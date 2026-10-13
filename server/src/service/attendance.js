'use strict';
const { replay } = require('../engine/replay');
const { summarize } = require('../engine/daily');
const { DAY, MIN, dayKey, dayStart, addDays } = require('../engine/time');
const { distanceM } = require('../util/geo');

const CLIENT_TYPES = new Set(['ENTER', 'EXIT', 'PING']);
const PAD = DAY; // replay window padding so a visit that began before the window is still seen

class Attendance {
  constructor(store, cfg, clock = () => Date.now()) {
    this.store = store;
    this.cfg = cfg;
    this.clock = clock;
  }

  assignedLocations(locations, userName) {
    const u = userName.toLowerCase();
    return locations.filter((l) => (l.assignedEmployees || []).some((n) => String(n).toLowerCase() === u));
  }

  /** Validate, de-skew and store a batch. Safe to call again with the same events. */
  async ingest(user, body) {
    const p = this.cfg.policy;
    const now = this.clock();
    const list = Array.isArray(body && body.events) ? body.events.slice(0, p.maxBatch) : [];
    // Clock skew: the phone stamps the moment it sends the batch. If its clock is off we shift
    // every event in the batch by the same amount, so a wrong phone clock cannot corrupt hours.
    let skew = 0;
    const sent = Number(body && body.deviceSentAt);
    if (Number.isFinite(sent) && sent > 0 && Math.abs(now - sent) > p.skewToleranceMs) skew = now - sent;

    const locations = await this.store.listLocations();
    const mine = this.assignedLocations(locations, user.name);
    const byId = new Map(mine.map((l) => [String(l.id), l]));
    const toStore = [];
    const rejected = [];
    let lastPing = null;

    for (const raw of list) {
      const id = raw && typeof raw.eventId === 'string' ? raw.eventId.slice(0, 80) : '';
      if (!id || !CLIENT_TYPES.has(raw.type) || !Number.isFinite(Number(raw.occurredAt))) {
        rejected.push({ eventId: id, why: 'malformed' });
        continue;
      }
      if (raw.mock === true) {
        rejected.push({ eventId: id, why: 'mock_location' });
        continue;
      }
      const at = Math.min(Number(raw.occurredAt) + skew, now);
      const base = { userName: user.name, occurredAt: at, receivedAt: now, source: raw.source || 'app', skewMs: skew };

      if (raw.type === 'ENTER' || raw.type === 'EXIT') {
        if (!byId.has(String(raw.locationId))) {
          rejected.push({ eventId: id, why: 'not_assigned' });
          continue;
        }
        toStore.push({ ...base, eventId: id, type: raw.type, locationId: String(raw.locationId) });
      } else {
        const lat = Number(raw.lat);
        const lng = Number(raw.lng);
        const acc = Number(raw.accuracy);
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
          rejected.push({ eventId: id, why: 'malformed' });
          continue;
        }
        if (!lastPing || at > lastPing.at) lastPing = { at, lat, lng, acc };
        if (Number.isFinite(acc) && acc > p.maxAccuracyM) {
          rejected.push({ eventId: id, why: 'poor_accuracy' });
          continue;
        }
        for (const loc of mine) {
          const d = distanceM(lat, lng, loc.latitude, loc.longitude);
          const r = Math.max(loc.radiusMeters || 100, p.minRadiusM);
          const a = Number.isFinite(acc) ? acc : 0;
          if (d <= r) toStore.push({ ...base, eventId: `${id}:${loc.id}`, type: 'PING_IN', locationId: String(loc.id) });
          else if (d > r * 1.15 + Math.min(a, 50)) toStore.push({ ...base, eventId: `${id}:${loc.id}`, type: 'PING_OUT', locationId: String(loc.id) });
          // between radius and radius+15%: undecided, ignored on purpose (hysteresis)
        }
      }
    }

    const inserted = await this.store.insertEvents(toStore);
    const patch = {};
    if (lastPing) patch.lastKnownLocation = { latitude: lastPing.lat, longitude: lastPing.lng, accuracy: lastPing.acc, updatedAt: lastPing.at };
    if (Object.keys(patch).length) await this.store.updateUser(user.id, patch);
    const state = await this.state(user);
    await this.store.updateUser(user.id, { currentStatus: state.open ? 'active' : 'checked_out' });
    return { accepted: inserted, duplicates: toStore.length - inserted, rejected, state, serverTime: now };
  }

  async _sessions(userName, from, to, locations) {
    const now = this.clock();
    const events = await this.store.listEvents(userName, from - PAD, to);
    const adj = await this.store.listAdjustments(userName, from - PAD, to);
    const all = [...events];
    for (const a of adj) if (!all.some((e) => e.eventId === a.eventId)) all.push(a);
    const names = new Map((locations || []).map((l) => [String(l.id), l.name]));
    return replay(all, now, this.cfg.policy)
      .filter((s) => s.end >= from && s.start <= to)
      .map((s) => ({ ...s, locationName: names.get(String(s.locationId)) || 'Site' }));
  }

  /** Live state: is the person inside a site right now, and how long today. */
  async state(user) {
    const now = this.clock();
    const tz = this.cfg.tzOffsetMin;
    const locations = await this.store.listLocations();
    const today = dayKey(now, tz);
    const from = dayStart(today, tz);
    const sessions = await this._sessions(user.name, from, now, locations);
    const sum = summarize(sessions, this.cfg)[today];
    const open = sessions.filter((s) => s.open).sort((a, b) => a.start - b.start)[0] || null;
    return {
      serverTime: now,
      date: today,
      open: open ? { locationId: open.locationId, locationName: open.locationName, since: open.start, stale: open.stale } : null,
      todayMinutes: sum ? sum.totalMinutes : 0,
      todayStatus: sum ? sum.status : 'absent',
      checkInCount: sum ? sum.checkInCount : 0,
    };
  }

  async day(userName, key) {
    const tz = this.cfg.tzOffsetMin;
    const from = dayStart(key, tz);
    const locations = await this.store.listLocations();
    const sessions = await this._sessions(userName, from, from + DAY - 1, locations);
    const s = summarize(sessions, this.cfg)[key];
    return s || { date: key, totalMinutes: 0, status: 'absent', checkInCount: 0, needsReview: false, sessions: [] };
  }

  async month(userName, ym) {
    const tz = this.cfg.tzOffsetMin;
    const first = `${ym}-01`;
    const from = dayStart(first, tz);
    const [y, m] = ym.split('-').map(Number);
    const next = m === 12 ? `${y + 1}-01-01` : `${y}-${String(m + 1).padStart(2, '0')}-01`;
    const to = dayStart(next, tz) - 1;
    const locations = await this.store.listLocations();
    const sessions = await this._sessions(userName, from, to, locations);
    const sums = summarize(sessions, this.cfg);
    const days = Object.values(sums).filter((d) => d.date >= first && d.date < next).map(({ sessions: _s, ...rest }) => rest);
    return { month: ym, days: days.sort((a, b) => a.date.localeCompare(b.date)), totalMinutes: days.reduce((a, d) => a + d.totalMinutes, 0) };
  }

  /** Admin dashboard: everyone, live. */
  async overview() {
    const users = (await this.store.listUsers()).filter((u) => u.role !== 'admin');
    const out = [];
    for (const u of users) {
      const st = await this.state(u);
      out.push({
        id: u.id,
        name: u.name,
        status: st.open ? (st.open.stale ? 'unconfirmed' : 'inside') : 'outside',
        site: st.open ? st.open.locationName : null,
        since: st.open ? st.open.since : null,
        todayMinutes: st.todayMinutes,
        lastKnownLocation: u.lastKnownLocation || null,
      });
    }
    return { serverTime: this.clock(), employees: out };
  }

  async review(fromKey, toKey) {
    const tz = this.cfg.tzOffsetMin;
    const from = dayStart(fromKey, tz);
    const to = dayStart(addDays(toKey, 1), tz) - 1;
    const locations = await this.store.listLocations();
    const users = (await this.store.listUsers()).filter((u) => u.role !== 'admin');
    const items = [];
    for (const u of users) {
      const ss = await this._sessions(u.name, from, to, locations);
      for (const s of ss) if (s.needsReview) items.push({ userName: u.name, ...s });
    }
    return items.sort((a, b) => b.start - a.start);
  }

  /**
   * Detailed attendance report for an optional userName and date range [fromKey, toKey].
   * Generates day-by-day records for all employees or a single employee.
   */
  async report({ userName, fromKey, toKey }) {
    const tz = this.cfg.tzOffsetMin;
    const from = dayStart(fromKey, tz);
    const to = dayStart(addDays(toKey, 1), tz) - 1;
    const locations = await this.store.listLocations();
    const locMap = new Map(locations.map((l) => [String(l.id), l.name]));
    let users = (await this.store.listUsers()).filter((u) => u.role !== 'admin');
    if (userName && userName.trim()) {
      users = users.filter((u) => u.name.toLowerCase() === userName.trim().toLowerCase());
    }

    const records = [];
    for (const u of users) {
      const sessions = await this._sessions(u.name, from, to, locations);
      const sums = summarize(sessions, this.cfg);

      // Generate continuous day entries from fromKey to toKey
      let cursorKey = fromKey;
      while (cursorKey <= toKey) {
        const sum = sums[cursorKey];
        if (sum && sum.totalMinutes > 0) {
          const daySessions = sum.sessions || [];
          const firstIn = daySessions.length > 0 ? daySessions[0].start : null;
          const lastOut = daySessions.length > 0 ? daySessions[daySessions.length - 1].end : null;
          const sitesVisited = [...new Set(daySessions.map((s) => s.locationName || locMap.get(String(s.locationId)) || 'Site'))].join(', ');

          records.push({
            userName: u.name,
            userId: u.id,
            date: cursorKey,
            status: sum.status, // present | partial | absent
            totalMinutes: sum.totalMinutes,
            workedHours: (sum.totalMinutes / 60).toFixed(2),
            checkInCount: sum.checkInCount,
            firstIn,
            lastOut,
            sites: sitesVisited,
            needsReview: sum.needsReview || false,
          });
        } else {
          records.push({
            userName: u.name,
            userId: u.id,
            date: cursorKey,
            status: 'absent',
            totalMinutes: 0,
            workedHours: '0.00',
            checkInCount: 0,
            firstIn: null,
            lastOut: null,
            sites: '-',
            needsReview: false,
          });
        }
        cursorKey = addDays(cursorKey, 1);
      }
    }

    return {
      from: fromKey,
      to: toKey,
      totalRecords: records.length,
      records: records.sort((a, b) => (b.date === a.date ? a.userName.localeCompare(b.userName) : b.date.localeCompare(a.date))),
    };
  }

  async adjust(admin, b) {
    const now = this.clock();
    const start = Number(b.start);
    const end = Number(b.end);
    if (!b.userName || !['add', 'void'].includes(b.action) || !Number.isFinite(start) || !Number.isFinite(end) || end <= start) {
      const e = new Error('userName, action (add|void), start and end (epoch ms, end > start) are required');
      e.status = 400;
      throw e;
    }
    if (end - start > 24 * 60 * MIN) {
      const e = new Error('An adjustment cannot exceed 24 hours');
      e.status = 400;
      throw e;
    }
    const ev = {
      eventId: `adj-${now}-${Math.random().toString(36).slice(2, 8)}`,
      userName: b.userName,
      type: b.action === 'add' ? 'ADJ_ADD' : 'ADJ_VOID',
      locationId: b.locationId ? String(b.locationId) : null,
      occurredAt: start,
      endAt: end,
      receivedAt: now,
      note: String(b.note || '').slice(0, 200),
      by: admin.name,
      source: 'admin',
    };
    await this.store.insertEvents([ev]);
    return ev;
  }

  /** Housekeeping only. Hours are derived on read, so skipping the sweep never makes them wrong. */
  async sweep() {
    const now = this.clock();
    const users = (await this.store.listUsers()).filter((u) => u.role !== 'admin');
    let changed = 0;
    for (const u of users) {
      const st = await this.state(u);
      const want = st.open ? 'active' : 'checked_out';
      if (u.currentStatus !== want) {
        await this.store.updateUser(u.id, { currentStatus: want });
        changed++;
      }
    }
    const pruned = await this.store.deletePingsBefore(now - this.cfg.policy.pingRetentionDays * DAY);
    return { checked: users.length, statusChanged: changed, pruned, serverTime: now };
  }
}

module.exports = Attendance;

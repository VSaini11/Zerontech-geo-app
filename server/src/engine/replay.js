'use strict';
/**
 * Pure attendance engine. Input: an unordered, possibly duplicated, possibly late bag of facts.
 * Output: sessions. No clock reads, no I/O, so identical input always gives identical output.
 *
 * Fact types
 *   ENTER / EXIT      OS geofence transitions reported by the phone
 *   PING_IN/PING_OUT  position samples classified against a site (derived on the server)
 *   ADJ_ADD           admin added a block of time     (occurredAt = start, endAt = end)
 *   ADJ_VOID          admin removed a block of time   (occurredAt = start, endAt = end)
 */
const IN_TYPES = new Set(['ENTER', 'PING_IN']);
const OUT_TYPES = new Set(['EXIT', 'PING_OUT']);
const RANK = { ENTER: 0, PING_IN: 0, PING_OUT: 1, EXIT: 1 };

function finish(cur, end, reason, flags, policy) {
  const f = [...cur.flags, ...flags];
  let e = Math.max(end, cur.start);
  if (e - cur.start > policy.maxSessionMs) {
    e = cur.start + policy.maxSessionMs;
    f.push('over_max');
    reason = 'auto_close';
  }
  return { locationId: cur.locationId, start: cur.start, end: e, open: false, stale: false, reason, flags: f };
}

function replayLocation(locationId, events, now, policy) {
  const out = [];
  let cur = null;
  for (const ev of events) {
    const t = ev.occurredAt;
    if (IN_TYPES.has(ev.type)) {
      if (!cur) {
        cur = { locationId, start: t, last: t, flags: [] };
      } else if (t - cur.last > policy.bridgeMs) {
        // Long silence with no EXIT: the earlier visit ended around its last proof of presence.
        out.push(finish(cur, cur.last + policy.graceMs, 'inferred_exit', ['no_exit_recorded'], policy));
        cur = { locationId, start: t, last: t, flags: [] };
      } else {
        if (t - cur.last > policy.staleMs && !cur.flags.includes('bridged_gap')) cur.flags.push('bridged_gap');
        cur.last = Math.max(cur.last, t);
      }
    } else if (OUT_TYPES.has(ev.type)) {
      if (cur) {
        out.push(finish(cur, t, 'outside_radius', [], policy));
        cur = null;
      }
    }
  }
  if (cur) {
    const idle = now - cur.last;
    if (idle > policy.bridgeMs) {
      out.push(finish(cur, cur.last + policy.graceMs, 'inferred_exit', ['no_exit_recorded'], policy));
    } else if (now - cur.start > policy.maxSessionMs) {
      out.push(finish(cur, cur.start + policy.maxSessionMs, 'auto_close', ['over_max'], policy));
    } else {
      const stale = idle > policy.staleMs;
      out.push({
        locationId,
        start: cur.start,
        end: stale ? Math.min(now, cur.last + policy.graceMs) : now,
        open: true,
        stale,
        reason: null,
        flags: [...cur.flags],
      });
    }
  }
  return out;
}

// A short exit + re-entry is GPS or elevator noise, not a new visit.
function mergeFlaps(sessions, policy) {
  const sorted = [...sessions].sort((a, b) => a.start - b.start);
  const res = [];
  for (const s of sorted) {
    const p = res[res.length - 1];
    if (p && !p.open && s.start - p.end <= policy.flapMs && s.start >= p.end) {
      p.end = s.end;
      p.open = s.open;
      p.stale = s.stale;
      p.reason = s.reason;
      p.flags = [...new Set([...p.flags, ...s.flags, 'merged_flap'])];
    } else {
      res.push({ ...s, flags: [...s.flags] });
    }
  }
  return res;
}

function subtract(session, from, to) {
  if (to <= session.start || from >= session.end) return [session];
  const parts = [];
  if (from > session.start) parts.push({ ...session, end: from, open: false, stale: false, flags: [...session.flags, 'trimmed'] });
  if (to < session.end) parts.push({ ...session, start: to, flags: [...session.flags, 'trimmed'] });
  return parts;
}

function replay(events, now, policy) {
  const facts = events
    .filter((e) => IN_TYPES.has(e.type) || OUT_TYPES.has(e.type))
    .sort((a, b) => a.occurredAt - b.occurredAt || RANK[a.type] - RANK[b.type] || String(a.eventId).localeCompare(String(b.eventId)));

  const byLoc = new Map();
  for (const e of facts) {
    if (!byLoc.has(e.locationId)) byLoc.set(e.locationId, []);
    byLoc.get(e.locationId).push(e);
  }

  let sessions = [];
  for (const [locId, evs] of byLoc) sessions.push(...mergeFlaps(replayLocation(locId, evs, now, policy), policy));

  const adj = events.filter((e) => e.type === 'ADJ_VOID' || e.type === 'ADJ_ADD');
  for (const a of adj.filter((x) => x.type === 'ADJ_VOID')) {
    sessions = sessions.flatMap((s) => (a.locationId && a.locationId !== s.locationId ? [s] : subtract(s, a.occurredAt, a.endAt)));
  }
  for (const a of adj.filter((x) => x.type === 'ADJ_ADD')) {
    sessions.push({
      locationId: a.locationId || null,
      start: a.occurredAt,
      end: a.endAt,
      open: false,
      stale: false,
      reason: 'manual',
      flags: ['manual'],
      note: a.note || '',
    });
  }

  return sessions
    .filter((s) => s.end > s.start || s.open)
    .map((s) => ({ ...s, needsReview: s.flags.includes('no_exit_recorded') || s.flags.includes('over_max') }))
    .sort((a, b) => a.start - b.start);
}

module.exports = { replay, IN_TYPES, OUT_TYPES };

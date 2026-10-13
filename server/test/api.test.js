'use strict';
const test = require('node:test');
const assert = require('node:assert');
const bcrypt = require('bcryptjs');
const cfg = require('../src/config');
const MemoryStore = require('../src/store/memory');
const createApp = require('../src/app');

const M = 60000, H = 60 * M;
let now = Date.parse('2026-03-02T04:00:00Z');
let server, base, store;
const OFFICE = { latitude: 28.6139, longitude: 77.209 };

async function call(method, path, { token, body } = {}) {
  const r = await fetch(base + path, { method, headers: { 'content-type': 'application/json', ...(token ? { authorization: 'Bearer ' + token } : {}) }, body: body ? JSON.stringify(body) : undefined });
  return { status: r.status, body: await r.json().catch(() => ({})) };
}

test.before(async () => {
  store = new MemoryStore();
  await store.createUser({ name: 'admin', password: await bcrypt.hash('adminpw', 4), role: 'admin' });
  await store.createUser({ name: 'asha', password: await bcrypt.hash('ashapw1', 4), role: 'employee' });
  await store.createLocation({ name: 'Head Office', ...OFFICE, radiusMeters: 150, assignedEmployees: ['asha'] });
  server = createApp(store, cfg, () => now).listen(0);
  base = 'http://127.0.0.1:' + server.address().port;
});
test.after(() => server.close());

let asha, adminTok, refresh, locId;

test('login, config and refresh', async () => {
  const l = await call('POST', '/api/auth/login', { body: { name: 'asha', password: 'ashapw1' } });
  assert.equal(l.status, 200);
  asha = l.body.accessToken; refresh = l.body.refreshToken;
  assert.equal((await call('POST', '/api/auth/login', { body: { name: 'asha', password: 'bad' } })).status, 401);
  const c = await call('GET', '/api/me/config', { token: asha });
  assert.equal(c.body.locations.length, 1);
  locId = c.body.locations[0].id;
  const r = await call('POST', '/api/auth/refresh', { body: { refreshToken: refresh } });
  assert.equal(r.status, 200);
  assert.equal((await call('POST', '/api/auth/refresh', { body: { refreshToken: asha } })).status, 401, 'access token must not work as refresh');
  adminTok = (await call('POST', '/api/auth/login', { body: { name: 'admin', password: 'adminpw' } })).body.accessToken;
});

test('events delivered twice and out of order produce the same hours', async () => {
  const t = now;
  const batch = [
    { eventId: 'x2', type: 'EXIT', locationId: locId, occurredAt: t + 3 * H },
    { eventId: 'x1', type: 'ENTER', locationId: locId, occurredAt: t },
  ];
  now = t + 4 * H;
  const a = await call('POST', '/api/geo/events', { token: asha, body: { deviceSentAt: now, events: batch } });
  assert.equal(a.body.accepted, 2);
  const b = await call('POST', '/api/geo/events', { token: asha, body: { deviceSentAt: now, events: batch } });
  assert.equal(b.body.accepted, 0);
  assert.equal(b.body.duplicates, 2);
  assert.equal(b.body.state.todayMinutes, 180);
  assert.equal(b.body.state.open, null);
});

test('wrong phone clock is corrected from the batch send time', async () => {
  const phoneAhead = 2 * H;
  const t = now - 30 * M;
  const r = await call('POST', '/api/geo/events', { token: asha, body: { deviceSentAt: now + phoneAhead, events: [{ eventId: 'sk1', type: 'ENTER', locationId: locId, occurredAt: t + phoneAhead }] } });
  assert.equal(r.body.state.open.since, t);
  assert.equal(r.body.state.todayMinutes, 180 + 30);
});

test('mock locations and unassigned sites are rejected', async () => {
  const r = await call('POST', '/api/geo/events', { token: asha, body: { deviceSentAt: now, events: [
    { eventId: 'm1', type: 'ENTER', locationId: locId, occurredAt: now, mock: true },
    { eventId: 'm2', type: 'ENTER', locationId: '999', occurredAt: now },
  ] } });
  assert.deepEqual(r.body.rejected.map((x) => x.why).sort(), ['mock_location', 'not_assigned']);
});

test('ping outside radius closes, ping inside opens; poor accuracy ignored', async () => {
  const far = { lat: OFFICE.latitude + 0.02, lng: OFFICE.longitude };
  now += 10 * M;
  let r = await call('POST', '/api/geo/events', { token: asha, body: { deviceSentAt: now, events: [{ eventId: 'p1', type: 'PING', occurredAt: now, ...far, accuracy: 20 }] } });
  assert.equal(r.body.state.open, null);
  now += 20 * M;
  r = await call('POST', '/api/geo/events', { token: asha, body: { deviceSentAt: now, events: [{ eventId: 'p2', type: 'PING', occurredAt: now, lat: OFFICE.latitude, lng: OFFICE.longitude, accuracy: 500 }] } });
  assert.equal(r.body.rejected[0].why, 'poor_accuracy');
  assert.equal(r.body.state.open, null);
  now += M;
  r = await call('POST', '/api/geo/events', { token: asha, body: { deviceSentAt: now, events: [{ eventId: 'p3', type: 'PING', occurredAt: now, lat: OFFICE.latitude, lng: OFFICE.longitude, accuracy: 10 }] } });
  assert.ok(r.body.state.open);
});

test('app closed for days: hours never run away, and the admin sees it flagged', async () => {
  now += 5 * 24 * H;
  const s = await call('GET', '/api/geo/state', { token: asha });
  assert.equal(s.body.open, null);
  const rv = await call('GET', '/api/admin/review', { token: adminTok });
  assert.ok(rv.body.items.some((i) => i.userName === 'asha' && i.flags.includes('no_exit_recorded')));
  assert.equal((await call('GET', '/api/admin/review', { token: asha })).status, 403);
});

test('admin overview, adjust, sweep, employees', async () => {
  const o = await call('GET', '/api/admin/status', { token: adminTok });
  assert.equal(o.body.employees[0].name, 'asha');
  const day = '2026-03-02';
  const before = (await call('GET', `/api/geo/day?date=${day}&user=asha`, { token: adminTok })).body.totalMinutes;
  const start = Date.parse('2026-03-02T04:00:00Z');
  await call('POST', '/api/admin/adjust', { token: adminTok, body: { userName: 'asha', action: 'void', start, end: start + H, note: 'test' } });
  const after = (await call('GET', `/api/geo/day?date=${day}&user=asha`, { token: adminTok })).body.totalMinutes;
  assert.equal(after, before - 60);
  assert.equal((await call('POST', '/api/admin/sweep', { token: adminTok })).status, 200);
  const e = await call('POST', '/api/employees', { token: adminTok, body: { name: 'ravi', password: 'ravipw1', locationIds: [locId] } });
  assert.equal(e.status, 201);
  assert.equal((await call('POST', '/api/employees', { token: adminTok, body: { name: 'ravi', password: 'ravipw1' } })).status, 409);
  assert.equal((await call('POST', '/api/locations', { token: adminTok, body: { name: 'Tiny', latitude: 1, longitude: 1, radiusMeters: 20 } })).status, 400);
});

test('password reset revokes old sessions', async () => {
  const id = (await store.findUserByName('asha')).id;
  await call('PUT', `/api/employees/${id}/password`, { token: adminTok, body: { password: 'newpass1' } });
  assert.equal((await call('GET', '/api/geo/state', { token: asha })).status, 401);
  assert.equal((await call('POST', '/api/auth/refresh', { body: { refreshToken: refresh } })).status, 401);
});

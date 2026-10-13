'use strict';
const test = require('node:test');
const assert = require('node:assert');
const cfg = require('../src/config');
const { replay } = require('../src/engine/replay');
const { summarize } = require('../src/engine/daily');

const M = 60000;
const H = 60 * M;
const T0 = Date.parse('2026-03-02T04:00:00Z'); // 09:30 IST
const P = cfg.policy;
let n = 0;
const ev = (type, at, loc = 'A') => ({ eventId: 'e' + n++, type, locationId: loc, occurredAt: at });
const hours = (sessions) => summarize(sessions, cfg);
const total = (sessions) => Object.values(hours(sessions)).reduce((a, d) => a + d.totalMinutes, 0);

test('simple visit = exit minus enter', () => {
  const s = replay([ev('ENTER', T0), ev('EXIT', T0 + 3 * H)], T0 + 10 * H, P);
  assert.equal(s.length, 1);
  assert.equal(total(s), 180);
});

test('delivery order and duplicates do not matter (app closed, events arrive late and shuffled)', () => {
  const a = ev('ENTER', T0), b = ev('EXIT', T0 + 2 * H), c = ev('ENTER', T0 + 3 * H), d = ev('EXIT', T0 + 5 * H);
  const x = replay([a, b, c, d], T0 + 9 * H, P);
  const y = replay([d, c, b, a, a, c], T0 + 9 * H, P);
  assert.deepEqual(x, y);
  assert.equal(total(x), 240);
});

test('lost EXIT never leaves a visit running for days', () => {
  const s = replay([ev('ENTER', T0)], T0 + 72 * H, P);
  assert.equal(s.length, 1);
  assert.equal(s[0].open, false);
  assert.equal(s[0].reason, 'inferred_exit');
  assert.ok(s[0].needsReview);
  assert.equal(total(s), 15); // last proof + grace only
});

test('lost EXIT followed by next-day ENTER does not merge into a 20-hour day', () => {
  const s = replay([ev('ENTER', T0), ev('ENTER', T0 + 24 * H), ev('EXIT', T0 + 32 * H)], T0 + 40 * H, P);
  assert.equal(s.length, 2);
  assert.equal(total(s), 15 + 480);
});

test('lost ENTER then EXIT: exit is ignored, no negative or phantom time', () => {
  const s = replay([ev('EXIT', T0)], T0 + H, P);
  assert.equal(s.length, 0);
});

test('heartbeat pings keep a long visit alive and silence after them is capped', () => {
  const evs = [ev('ENTER', T0)];
  for (let i = 1; i <= 8; i++) evs.push(ev('PING_IN', T0 + i * 30 * M));
  const s = replay(evs, T0 + 20 * H, P);
  assert.equal(total(s), 4 * 60 + 15);
});

test('open session is live while signal is fresh, and stops counting when stale', () => {
  const fresh = replay([ev('ENTER', T0)], T0 + 30 * M, P);
  assert.equal(fresh[0].open, true);
  assert.equal(fresh[0].stale, false);
  assert.equal(total(fresh), 30);
  const stale = replay([ev('ENTER', T0)], T0 + 2 * H, P);
  assert.equal(stale[0].open, true);
  assert.equal(stale[0].stale, true);
  assert.equal(total(stale), 15);
});

test('a ping after a quiet gap bridges the visit (doze mode, no EXIT happened)', () => {
  const s = replay([ev('ENTER', T0), ev('PING_IN', T0 + 2 * H), ev('EXIT', T0 + 3 * H)], T0 + 5 * H, P);
  assert.equal(s.length, 1);
  assert.equal(total(s), 180);
  assert.ok(s[0].flags.includes('bridged_gap'));
});

test('GPS flap: exit and re-enter within 10 min is one visit', () => {
  const s = replay([ev('ENTER', T0), ev('EXIT', T0 + 2 * H), ev('ENTER', T0 + 2 * H + 4 * M), ev('EXIT', T0 + 4 * H)], T0 + 9 * H, P);
  assert.equal(s.length, 1);
  assert.equal(total(s), 240);
});

test('genuine break longer than the flap window stays two visits', () => {
  const s = replay([ev('ENTER', T0), ev('EXIT', T0 + 2 * H), ev('ENTER', T0 + 3 * H), ev('EXIT', T0 + 5 * H)], T0 + 9 * H, P);
  assert.equal(s.length, 2);
  assert.equal(total(s), 240);
});

test('visit past midnight splits across IST days', () => {
  const start = Date.parse('2026-03-02T16:00:00Z'); // 21:30 IST
  const s = replay([ev('ENTER', start), ev('EXIT', start + 4 * H)], start + 10 * H, P);
  const d = hours(s);
  assert.equal(d['2026-03-02'].totalMinutes, 150);
  assert.equal(d['2026-03-03'].totalMinutes, 90);
});

test('overlapping sites never double count', () => {
  const s = replay([ev('ENTER', T0, 'A'), ev('ENTER', T0 + H, 'B'), ev('EXIT', T0 + 2 * H, 'A'), ev('EXIT', T0 + 3 * H, 'B')], T0 + 9 * H, P);
  assert.equal(s.length, 2);
  assert.equal(total(s), 180);
});

test('visit over 16 hours is capped and flagged', () => {
  const s = replay([ev('ENTER', T0), ev('PING_IN', T0 + 3 * H), ev('PING_IN', T0 + 6 * H), ev('PING_IN', T0 + 9 * H), ev('PING_IN', T0 + 12 * H), ev('PING_IN', T0 + 15 * H), ev('PING_IN', T0 + 17 * H), ev('EXIT', T0 + 18 * H)], T0 + 30 * H, P);
  assert.equal(s[0].flags.includes('over_max'), true);
  assert.equal(total(s), 16 * 60);
});

test('admin void and add adjust the result', () => {
  const base = [ev('ENTER', T0), ev('EXIT', T0 + 4 * H)];
  const voided = replay([...base, { eventId: 'v', type: 'ADJ_VOID', occurredAt: T0 + 2 * H, endAt: T0 + 3 * H }], T0 + 9 * H, P);
  assert.equal(total(voided), 180);
  const added = replay([{ eventId: 'a', type: 'ADJ_ADD', locationId: 'A', occurredAt: T0, endAt: T0 + 2 * H, note: 'forgot phone' }], T0 + 9 * H, P);
  assert.equal(total(added), 120);
});

test('lunch deduction applies only to the overlap and only when configured', () => {
  const c = { ...cfg, policy: { ...P, lunchDeductMin: 60 } };
  const s = replay([ev('ENTER', T0), ev('EXIT', T0 + 8 * H)], T0 + 10 * H, P); // 09:30-17:30 IST
  assert.equal(Object.values(summarize(s, c))[0].totalMinutes, 420);
});

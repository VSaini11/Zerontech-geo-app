'use strict';
const { DAY, MIN, dayKey, dayStart, minuteOfDay } = require('./time');

function union(intervals) {
  const s = intervals.filter((i) => i[1] > i[0]).sort((a, b) => a[0] - b[0]);
  const out = [];
  for (const i of s) {
    const l = out[out.length - 1];
    if (l && i[0] <= l[1]) l[1] = Math.max(l[1], i[1]);
    else out.push([i[0], i[1]]);
  }
  return out;
}

/**
 * Split sessions at business-day midnight, merge overlapping time (two sites with overlapping
 * circles never double count), optionally deduct lunch, return one summary per day touched.
 */
function summarize(sessions, cfg) {
  const tz = cfg.tzOffsetMin;
  const p = cfg.policy;
  const days = new Map();
  for (const s of sessions) {
    let cursor = s.start;
    while (cursor < s.end) {
      const key = dayKey(cursor, tz);
      const dStart = dayStart(key, tz);
      const dEnd = dStart + DAY;
      const segEnd = Math.min(s.end, dEnd);
      if (!days.has(key)) days.set(key, { date: key, intervals: [], sessions: [] });
      const d = days.get(key);
      d.intervals.push([cursor, segEnd]);
      d.sessions.push({ ...s, start: cursor, end: segEnd, minutes: Math.round((segEnd - cursor) / MIN) });
      cursor = segEnd;
    }
  }
  const out = {};
  for (const [key, d] of days) {
    const merged = union(d.intervals);
    let ms = merged.reduce((a, i) => a + (i[1] - i[0]), 0);
    if (p.lunchDeductMin > 0) {
      const dStart = dayStart(key, tz);
      const lo = dStart + p.lunchStartMin * MIN;
      const hi = dStart + p.lunchEndMin * MIN;
      const overlap = merged.reduce((a, i) => a + Math.max(0, Math.min(i[1], hi) - Math.max(i[0], lo)), 0);
      ms -= Math.min(overlap, p.lunchDeductMin * MIN);
    }
    const minutes = Math.max(0, Math.round(ms / MIN));
    out[key] = {
      date: key,
      totalMinutes: minutes,
      status: minutes >= p.presentMin ? 'present' : minutes > 0 ? 'partial' : 'absent',
      checkInCount: d.sessions.length,
      needsReview: d.sessions.some((x) => x.needsReview),
      sessions: d.sessions.sort((a, b) => a.start - b.start),
    };
  }
  return out;
}

module.exports = { summarize, union, minuteOfDay };

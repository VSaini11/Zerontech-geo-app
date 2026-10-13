'use strict';
const DAY = 24 * 60 * 60 * 1000;
const MIN = 60 * 1000;

// Day boundaries are computed in the business time zone (offset minutes east of UTC),
// never in the server's or phone's local zone.
function dayKey(ms, tz) {
  return new Date(ms + tz * MIN).toISOString().slice(0, 10);
}
function dayStart(key, tz) {
  return Date.parse(key + 'T00:00:00.000Z') - tz * MIN;
}
function addDays(key, n) {
  return new Date(Date.parse(key + 'T00:00:00.000Z') + n * DAY).toISOString().slice(0, 10);
}
function minuteOfDay(ms, tz) {
  const d = new Date(ms + tz * MIN);
  return d.getUTCHours() * 60 + d.getUTCMinutes();
}
function validKey(k) {
  return typeof k === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(k) && !Number.isNaN(Date.parse(k));
}
module.exports = { DAY, MIN, dayKey, dayStart, addDays, minuteOfDay, validKey };

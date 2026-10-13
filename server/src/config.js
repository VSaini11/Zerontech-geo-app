'use strict';
// All policy numbers live here so they can be tuned without touching logic.
const num = (v, d) => (v === undefined || v === '' || Number.isNaN(Number(v)) ? d : Number(v));
const MIN = 60 * 1000;

module.exports = {
  // AppSail tells the container which port to bind through this variable.
  port: num(process.env.X_ZOHO_CATALYST_LISTEN_PORT || process.env.PORT, 9000),
  mongoUri: process.env.MONGODB_URI || '',
  jwtSecret: process.env.JWT_SECRET || 'dev-only-change-me',
  sweepKey: process.env.SWEEP_KEY || '',
  accessTtl: process.env.ACCESS_TTL || '2h',
  refreshTtl: process.env.REFRESH_TTL || '90d',

  tzOffsetMin: num(process.env.TZ_OFFSET_MIN, 330), // IST

  policy: {
    minRadiusM: num(process.env.MIN_RADIUS_M, 100),
    maxAccuracyM: num(process.env.MAX_ACCURACY_M, 100),
    flapMs: num(process.env.FLAP_MIN, 10) * MIN,     // exit+re-enter inside this gap = same visit
    staleMs: num(process.env.STALE_MIN, 45) * MIN,   // no signal this long = "unconfirmed"
    bridgeMs: num(process.env.BRIDGE_MIN, 180) * MIN,// silence longer than this = visit ended
    graceMs: num(process.env.GRACE_MIN, 15) * MIN,   // credit after last proof of presence
    maxSessionMs: num(process.env.MAX_SESSION_H, 16) * 60 * MIN,
    lunchDeductMin: num(process.env.LUNCH_DEDUCT_MIN, 0),
    lunchStartMin: 13 * 60,
    lunchEndMin: 14 * 60,
    presentMin: num(process.env.PRESENT_MIN, 240),
    skewToleranceMs: 2 * MIN,
    maxBatch: 200,
    pingRetentionDays: num(process.env.PING_RETENTION_DAYS, 120),
  },
};

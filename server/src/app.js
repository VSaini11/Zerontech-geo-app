'use strict';
const express = require('express');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const Attendance = require('./service/attendance');
const { dayKey, validKey } = require('./engine/time');

function wrap(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}
function httpError(status, message) {
  const e = new Error(message);
  e.status = status;
  return e;
}

module.exports = function createApp(store, cfg, clock = () => Date.now()) {
  const app = express();
  const svc = new Attendance(store, cfg, clock);
  app.use(cors());
  app.use(express.json({ limit: '1mb' }));

  const sign = (user, type) =>
    jwt.sign({ sub: user.id, name: user.name, role: user.role, tv: user.tokenVersion || 0, typ: type }, cfg.jwtSecret, {
      expiresIn: type === 'access' ? cfg.accessTtl : cfg.refreshTtl,
    });
  const userView = (u) => ({ id: u.id, name: u.name, role: u.role });
  const tokens = (u) => ({ accessToken: sign(u, 'access'), refreshToken: sign(u, 'refresh'), token: sign(u, 'access'), user: userView(u), serverTime: clock() });

  const auth = wrap(async (req, _res, next) => {
    const h = req.headers.authorization || '';
    const t = h.startsWith('Bearer ') ? h.slice(7) : null;
    if (!t) throw httpError(401, 'Missing token');
    let p;
    try { p = jwt.verify(t, cfg.jwtSecret); } catch (e) { throw httpError(401, e.name === 'TokenExpiredError' ? 'token_expired' : 'Invalid token'); }
    if (p.typ !== 'access') throw httpError(401, 'Invalid token type');
    const u = await store.getUser(p.sub);
    if (!u || (u.tokenVersion || 0) !== p.tv) throw httpError(401, 'Session revoked');
    req.user = u;
    next();
  });
  const admin = (req, _res, next) => (req.user.role === 'admin' ? next() : next(httpError(403, 'Admin only')));

  app.get('/api/health', (_req, res) => res.json({ ok: true, serverTime: clock() }));

  // ---- auth
  app.post('/api/auth/login', wrap(async (req, res) => {
    const { name, password } = req.body || {};
    if (!name || !password) throw httpError(400, 'name and password required');
    const u = await store.findUserByName(name);
    if (!u || !(await bcrypt.compare(String(password), u.password))) throw httpError(401, 'Wrong username or password');
    res.json(tokens(u));
  }));
  // The long-lived refresh token is what keeps a phone signed in after weeks of the app being closed.
  app.post('/api/auth/refresh', wrap(async (req, res) => {
    let p;
    try { p = jwt.verify(String((req.body || {}).refreshToken || ''), cfg.jwtSecret); } catch { throw httpError(401, 'Refresh token invalid'); }
    if (p.typ !== 'refresh') throw httpError(401, 'Refresh token invalid');
    const u = await store.getUser(p.sub);
    if (!u || (u.tokenVersion || 0) !== p.tv) throw httpError(401, 'Session revoked');
    res.json(tokens(u));
  }));
  app.post('/api/auth/push-token', auth, wrap(async (req, res) => {
    await store.updateUser(req.user.id, { pushToken: String((req.body || {}).pushToken || '') });
    res.json({ ok: true });
  }));

  // ---- employee: config, events, views
  app.get('/api/me/config', auth, wrap(async (req, res) => {
    const locs = svc.assignedLocations(await store.listLocations(), req.user.name);
    res.json({
      serverTime: clock(),
      user: userView(req.user),
      policy: { minRadiusM: cfg.policy.minRadiusM, maxAccuracyM: cfg.policy.maxAccuracyM },
      locations: locs.map((l) => ({ id: l.id, name: l.name, latitude: l.latitude, longitude: l.longitude, radiusMeters: Math.max(l.radiusMeters || 100, cfg.policy.minRadiusM) })),
    });
  }));
  app.post('/api/geo/events', auth, wrap(async (req, res) => res.json(await svc.ingest(req.user, req.body))));
  app.get('/api/geo/state', auth, wrap(async (req, res) => res.json(await svc.state(req.user))));

  const target = (req) => (req.user.role === 'admin' && req.query.user ? String(req.query.user) : req.user.name);
  app.get('/api/geo/day', auth, wrap(async (req, res) => {
    const key = req.query.date || dayKey(clock(), cfg.tzOffsetMin);
    if (!validKey(key)) throw httpError(400, 'date must be YYYY-MM-DD');
    res.json(await svc.day(target(req), key));
  }));
  app.get('/api/geo/month', auth, wrap(async (req, res) => {
    const ym = req.query.month || dayKey(clock(), cfg.tzOffsetMin).slice(0, 7);
    if (!/^\d{4}-\d{2}$/.test(ym)) throw httpError(400, 'month must be YYYY-MM');
    res.json(await svc.month(target(req), ym));
  }));

  // ---- admin
  app.get('/api/admin/status', auth, admin, wrap(async (_req, res) => res.json(await svc.overview())));
  app.get('/api/admin/review', auth, admin, wrap(async (req, res) => {
    const to = req.query.to || dayKey(clock(), cfg.tzOffsetMin);
    const from = req.query.from || dayKey(clock() - 7 * 86400000, cfg.tzOffsetMin);
    if (!validKey(from) || !validKey(to)) throw httpError(400, 'from/to must be YYYY-MM-DD');
    res.json({ items: await svc.review(from, to) });
  }));
  app.get('/api/admin/report', auth, admin, wrap(async (req, res) => {
    const toKey = req.query.to || dayKey(clock(), cfg.tzOffsetMin);
    const fromKey = req.query.from || toKey;
    if (!validKey(fromKey) || !validKey(toKey)) throw httpError(400, 'from and to must be YYYY-MM-DD');
    const userName = req.query.user || null;
    res.json(await svc.report({ userName, fromKey, toKey }));
  }));
  app.post('/api/admin/adjust', auth, admin, wrap(async (req, res) => res.json(await svc.adjust(req.user, req.body || {}))));
  app.get('/api/admin/employee/:name', auth, admin, wrap(async (req, res) => {
    const u = await store.findUserByName(req.params.name);
    if (!u) throw httpError(404, 'Not found');
    res.json({ user: { ...userView(u), lastKnownLocation: u.lastKnownLocation || null }, state: await svc.state(u), today: await svc.day(u.name, dayKey(clock(), cfg.tzOffsetMin)) });
  }));

  // Housekeeping. Called by a scheduler with the shared key, or by an admin. Never needed for correctness.
  app.post('/api/admin/sweep', wrap(async (req, res, next) => {
    if (cfg.sweepKey && req.headers['x-sweep-key'] === cfg.sweepKey) return res.json(await svc.sweep());
    return auth(req, res, (err) => {
      if (err) return next(err);
      admin(req, res, async (e2) => {
        if (e2) return next(e2);
        try { res.json(await svc.sweep()); } catch (e) { next(e); }
      });
    });
  }));

  // ---- employees
  const empView = (u) => ({ id: u.id, name: u.name, role: u.role, createdAt: u.createdAt, currentStatus: u.currentStatus });
  app.get('/api/employees', auth, admin, wrap(async (_req, res) => {
    const [users, locs] = await Promise.all([store.listUsers(), store.listLocations()]);
    res.json(users.map((u) => ({ ...empView(u), sites: locs.filter((l) => (l.assignedEmployees || []).includes(u.name)).map((l) => ({ id: l.id, name: l.name })) })));
  }));
  app.post('/api/employees', auth, admin, wrap(async (req, res) => {
    const { name, password, locationIds } = req.body || {};
    if (!name || !password || String(password).length < 6) throw httpError(400, 'name and a password of at least 6 characters are required');
    if (await store.findUserByName(name)) throw httpError(409, 'Username already exists');
    const u = await store.createUser({ name: String(name).trim(), password: await bcrypt.hash(String(password), 10), role: 'employee' });
    for (const id of locationIds || []) {
      const l = await store.getLocation(id);
      if (l && !(l.assignedEmployees || []).includes(u.name)) await store.updateLocation(id, { assignedEmployees: [...(l.assignedEmployees || []), u.name] });
    }
    res.status(201).json(empView(u));
  }));
  app.put('/api/employees/:id/password', auth, admin, wrap(async (req, res) => {
    const pw = String((req.body || {}).password || '');
    if (pw.length < 6) throw httpError(400, 'Password must be at least 6 characters');
    const u = await store.getUser(req.params.id);
    if (!u) throw httpError(404, 'Not found');
    await store.updateUser(u.id, { password: await bcrypt.hash(pw, 10), tokenVersion: (u.tokenVersion || 0) + 1 });
    res.json({ ok: true });
  }));
  app.put('/api/employees/:id/sites', auth, admin, wrap(async (req, res) => {
    const u = await store.getUser(req.params.id);
    if (!u) throw httpError(404, 'Not found');
    const want = new Set((req.body.locationIds || []).map(String));
    for (const l of await store.listLocations()) {
      const has = (l.assignedEmployees || []).includes(u.name);
      if (want.has(String(l.id)) && !has) await store.updateLocation(l.id, { assignedEmployees: [...(l.assignedEmployees || []), u.name] });
      if (!want.has(String(l.id)) && has) await store.updateLocation(l.id, { assignedEmployees: l.assignedEmployees.filter((n) => n !== u.name) });
    }
    res.json({ ok: true });
  }));
  app.delete('/api/employees/:id', auth, admin, wrap(async (req, res) => {
    const u = await store.getUser(req.params.id);
    if (!u) throw httpError(404, 'Not found');
    if (u.id === req.user.id) throw httpError(400, 'You cannot delete yourself');
    for (const l of await store.listLocations()) {
      if ((l.assignedEmployees || []).includes(u.name)) await store.updateLocation(l.id, { assignedEmployees: l.assignedEmployees.filter((n) => n !== u.name) });
    }
    await store.deleteUser(u.id);
    res.json({ ok: true });
  }));

  // ---- locations
  const locBody = (b) => {
    const lat = Number(b.latitude), lng = Number(b.longitude), r = Number(b.radiusMeters ?? 100);
    if (!b.name || !Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) throw httpError(400, 'name, latitude and longitude are required');
    if (!Number.isFinite(r) || r < cfg.policy.minRadiusM || r > 5000) throw httpError(400, `radiusMeters must be between ${cfg.policy.minRadiusM} and 5000`);
    return { name: String(b.name).trim(), latitude: lat, longitude: lng, radiusMeters: r, ...(Array.isArray(b.assignedEmployees) ? { assignedEmployees: b.assignedEmployees.map(String) } : {}) };
  };
  app.get('/api/locations', auth, admin, wrap(async (_req, res) => res.json(await store.listLocations())));
  app.post('/api/locations', auth, admin, wrap(async (req, res) => res.status(201).json(await store.createLocation(locBody(req.body || {})))));
  app.put('/api/locations/:id', auth, admin, wrap(async (req, res) => {
    const l = await store.updateLocation(req.params.id, locBody(req.body || {}));
    if (!l) throw httpError(404, 'Not found');
    res.json(l);
  }));
  app.delete('/api/locations/:id', auth, admin, wrap(async (req, res) => { await store.deleteLocation(req.params.id); res.json({ ok: true }); }));

  app.use((_req, _res, next) => next(httpError(404, 'Not found')));
  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    const status = err.status || 500;
    if (status >= 500) console.error(err);
    res.status(status).json({ error: status >= 500 ? 'Server error' : err.message });
  });

  app.svc = svc;
  return app;
};

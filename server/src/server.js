'use strict';
const bcrypt = require('bcryptjs');
const cfg = require('./config');
const createStore = require('./store');
const createApp = require('./app');

async function main() {
  const memory = process.argv.includes('--memory');
  const store = await createStore({ memory, mongoUri: cfg.mongoUri });
  if (process.argv.includes('--seed')) {
    await store.createUser({ name: 'admin', password: await bcrypt.hash('admin123', 10), role: 'admin' });
    await store.createUser({ name: 'asha', password: await bcrypt.hash('asha123', 10), role: 'employee' });
    await store.createLocation({ name: 'Head Office', latitude: 28.6139, longitude: 77.209, radiusMeters: 150, assignedEmployees: ['asha'] });
    console.log('Seeded: admin/admin123, asha/asha123 (dev only)');
  }
  if (cfg.jwtSecret === 'dev-only-change-me' && process.env.NODE_ENV === 'production') {
    console.error('Refusing to start in production without JWT_SECRET');
    process.exit(1);
  }
  createApp(store, cfg).listen(cfg.port, '0.0.0.0', () => console.log(`geo-app server on :${cfg.port} (${memory || !cfg.mongoUri ? 'memory' : 'mongo'})`));
}
main().catch((e) => { console.error(e); process.exit(1); });

# Deploying the server (same AppSail, same database)

The server is a drop-in replacement for your current Express app. It keeps the same collections
`users` and `locations` and the same field names, so **existing logins keep working**. It adds one
collection, `geo_events`. Nothing in your old collections is changed.

## Steps
1. Copy the `server/` folder over your current server folder (or deploy it as a new AppSail
   service and test first).
2. Set environment variables in AppSail (same values as today for the first two):
   - `MONGODB_URI`, `JWT_SECRET`
   - `SWEEP_KEY` (new, any long random string, optional)
   - optional policy overrides: see `.env.example`
3. Deploy the Docker image or Node app as you do now. The server listens on
   `X_ZOHO_CATALYST_LISTEN_PORT` (AppSail sets it; default 9000, as documented by Catalyst).
4. Check `GET /api/health`.
5. Optional housekeeping: have a scheduler call
   `POST /api/admin/sweep` with header `x-sweep-key: <SWEEP_KEY>` once a day (cron-job.org, which
   you already use, is fine; Catalyst's own job scheduling also works). **Hours are correct even if
   this never runs**: it only refreshes status flags and deletes pings older than 120 days.
   You can keep your existing `/api/health` keep-alive.

## Database: MongoDB vs Catalyst Data Store
Your architecture document says MongoDB (Mongoose). You described the database as Catalyst Data
Store. Those are different products. I built against **MongoDB**, because that is what the document
and the "same database" instruction describe, and I could not see your server code.

If you really are on Catalyst Data Store, the only file to replace is `src/store/mongo.js`.
`src/store/memory.js` shows the exact interface (about 20 small functions). The engine, API and
app do not change. Two things to plan for in Data Store: a unique index on `eventId`
(or check-then-insert) and range queries on `occurredAt` per user. Tell me and I will write it.

## Old app and new app side by side
Old checkins/dailylogs are untouched and are not read by the new app. Admins start fresh in
`geo_events`. To keep history, keep the old app's data as is; do not migrate.

## API summary
Auth: `POST /api/auth/login`, `/refresh`.  Employee: `GET /api/me/config`, `POST /api/geo/events`,
`GET /api/geo/state|day|month`.  Admin: `GET /api/admin/status|review`, `POST /api/admin/adjust`,
employees and locations CRUD (same paths as before).

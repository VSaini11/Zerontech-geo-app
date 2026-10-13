# Catalyst & FCM Production Deployment Roadmap

This document outlines the step-by-step tasks to transition from the local development stack to **Zoho Catalyst (Data Store + AppSail)** with **Firebase Cloud Messaging (FCM)** instant admin push notifications.

---

## 1. Zoho Catalyst Data Store Migration

Connect the Node server to the existing Catalyst Data Store tables to access existing employees and locations:

### Information Needed from Zoho Catalyst Console
- [ ] **Project ID** / **Environment ID** (Development / Production).
- [ ] **Data Store Table Details**:
  - `users` table: Table ID & Column mapping (`name`, `password`, `role`, `tokenVersion`, `lastKnownLocation`).
  - `locations` table: Table ID & Column mapping (`name`, `latitude`, `longitude`, `radiusMeters`, `assignedEmployees`).
  - `geo_events` table (or new table): Table ID & Column mapping (`eventId`, `userName`, `type`, `occurredAt`, `locationId`, etc.).
  - `admin_tokens` table: Table ID for storing Admin FCM push tokens.
- [ ] **Catalyst SDK Credentials**:
  - `CATALYST_PROJECT_ID`
  - `CATALYST_CLIENT_ID`
  - `CATALYST_CLIENT_SECRET` (or Catalyst server SDK execution environment credentials).

### Server Code Integration
- [ ] Implement `server/src/store/catalyst.js` implementing the same interface as `mongo.js` / `memory.js`.
- [ ] Switch store adapter based on environment variable: `STORE_TYPE=catalyst` (or default fallback).

---

## 2. Docker Container Deployment to Catalyst AppSail

Deploy the server image directly to AppSail:

### Steps
1. **Build Production Image**:
   ```powershell
   cd server
   docker build -t geo-app-server:latest .
   ```
2. **Push to Container Registry / Deploy on AppSail**:
   - Upload either via Catalyst CLI (`catalyst deploy:appsail`) or push the container image to your container registry.
3. **Configure AppSail Environment Variables**:
   - `PORT=9000` (or leave default `X_ZOHO_CATALYST_LISTEN_PORT`).
   - `NODE_ENV=production`.
   - `JWT_SECRET=<secure-random-jwt-secret>`.
   - `TZ_OFFSET_MIN=330` (IST time offset).
   - Catalyst Project credentials & Table IDs.
   - FCM credentials (see Section 3).

---

## 3. Free Firebase Cloud Messaging (FCM) Push Notifications

Setup instant notifications for Admin when any employee enters or exits geofences (closed/open phone):

### Firebase Console Setup (100% Free - Spark Plan)
- [ ] Create a free project in [Firebase Console](https://console.firebase.google.com).
- [ ] Add Android app (`com.gnc.geo_app`) & download `google-services.json` into `app/android/app/`.
- [ ] Generate a Service Account Private Key (`firebase-admin` or HTTP v1 API keys).

### AppSail Server Push Dispatcher
- [ ] Add lightweight FCM push dispatcher in `server/src/service/attendance.js`:
  - When `ENTER` or `PING_IN` occurs: Send `"Employee [Name] Checked In at [Site] • Entered geofence"`.
  - When `EXIT` or `PING_OUT` occurs: Send `"Employee [Name] Checked Out of [Site] • [Reason]"`.
  - Broadcast push to all device tokens found in `admin_tokens`.

### Flutter App Integration
- [ ] Add `firebase_core` & `firebase_messaging` dependencies to `pubspec.yaml`.
- [ ] In Admin Shell: register device token on login via `POST /api/admin/device-token`.
- [ ] Test notification delivery when admin phone is closed, locked, and active.

---

## 4. Verification & Testing Checklist

- [ ] **Data Store Connectivity**: Verify all existing employees and work sites load in the Admin Directory and Locations tab.
- [ ] **AppSail Endpoint Health**: Verify `GET /api/health` returns status `ok`.
- [ ] **Geofencing & Accuracy**: Test employee check-in on physical Android device inside site radius.
- [ ] **Admin Map Precision**: Verify admin sees the live location pin or last-synced position pin on the map.
- [ ] **Excel / CSV Report**: Run a test export of company-wide attendance for a selected period.
- [ ] **Closed-App Notifications**: Confirm Admin gets an instant notification on lock screen when an employee checks in/out.

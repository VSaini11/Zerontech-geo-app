# Why check-in/check-out and worked hours broke after the app was closed for a long time

**Honest note:** I was given the architecture document, not the source code. These causes are
what that design makes *almost certain*, read against your symptoms. Each has a "how to confirm"
query so you can prove it on your live data. The new app removes every one of them by design.

## The core mistake
The old design makes the **phone the authority**: it decides "I am checked in", keeps the open
record id on the phone (`CACHED_ACTIVE_CHECKIN_KEY`), and later says "close record X at time T".
Anything that makes the phone forget, miss, or fail to deliver a single message leaves the server
with a permanently wrong record. A long-closed app hits all of those at once.

| # | Cause (old design) | What you saw | How to confirm | Fix in geo-app |
|---|---|---|---|---|
| 1 | **Checkout depends on a cached `checkInId`.** If the phone's cache is cleared, the app was killed, or the check-in was created by a different run, `PUT /checkins/checkout` has nothing valid to close. | Stuck "Checked in", or checkout silently lost. | `checkins` with `status:"active"` older than 1 day; users with 2+ active rows. | No ids on the phone. The phone sends facts (`ENTER`, `EXIT`, pings). The server derives sessions. Nothing to forget. |
| 2 | **Geofence registration is lost while the app is closed** (reboot, force-stop, OEM cleanup, permission change). No registration means no ENTER when the person walks in. | "Never checked me in when I came into the radius." | Employees whose first event of the day is hours after arrival. | Registration is re-checked every 15 min by WorkManager, on every app open, and after reboot. Geofence uses `initialTriggers: ENTER` so being already inside at registration still reports. A position ping is a second, independent proof of presence. |
| 3 | **Access token expires with no refresh.** After days closed, `SyncWorker` gets 401 on every upload, forever. | Queued punches never arrive; hours missing for days, then "fixed" after re-login. | Server logs: 401 from the worker user-agent; users whose last punch is days old but who work daily. | Short access token + 90-day refresh token. `401` triggers one refresh and a retry. Refresh is revoked only by an admin password reset or account deletion. |
| 4 | **Punches are not idempotent.** The offline queue replays check-in/check-out requests. A retry after a half-finished send creates duplicates; out-of-order delivery closes the wrong record. | Double check-ins, negative or doubled durations. | `checkins` for one user with overlapping time ranges. | Every event has a UUID. The server stores each once. Order is irrelevant: events are sorted by when they happened, not when they arrived. |
| 5 | **A missed exit leaves a session open forever.** Duration is computed when the checkout arrives. If it never does, the record stays `active` and the day's hours are 0 or enormous the next time something closes it. | "Hours counting issue", 20+ hour days. | `checkins` active for more than 16 h. | Hours are computed **on read** from the event log. Missing exit = visit ends at last proof of presence + 15 min, flagged "needs review", shown to the admin. Never more than 16 h. |
| 6 | **Phone clock decides the time.** `checkInTime` is the phone's ISO string. A wrong clock, or a queued event stamped hours ago, writes wrong hours. | Odd start times, hours off by the clock error. | `checkInTime` in the future, or far from `createdAt`. | The phone stamps each upload batch; the server measures the difference and corrects every event in it. Future times are clamped. The on-screen timer uses the server clock. |
| 7 | **Day boundaries.** `DailyLog.date` is built on a server clock (likely UTC). A shift across midnight IST lands on the wrong day. | Hours on the wrong date in the calendar. | Logs for shifts crossing 18:30 UTC. | Days are cut at IST midnight (configurable), sessions are split across the cut. |
| 8 | **GPS jitter.** One noisy fix outside the radius = checkout, next = new check-in. | Many tiny sessions, lost minutes. | Many sessions under 10 min. | Exit + re-enter within 10 minutes is merged. Fixes worse than 100 m accuracy are ignored. Exit needs to be beyond radius + 15 % (hysteresis). |
| 9 | **Reliance on a foreground service and an external keep-alive ping.** Phones that kill background services, or a cold container, drop events. | Works for some phones, not others. | Compare by phone brand. | Uses the OS geofencing API (survives app kill), not a custom service. The server does not need to be warm for correctness: events are queued on the phone and retried. |
| 10 | **Overlapping sites double count.** | Hours above elapsed time. | Sum of durations greater than first-in to last-out. | Overlapping time across sites is merged before totalling. |

## Queries to run on your current MongoDB
```js
// 1 & 5: sessions left open
db.checkins.find({status:"active", checkInTime:{$lt: new Date(Date.now()-16*3600e3)}})
// 1: users with more than one active session
db.checkins.aggregate([{$match:{status:"active"}},{$group:{_id:"$userName",n:{$sum:1}}},{$match:{n:{$gt:1}}}])
// 4: overlapping sessions for a user
db.checkins.find({userName:"NAME"}).sort({checkInTime:1})
// 6: events dated in the future
db.checkins.find({checkInTime:{$gt:new Date()}})
// 8: very short sessions
db.checkins.find({durationMinutes:{$lt:10}, status:"completed"}).count()
```

## What cannot be fixed by software
If the person turns location off, revokes "Allow all the time", or the manufacturer force-stops the
app, no app can see them. geo-app detects this (heartbeat stops, local notification, admin sees
"No signal") instead of silently producing wrong hours.

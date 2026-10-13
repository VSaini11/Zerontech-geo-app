# geo-app

Automatic geofenced attendance (Flutter app + Node/Express server) rebuilt so it stays correct
after the phone has been closed for days.

- `docs/ROOT_CAUSES.md`: the exact failure causes, how to confirm each, how they are fixed
- `server/`: drop-in server, same AppSail + same database collections (`DEPLOY_CATALYST.md`)
- `app/`: Flutter app. Admin: 5 tabs (Status, Locations, Employees, Calendar, Profile).
  Employee: 3 tabs (Status, Calendar, Profile).

## How it works in one paragraph
The phone only reports **facts**: "the OS says I crossed site X" and "my position is here".
Each fact has a unique id, is written to disk first, then uploaded with retries. The server keeps
the facts and **derives** visits and worked hours every time they are read, using fixed rules
(merge flaps, cap at 16 h, cut at IST midnight, merge overlapping sites). Because nothing is
stored as "current state", nothing can get stuck.

## Run the server
```bash
cd server && npm install && npm test        # 23 tests
npm run dev                                  # in-memory, seeded: admin/admin123, asha/asha123
```
## Run the app (Windows PowerShell, Flutter installed)
```powershell
cd app
.\setup.ps1
flutter run --dart-define=API_BASE=http://10.0.2.2:9000    # emulator -> your PC; use your server URL for a phone
flutter analyze
```

## Status of this delivery (please read)
- Server logic: **tested here** (23 passing tests: lost exits, duplicates, reordering, clock skew,
  midnight, overlapping sites, auth refresh and revoke).
- Flutter app: **written but not compiled here** (no Flutter SDK was available in my environment).
  Plugin calls were checked against pub.dev docs, but expect to fix a few small analyzer errors on
  the first `flutter analyze`. Send me the output and I will correct it.
- MongoDB store: written, not run against a live database here. Memory store is what the tests use.
- Causes in `ROOT_CAUSES.md` are inferred from your architecture document, not from your code.

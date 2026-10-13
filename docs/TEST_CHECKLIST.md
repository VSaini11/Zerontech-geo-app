# Device test checklist (run on a real Android phone; emulators do not reproduce OEM behaviour)

Set the test site radius to 100–150 m around a place you can walk in and out of.

1. Sign in, grant all four items on the Status tab. All green.
2. **Cold start while inside:** register site where you stand. Within about 1–2 min you get "Checked in".
3. **Swipe the app away.** Walk out of the circle. Within a few minutes: "Checked out" notification.
   Open the app: hours = time between, no duplicate.
4. **Airplane mode** before walking in. Walk in, wait, walk out, turn data on. Both events upload
   within about 15 min (or open the app = instant). Hours correct.
5. **Reboot** the phone, do not open the app. Walk in. Check-in still happens.
6. **Long closure:** leave the phone off the site for a day with the app closed, then arrive.
   Check-in happens; admin tab shows no phantom hours in between.
7. **Phone off inside the site:** switch phone off for 2 h, switch on. Admin sees a "needs review"
   flag; hours counted only to last signal + 15 min.
8. **Wrong phone clock:** set time 2 h ahead (turn off automatic time). Check-in time shown is still correct.
9. **Password reset** by admin: employee is signed out and sees login with a message.
10. Admin: add site on map, assign employee, add employee, reset password, void a visit.
Server side: `cd server && npm test` (23 tests).

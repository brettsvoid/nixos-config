# Backend: notification history

Read `briefs/_backend-common.md` first; its rules apply. Unit name: `notifications`.

macOS keeps delivered notifications in the usernoted store:
`~/Library/Group Containers/group.com.apple.usernoted/db2/db` (SQLite, WAL mode, with
`db-wal` and `db-shm`). Opening it needs Full Disk Access, which edgebar has today only
because tccd attributes it to kitty (a bare binary gets EPERM). Never write to it.

Build `src-tauri/src/notifications.rs`:
- `notification_history` → `NotificationHistory` per ipc.ts: newest first, at most 100
  items from the last 7 days. Read a consistent snapshot without touching Apple's files:
  copy `db`, `db-wal` and `db-shm` together into a temp dir and open the copy read-only
  (rusqlite with its `bundled` feature is fine). EPERM → `access: "denied"`, file missing
  → `"unavailable"`.
- Find the schema yourself (tables and columns only; `.schema` is fine). Records hold a
  binary plist; parse it with the `plist` crate into app bundle id, title, subtitle, body
  and date. Print counts and which fields parsed, never values.
- `icon`: the app's icon from its bundle id, reusing lib.rs's icon helper
  (`icon_png_data_url`, make it `pub(crate)`) and cache.
- `notification_dismiss { ids }` and `notification_clear`: macOS's store stays untouched,
  so these hide entries in edgebar: keep the hidden ids (and a "cleared before" time for
  clear) in `~/.cache/edgebar/notifications-hidden.json`, written atomically, applied on
  every read. You may create and delete that file.
- Keep each read fast: measure the copy-and-parse time and report it. The UI will read
  on show and refresh about every 15 s while the dashboard is open.

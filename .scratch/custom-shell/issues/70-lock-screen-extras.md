# Lock screen: avatar, weather, notifications, system information

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

More than today's clock, date, field and media card (`lock/LockSurface.qml`, issue 21;
blur, dim and media are settings since issue 29). Caelestia's lock adds a profile
picture, weather, a notification list, a "fetch" card and live CPU, GPU and memory
(`modules/lock/`; ideas only).

Whoever walks past sees a locked screen. So it shows nothing a notification says, no
window titles, and nothing to act on beyond the media controls it has today.

## Proposed choices

1. **Avatar** above the clock: a 96 px circle from issue 52's `user.avatar` (default
   `~/.face`, which does not exist on brett-desktop, checked). With no file, the
   name's first letter, as 52's card does. Alternative: no avatar without a file.
   `lock.avatar` (`true`).
2. **Weather** on the date's line: icon, temperature, condition from issue 49's
   service, without the place. It shows the cache and fetches once as the lock comes up
   if the data is older than 49's refresh time; no timer while locked. Alternative:
   register as a view, so 49 refreshes every 30 minutes all night. Hidden while 49's
   tab and card are both off, which keeps 49's promise to send nothing then.
   `lock.weather` (`true`).
3. **Notifications, privacy first:** under the field, a chip per app that sent
   something since the lock came up: icon, name, count; critical ones in the error
   colour. **No summary, no body:** they can hold messages or one-time codes. Nothing
   opens or dismisses from here. `lock.notifications`: `"off"`, `"apps"` (default),
   `"summaries"`. Alternative default: `"off"`.
4. **System information,** off by default: one line at the bottom left with host name,
   uptime and, on the laptop, battery. Host and uptime read as issue 52 reads them, at
   the clock's minute tick. No live CPU or GPU: that keeps `shell-stats` running.
   `lock.systemInfo` (`false`).
5. **Caps lock warning** in the message line under the field, when no error shows,
   from issue 40's lock-keys state (its `bindlni` is a locked bind, so it fires while
   locked). `lock.capsLock` (`true`).
6. **Screens:** the extras show only on the screen focused as the lock came up; the
   others keep today's clock, date and field. Alternative: every screen. Reason: the
   portrait Dell has little room, and one copy is enough.
7. **Settings** on the Session page, under "Lock screen", beside blur, dim and media.
   **Cost:** nothing moves at rest, as today; the battery comes from UPower's signals;
   at most one weather request per lock; nothing exists while unlocked.

## Acceptance criteria

- [ ] At the defaults with no `~/.face`, the lock is today's plus the letter avatar, the
      weather line, and chips once something arrives.
- [ ] `notify-send 'Code' '123456'` while locked shows only "notify-send · 1", never
      "Code" or the number. `"summaries"` shows "Code", never the number.
- [ ] Caps Lock while locked shows the warning; pressing it again clears it.
- [ ] The extras appear on the focused screen only.
- [ ] No frames drawn in 10 s at rest while locked (QSG render timing, as issue 21).
- [ ] At most one weather request per lock.
- [ ] Costs nothing while unlocked, so nothing in game mode.

## Blocked by

- .scratch/custom-shell/issues/49-weather.md (the weather line only)
- .scratch/custom-shell/issues/52-user-card.md (the avatar's image only)
- .scratch/custom-shell/issues/40-more-bar-entries.md (the caps lock state only)

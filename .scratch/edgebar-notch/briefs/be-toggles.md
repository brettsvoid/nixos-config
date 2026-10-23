# Backend: the dashboard's five quick toggles

Read `briefs/_backend-common.md` first; its rules apply. Unit name: `toggles`.

A probe of this Mac (macOS 26.7.1) already found what works. Its probe sources are in
`/private/tmp/claude-501/-Users-brett-nixos-config/d8cb2a47-141a-461f-86e4-14bdf688cfa3/scratchpad/probes/`
(read them for the exact calls and struct layouts). Key fact: edgebar runs under herdr,
which tccd attributes to kitty, so edgebar holds kitty's permissions (including Full Disk
Access) and kitty's Info.plist usage strings.

Build `src-tauri/src/toggles.rs`: `toggles` returns all five `ToggleState`s in the order
wifi, bluetooth, focus, nightShift, caffeine; `set_toggle { id, on }` sets one and
returns its new state, then emits `toggles` with all five. Each toggle is one entry in a
table (id, read, write), not a branch spread through the code.

- **wifi.** Read with CoreWLAN (`CWWiFiClient sharedWiFiClient` → `interface` →
  `powerOn`, about 1 ms; link CoreWLAN in build.rs). Write with
  `networksetup -setairportpower <device> on|off`, the device found once from
  `networksetup -listallhardwareports`. NEVER run the write. `detail`: "On"/"Off".
- **bluetooth.** Read the notify key `com.apple.bluetooth.power` (`notify_register_check`
  + `notify_get_state` from libc; 1 = on; the probe saw 1, the off value is unvalidated:
  treat any other value as off and say so). Write with IOBluetooth's
  `IOBluetoothPreferenceSetControllerPowerState(int)`, resolved with dlsym, on a worker
  thread with a 3 s timeout: it raises a Bluetooth permission prompt for kitty, which can
  block. On timeout or failure the state's `detail` says Bluetooth permission is needed.
  NEVER call it, or any IOBluetooth getter.
- **focus.** Read `~/Library/DoNotDisturb/DB/Assertions.json` (readable only through Full
  Disk Access): on when it holds an active assertion. You may print its key structure, not
  its values. Write runs a Shortcut: `shortcuts run "<name>"` with the name from a new
  config key `toggles.focusShortcut`, default "Toggle Focus" in config.default.json.
  Brett has no Shortcuts yet (`shortcuts list` prints nothing), so `available` is false
  until a Shortcut of that name exists (cache the list ~30 s), and `detail` tells him to
  make one ("Set Focus" action, Do Not Disturb, Toggle). File unreadable: `available`
  false with a Full Disk Access detail. Don't run any shortcut in tests.
- **nightShift.** CoreBrightness's private `CBBlueLightClient` (dlopen the framework):
  `getBlueLightStatus:` with the 40-byte struct the probe used (from the nightlight
  crate), `setEnabled:` to write. `on` = enabled; `detail` from the mode (off,
  sunset to sunrise, custom schedule). Night Shift is harmless and reversible, so you may
  prove the write once: flip it, read it back, flip it back, all in one ignored test, and
  report both reads.
- **caffeine.** A child `/usr/bin/caffeinate -di -w <edgebar's pid>`, so it dies with
  edgebar; on = the child is alive; off kills it. Safe to prove both ways in a test.

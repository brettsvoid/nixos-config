# Bluetooth: a pairing agent in the shell

Status: ready-for-human
Type: AFK; pairing the controller needs you

## Parent

.scratch/custom-shell/PRD.md

## What to build

A BlueZ pairing agent that the shell runs, so that devices which ask for a passkey
confirmation pair from the Bluetooth page (issue 28). Today they fail, and only
`bluetoothctl` can pair them.

### What was found

22 Oct 2026, brett-desktop: an Xbox Wireless Controller (`A8:8C:3E:2B:D8:3B`, USB ID
`045E:0B13`, Bluetooth Low Energy) did not pair from the page. bluetoothd logged:

```
src/device.c:new_auth() No agent available for request type 2
device_confirm_passkey: Operation not permitted
...
profiles/input/hog-lib.c:report_map_read_cb() Report Map read failed: Encryption required before read/write
```

The controller stayed connected but not paired, and its input was not read. Issue 28
assumed that most controllers need no confirmation. This one does.

Quickshell 0.3.0 cannot do this in QML: its Bluetooth types
(`quickshell-bluetooth.qmltypes`) have no agent.

### How BlueZ agents work (BlueZ 5.87, `man org.bluez.AgentManager`, `man org.bluez.Agent`)

- A program exports an object with the `org.bluez.Agent1` interface on the system bus.
  Then it calls `RegisterAgent(path, capability)` on `org.bluez.AgentManager1` at
  `/org/bluez`. `RequestDefaultAgent(path)` makes it the agent for pairings that other
  programs start, such as the shell's `pair()` call.
- Capabilities: `DisplayOnly`, `DisplayYesNo`, `KeyboardOnly`, `NoInputNoOutput`,
  `KeyboardDisplay`.
- Methods that BlueZ calls: `RequestConfirmation(device, passkey)`,
  `RequestAuthorization(device)` (just-works pairing that another device starts),
  `RequestPinCode`, `RequestPasskey`, `DisplayPinCode`, `DisplayPasskey`,
  `AuthorizeService`, `Cancel` and `Release`. Reject with `org.bluez.Error.Rejected`
  or `org.bluez.Error.Canceled`.
- We do not know yet which of these the controller causes. The log above shows only
  "request type 2", a confirmation. Log each call to find out.

### Decisions (22 Oct 2026)

1. **Native code:** a small Rust program, as the PRD says (like `shell-stats`). It
   registers the agent with the `KeyboardDisplay` capability and makes it the default
   agent. It prints each request as a JSON line and reads the page's answer as a JSON
   line on stdin. Quickshell's `Process` can write to stdin (`stdinEnabled`,
   `write()`). It registers again if bluetoothd restarts or calls `Release`.
2. **Confirmations are accepted without a click,** but only for the device you pressed
   Pair on. This covers `RequestConfirmation`, `RequestAuthorization` and
   `AuthorizeService`. While it pairs, that device's row shows the passkey (6 digits,
   zero-padded). A request for any other device gets `org.bluez.Error.Rejected`.
3. **Every pairing method works from the page,** for full compatibility:
   - `RequestPinCode`: a text field in the row, 1 to 16 letters or digits.
   - `RequestPasskey`: a number field, 0 to 999999.
   - `DisplayPinCode` and `DisplayPasskey`: the row shows the code to type on the
     device. `DisplayPasskey` can come again with the count of keys typed so far.
   - `Cancel` from BlueZ clears the row's prompt. The row's Cancel button ends the
     pairing, as it does now.
4. **The agent runs only while the Bluetooth page shows.** The page starts the program
   when it shows and stops it when it closes, as it does with discovery. So it costs
   nothing at other times (issue 80). Nothing else in the shell pairs: the quick
   toggles (issue 48) only turn the adapter on and off. The adapter's Pairable flag is
   off, so other devices cannot start a pairing with this machine anyway.

## Acceptance criteria

- [ ] The Xbox Wireless Controller pairs from the Bluetooth page without a click after
      Pair. It connects, and Steam sees it as a controller.
- [ ] The row shows the passkey while a confirmation pairs.
- [x] PIN entry, passkey entry and the two display prompts work. If no device at hand
      needs them, test the page in `qs-test` with a stand-in command that prints
      sample requests as JSON lines, and say in a comment what was tested this way.
- [ ] Cancel on the page, and `Cancel` from BlueZ, end the pairing and clear the
      prompt.
- [x] A request for a device other than the one being paired is rejected.
- [ ] A device that needs no confirmation still pairs as before.
- [x] The agent's program runs only while the Bluetooth page shows: check with `ps`.
- [x] The notes in `settings/BluetoothPage.qml` and issue 28 no longer send devices to
      `bluetoothctl`.

## Blocked by

None. It builds on the page from issue 28.

## Comments

**2026-11-08:** Built on the `bluetooth-agent` branch: `shell-bluetooth-agent` (Rust,
zbus) and the page's side in `settings/BluetoothPage.qml`. The controller is yours to
pair, so the first criterion, Cancel during a real pairing and a device with no
confirmation are left for you.

- **How it works:**
  - The page runs `shell-bluetooth-agent` while it shows. The agent registers as the
    default agent (`KeyboardDisplay`), prints each request from BlueZ as a JSON line and
    reads the page's answers on stdin. It registers again when bluetoothd starts or
    sends `Release`, and exits when stdin closes.
  - A killed agent needs no unregistering: bluetoothd watches each agent's bus name and
    drops it when the name goes (`agent_create` adds the watch, `agent_disconnect`
    removes the agent and its default place; `src/agent.c`, BlueZ 5.87).
  - Pair sets the row as the target. Only the target gets answers; any other device is
    rejected. The page logs each line from the agent: `qs log -c custom-shell -f | grep
    shell-bluetooth-agent` shows which requests a device makes.
- **Tested against the real system bus** (no device paired, unpaired or forgotten, the
  adapter left on): the agent's `RegisterAgent` and `RequestDefaultAgent` each got a
  method return from bluetoothd (`:1.11`, seen with `strace` on the agent), with nothing
  on stderr. It exited as soon as stdin closed.
- **Tested against a fake `org.bluez` on a private bus** (the real agent binary, every
  method): answers turned into replies, `accept:false` and bad PINs or passkeys into
  `org.bluez.Error.Rejected`, BlueZ's `Cancel` into `org.bluez.Error.Canceled` for every
  open request, and `Release` and a new `org.bluez` owner each into a new registration.
- **Tested in `qs-test` with a stand-in agent** (a script first on `PATH` that printed
  sample requests for a real nearby device, a Samsung TV, and logged the page's
  answers). A test-only IPC call in the test's copy of the page set the target, so
  nothing was paired:
  - Before Pair, a confirmation was rejected. For the target, confirmation,
    authorisation and service requests were accepted at once, and the row showed
    "Pairing, passkey 001234". The same requests for another nearby device were
    rejected, PIN and passkey requests too.
  - PIN entry: the field took `ab12C` from `ab-12 C` and Return sent it. Passkey entry:
    the field took `012345` from `0x12345678` and Return sent `12345`.
  - "Type 4321 on the device" for `DisplayPinCode`; "Type 005678 on the device" and then
    ", 3 typed" for `DisplayPasskey`.
  - BlueZ's `Cancel` cleared an open PIN field and the page wrote nothing. What the
    row's Cancel button calls answered the open passkey request with `accept:false` and
    cleared the target.
  - A half-typed PIN stayed when the nearby list changed under it (a device hidden in
    the test's copy). The rows now come from a `ScriptModel`: with the old plain array,
    the same test lost the PIN, as every row was made again.
  - `ps`: the agent ran with the page open, stopped on another page, ran again on the
    page, and stopped with the window closed.
- **Not tested:** the row's Cancel button and the end of a pairing (`pairing` turning
  false) during a real pairing, as that needs Pair on a real device.
- **Your checks.** The controller is listed under Paired devices now (BlueZ says
  `Paired: true`, so it was paired outside the page). Steps:
  1. Switch to this branch's build, so `shell-bluetooth-agent` is installed and the
     shell restarts. Open the settings on the Bluetooth page (Super+I, Bluetooth).
     `pgrep -a shell-bluetooth` shows one process.
  2. In a terminal: `qs log -c custom-shell -f | grep shell-bluetooth-agent`.
  3. Forget the Xbox Wireless Controller under Paired devices (the bin icon).
  4. Hold the controller's pair button until the Xbox logo flashes fast. It shows under
     Nearby.
  5. Press Pair on its row and do nothing else. Does the row show "Pairing, passkey"
     and six digits, then the controller move to Paired devices and connect (the logo
     stays lit)? Which lines did the log in step 2 show?
  6. Does Steam list it as a controller (Steam, Settings, Controller)?
  7. Cancel: pair a phone from the page. The row shows the passkey while the phone
     asks you to confirm it; do the numbers match? Press Cancel on the row instead of
     confirming. Does the row go back to the phone's address, and the phone's dialog
     close?
  8. A device with no confirmation (a mouse or headset in pairing mode): does Pair
     still pair it?
  9. Close the settings window. `pgrep -a shell-bluetooth` shows nothing.

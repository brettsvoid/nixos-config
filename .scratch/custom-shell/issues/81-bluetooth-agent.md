# Bluetooth: a pairing agent in the shell

Status: ready-for-agent
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
- [ ] PIN entry, passkey entry and the two display prompts work. If no device at hand
      needs them, test the page in `qs-test` with a stand-in command that prints
      sample requests as JSON lines, and say in a comment what was tested this way.
- [ ] Cancel on the page, and `Cancel` from BlueZ, end the pairing and clear the
      prompt.
- [ ] A request for a device other than the one being paired is rejected.
- [ ] A device that needs no confirmation still pairs as before.
- [ ] The agent's program runs only while the Bluetooth page shows: check with `ps`.
- [ ] The notes in `settings/BluetoothPage.qml` and issue 28 no longer send devices to
      `bluetoothctl`.

## Blocked by

None. It builds on the page from issue 28.

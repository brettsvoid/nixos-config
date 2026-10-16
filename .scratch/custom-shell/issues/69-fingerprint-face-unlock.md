# Lock screen: fingerprint and face unlock

Status: ready-for-human
Type: HITL (needs a fingerprint reader or an IR camera, and enrolling)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Unlock with a finger (fprintd) or a face (howdy) while the password field keeps working.
Caelestia runs password, fingerprint and howdy PAM contexts side by side, each with its
own PAM file (`modules/lock/Pam.qml`, `assets/pam.d/`; ideas only).

Today `lock/Lock.qml` runs one `PamContext` on `/etc/pam.d/custom-shell`, made by
`security.pam.services.custom-shell = { }` in `modules/system/nixos/hyprland.nix`:
`pam_unix`, then `pam_deny` (checked). Each `PamContext` runs in its own process, so
several can run at once. nixpkgs has fprintd 1.94.5, howdy 3.0.0 and
linux-enable-ir-emitter 6.1.2, with NixOS modules (checked).

## Proposed choices

1. **Which device.** brett-desktop has no reader and no `/dev/video*` (checked).
   **Recommended: a USB fingerprint reader** from libfprint's supported list, for the
   desktop. Alternatives: an IR (Windows Hello) camera for howdy, which NixOS's own
   module warns a printed photo can fool; or neither, and close this issue.
   **Question:** does the laptop have a reader or an IR camera (`lsusb`,
   `ls /dev/video*` on it; unchecked)?
2. **Three PAM services, so the password never waits.** With `services.fprintd.enable`,
   every service gets `pam_fprintd` before `pam_unix` (`fprintAuth` defaults to it,
   pam.nix line 378), and the password waits for the reader's 30 s timeout. So:
   - `custom-shell`: `fprintAuth = false; howdy.enable = false;` (password only).
   - `custom-shell-fingerprint`, with fprintd on: `unixAuth = false; fprintAuth = true;`
     (pam_fprintd's defaults: 3 tries, 30 s; `pam_fprintd.c`).
   - `custom-shell-face`, with howdy on: `unixAuth = false; howdy.enable = true;
     howdy.control = "sufficient";`.
3. **Other services stay password-only:** `fprintAuth = false` and
   `howdy.enable = false` on greetd, login, sudo, su, polkit-1 and the rest, from one
   list. Alternative: NixOS's default, finger first everywhere. Reason: there the
   finger comes first and the password waits.
4. **Fingerprint runs with the lock,** beside the password. After its 30 s it starts
   again on the next key press or pointer move, so the reader does not cycle all night.
   After 3 failed fingers it stops and says "Use your password". A glyph under the
   field shows its state and PAM's message ("Place your finger…").
5. **Face runs on Enter in an empty field** (Caelestia's idea), so the camera is off
   while nobody is there. Typing stops it.
6. **Enrolling** stays in a terminal (`fprintd-enroll`, `sudo howdy add`), written down
   in `docs/lock-screen.md`. Alternative: buttons on the Session page.
7. **Settings** on the Session page, shown while their PAM file exists:
   `lock.fingerprint`, `lock.face` (`true`). A host turns the hardware on in Nix
   (`services.fprintd.enable`, or `services.howdy.enable` and
   `services.linux-enable-ir-emitter.enable`). **Cost:** PAM processes only while
   locked and checking; nothing in game mode.

## Acceptance criteria

- [ ] With no reader set up, the lock behaves exactly as today.
- [ ] An enrolled finger unlocks; a wrong one says so; the password works meanwhile.
- [ ] After 3 failed fingers, the password still unlocks.
- [ ] `sudo` and the greetd login still ask only for the password.
- [ ] Face (if chosen): Enter in an empty field starts it; typing stops it.
- [ ] After suspend and resume, the fingerprint works again.
- [ ] `lock-recover` still gets you back in (issue 21's steps).

## Blocked by

- None (needs the hardware from choice 1)

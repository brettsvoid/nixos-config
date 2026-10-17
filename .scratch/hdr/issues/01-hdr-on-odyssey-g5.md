# HDR on the Odyssey G5

Status: ready-for-human
Type: HITL

## What to build

HDR on the Odyssey G5 (DP-1) for fullscreen games and video, with VRR still on. Hyprland
turns HDR on by itself while a fullscreen window sends HDR (`render:cm_auto_hdr`, on by
default). That needs `render:cm_enabled = true` in `modules/home/desktop/hyprland.nix`,
which is `false` now.

## What is known (13 October 2026)

- Hyprland 0.56.2 turns HDR and VRR on and off separately, so the two settings don't
  block each other in Hyprland itself. The G5's EDID has HDR10 (PQ, BT2020) with a
  maximum of about 302 nits, the same as its SDR brightness. Samsung's spec page
  gives an 8-bit panel and DisplayPort 1.2.
- DisplayPort 1.2 carries 17.28 Gbit/s. 2560x1440 at 165 Hz needs 19.1 Gbit/s at
  10 bpc, so 10-bit only fits at 120 Hz or below.
- **The display hung twice** with NVIDIA 595.104.02 (open modules) on kernel 6.18.53.
  Each time the screen froze, and a power-off was the only way out:
  1. 21:14:10: `hyprctl keyword` with `cm,hdr,vrr,1` on the G5. Kernel: `NVRM: Xid 56`
     (display channel exception) within 1 s, then "Lost display notification" and
     another Xid 56. A `hyprctl reload` at 21:16:15 gave a third. At 21:18:58:
     "Flip event timeout".
  2. 21:26:00: an HDR10 clip played fullscreen in mpv (`--vo=gpu-next
     --target-colorspace-hint=yes --target-colorspace-hint-mode=source`).
     Hyprland's auto-HDR switched the G5 to HDR with VRR on. Xid 56 at 21:26:02.
- Both times HDR and VRR came on together, so it is not known whether HDR alone hangs it.
- During the first hang, KMS still reported the new state as applied (PQ metadata,
  BT2020, VRR_ENABLED=1). Check `journalctl -k | grep -E 'Xid|Flip event'` after each
  test step. Don't rely only on `hyprctl` or `drm_info`.
- With `cm_enabled = true` and the monitor in SDR, there were no errors.

## Newer drivers

- In the pinned nixpkgs (24 September 2026), `nvidiaPackages.latest` is 615.71.09, a
  new feature branch. `beta` (595.45.04) is older than what runs now. nixos-unstable
  has the same versions. NVIDIA has released 615.78.08 (7 October), but nixpkgs
  doesn't have it yet.
- No 610 or 615 release note mentions Xid 56, HDR with VRR, or display channel
  errors. 610 added HDR output on Wayland and the per-plane DRM colour pipeline API.
  That API needs Linux 6.19; this machine runs 6.18.53. A known issue in 610: a blank
  screen on enabling HDR with some compositors, worked around with the nvidia-drm
  `color_pipeline` module parameter.
- To try it: make `package` in `modules/system/nixos/nvidia.nix` a `lib.mkDefault`.
  Then set `hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.latest`
  in `brett-desktop.nix` only. Roll back by picking the previous generation at boot.

## Questions

1. Is HDR worth another hang? The G5's HDR has no brightness above SDR white, and
   Skyrim only outputs SDR.
2. If yes, which driver? (a) 615.71.09 from the pinned nixpkgs now. (b) Wait for
   615.78.08 or a later 595 point release in nixpkgs. (c) Kernel 6.19 plus a 610/615
   driver, for the colour pipeline API.
3. Do you accept a test that may hang the display? Save your work and close games
   before it.

## Test recipe (only with the user's go-ahead)

1. Set `cm_enabled = true`, rebuild, then log out and back in. Hyprland only offers
   `wp_color_manager_v1` when it starts. Check with `wayland-info`.
2. HDR without VRR first: `hyprctl keyword misc:vrr 0`, then play the HDR10 clip
   fullscreen on DP-1 with the mpv flags above. A test clip:
   `ffmpeg -f lavfi -i testsrc2=size=2560x1440:rate=100:duration=20 -vf format=yuv420p10le
   -c:v libx265 -x265-params "hdr10=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(3000000,1):max-cll=300,200"
   hdr10-test.mkv`.
3. Check `journalctl -k` for Xid. If it is clean, play it again with `misc:vrr 2`.
4. NVIDIA is card1 since the 13 October reboots (it was card0), so look it up rather
   than hard-coding `/sys/class/drm/card0-DP-1`.

## Comments

**2026-10-13:** Parked by the user. The `cm_enabled = true` change is reverted in the
repo (not committed). The running session keeps it until the next rebuild and re-login.
Memory: `hdr-vrr-odyssey-g5`.

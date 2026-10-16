# GIF and video wallpapers, subfolders and search

Status: ready-for-human
Type: AFK (once the choices are approved)

## Parent

.scratch/custom-shell/PRD.md

## What to build

Animated wallpapers (GIF and video), wallpapers in subfolders of the wallpaper folder,
and a search field in the picker. ambxst has all three
(`modules/widgets/dashboard/wallpapers/`: `find` over the tree, subfolder chips, GIF and
video through `mpvpaper`); ideas only.

- Today only `.jpg`, `.jpeg`, `.png` and `.webp` at the top of the folder count: in
  `dashboard/WallpaperTab.qml` (a `FolderListModel`), `wallpaper-thumbnails`,
  `Wallpaper.random()` and `generate-theme` (`-maxdepth 1`). `~/Pictures/Wallpapers`
  holds 19 images and no subfolders.
- Issue 29's options apply: the folder (41) is the root, fill (42) crops or fits, and the
  timed change (43) picks at random, paused in game mode.
- `mpvpaper` is installed only through ambxst, so it goes with issue 23. nixpkgs has
  `mpvpaper` 1.9, `qt6.qtmultimedia` 6.11.2 (Quickshell's Qt) and `ffmpeg-headless`
  9.0.1. The desktop has NVDEC (`libnvcuvid`) and NVIDIA's VA-API driver.
- Each frame of a moving Background-layer surface also makes Hyprland blur the
  background again while a tiled window shows (issue 74), on top of the decode.

## Proposed choices

1. **Video and GIF through `mpvpaper`, one per screen** (`no-audio loop hwdec=auto`,
   `panscan` from the fill setting), each with an mpv IPC socket under
   `$XDG_RUNTIME_DIR`. The shell pauses and resumes it through Quickshell's `Socket`, so
   no process starts per change. Alternative: Qt Multimedia's `Video` in the wallpaper
   window (one surface, plain bindings; whether it loads in `qs` and decodes on the GPU
   is unchecked). Reason: mpv decodes through NVDEC, which this machine has; Qt's path
   here is unchecked.
2. **It plays only while the desktop is in view** (the rule from issue 74: no windows on
   that screen's workspace, nothing fullscreen, not locked). Otherwise it pauses.
   Game mode stops it (`mpvpaper` exits) and it starts again after.
3. **A still for everything else:** `ffmpeg` takes a frame 1 s in; ImageMagick (already
   in `wallpaper-thumbnails`) takes a GIF's first. matugen, the lock screen, the picker's
   thumbnail and the shell's wallpaper window under the video all use the still. Both
   are Background-layer surfaces: check that `mpvpaper`'s draws on top.
4. **Kinds:** `.gif`, `.mp4`, `.webm`, `.mkv`, `.mov`. Always muted.
5. **Subfolders:** the picker lists the whole tree (three levels deep) from
   `wallpaper-thumbnails`, which prints each file as it goes. Chips above the grid:
   "All", then each top-level subfolder. Thumbnails are named by the relative path. A new
   file in a subfolder shows the next time the tab opens. Alternative: top level only,
   with subfolders as chips that switch the folder.
6. **Search:** a field above the grid; typing filters by name and path with
   `launcher/fuzzy.js`. Escape clears it, and the arrows still move through the grid.
7. **The timed change picks still images only.** Alternative: every kind. Reason: a
   video started by a timer costs GPU time no one asked for.
8. **Settings** (Appearance page): `wallpaper.subfolders` (on; nothing changes today, as
   there are none) and `wallpaper.animate` (on; off shows animated kinds as their still).
9. **Packages:** `mpvpaper` and `ffmpeg-headless` (in `generate-theme` and
   `wallpaper-thumbnails`).
10. **Cost:** nothing plays unless a GIF or video is the wallpaper. Then one decode per
    screen while the desktop shows, and none in game mode.

## Acceptance criteria

- [ ] A video and a GIF can be chosen, fill or fit, on both screens, without sound.
- [ ] Each pauses when a window opens on its screen, and plays again when it closes.
- [ ] In game mode no `mpvpaper` runs; after it the video plays again.
- [ ] The theme, lock screen and thumbnail come from the still.
- [ ] GPU decode and use (`nvidia-smi dmon`) while playing and while paused are noted here.
- [ ] Images in subfolders show, chips filter them, and search finds them by name.
- [ ] A restart of the shell leaves no stray `mpvpaper`.

## Blocked by

- None

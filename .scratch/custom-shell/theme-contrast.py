# theme-contrast.py [wallpaper]: for every matugen scheme, dark and light, prints the
# colours the shell draws text and cues in and their WCAG contrast against the text
# (theme/Theme.qml: text is on_background, subtext on_surface, primary, error). A ratio
# near 1.00 means the two cannot be told apart by lightness, only by hue if there is one.
# matugen runs with --dry-run, so the live theme is left alone. The wallpaper defaults to
# the saved choice; MATUGEN names the binary if it is not on PATH:
#   MATUGEN=$(nix build --no-link --print-out-paths .#nixosConfigurations.brett-desktop.pkgs.matugen)/bin/matugen
import json
import os
import pathlib
import subprocess
import sys

SCHEMES = ["neutral", "tonal-spot", "content", "fidelity", "expressive", "fruit-salad", "monochrome", "rainbow"]
PAIRS = [("primary", "on_background"), ("on_surface", "on_background"), ("on_surface_variant", "on_background"), ("error", "on_background"), ("primary", "background")]


def luminance(hex_colour):
    h = hex_colour.lstrip("#")
    channels = (int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))
    r, g, b = (c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4 for c in channels)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    high, low = sorted((luminance(a), luminance(b)), reverse=True)
    return (high + 0.05) / (low + 0.05)


if len(sys.argv) > 1:
    wallpaper = sys.argv[1]
else:
    state = pathlib.Path(os.environ.get("XDG_STATE_HOME", pathlib.Path.home() / ".local/state")) / "custom-shell/wallpaper.json"
    wallpaper = json.loads(state.read_text())["path"]
matugen = os.environ.get("MATUGEN", "matugen")

print(wallpaper)
print(f"{'scheme':18}" + "".join(f"{a}/{b}".rjust(32) for a, b in PAIRS))
for scheme in SCHEMES:
    for mode in ("dark", "light"):
        out = subprocess.run(
            [matugen, "image", wallpaper, "--source-color-index", "0", "--dry-run", "-j", "hex", "-t", f"scheme-{scheme}", "-m", mode],
            capture_output=True, text=True, check=True,
        ).stdout
        colours = {k: v["default"]["color"] for k, v in json.loads(out)["colors"].items()}
        cells = (f"{colours[a]} {colours[b]} {contrast(colours[a], colours[b]):5.2f}".rjust(32) for a, b in PAIRS)
        print(f"{scheme + '-' + mode:18}" + "".join(cells))

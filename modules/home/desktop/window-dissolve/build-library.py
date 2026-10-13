"""Builds the window effect library (window-dissolve.nix runs this in a Nix build).

Usage: build-library.py OUT OWN_DIR [--liixini DIR REV] [--nirimation DIR REV]

Needs glslangValidator and qsb on PATH. Writes to OUT:
- shaders/<id>-<open|close>.glsl: HyprWindowShade shaders, one per effect and kind.
- previews/<id>-<open|close>.frag.qsb: the same shaders for a Qt ShaderEffect (the
  shell's effect picker).
- index.json: every effect, with its name, source and durations.
- excluded.json: ported effects left out because they do not compile, and why.
- LICENSE-<collection>: the licence of each collection taken from.

Every shader is compiled here, as the plugin's GLSL ES 3.20 (glslang) and as the
preview (qsb). One of ours that fails stops the build. A ported one is left out
instead, so a broken effect upstream does not break a rebuild.

Our own effects are OWN_DIR/<id>-<open|close>.glsl as they are. The two collections
are niri custom-shader functions (`vec4 open_color(vec3 coords_geo, vec3 size_geo)`
and close_color), which a wrapper turns into HyprWindowShade shaders, so a new effect
upstream needs no hand edits:
- liixini/shaders: <effect>/{open,close}.glsl with a `config` (or open-config and
  close-config) holding duration-ms and curve, or spring.
- Xansidev/nirimation: animations/<effect>.kdl, niri config with window-open and
  window-close blocks.
"""

import json
import math
import re
import shutil
import subprocess
import sys
from pathlib import Path

import kdl

PLUGIN_MAX_DURATION = 5.0  # HyprWindowShade clamps @duration to this.

COLLECTIONS = {
    "liixini": {
        "url": "https://github.com/liixini/shaders",
        "licence": "MIT, Copyright (c) 2026 liixini",
    },
    "nirimation": {
        "url": "https://github.com/Xansidev/nirimation",
        "licence": "MIT, Copyright (c) 2025 Xansi.net",
    },
}

# Our own effects' names and descriptions, by id.
OWN = {
    "none": ("None", "Hyprland's own animation, with no shader."),
    "dissolve": ("Dissolve", "Burns through a noise pattern. The default."),
    "fade": ("Fade", "A plain fade."),
}


def display_name(slug):
    return slug.replace("-", " ").replace("_", " ").capitalize()


# ── Timing ────────────────────────────────────────────────────────────────────


def spring_duration(damping, stiffness, epsilon):
    """How long a niri spring from 0 to 1 takes to settle, in seconds.

    Stepped like niri's own (1 ms), until both the distance to 1 and the velocity are
    within epsilon.
    """
    c = 2.0 * damping * math.sqrt(stiffness)
    x, v, t, dt = 0.0, 0.0, 0.0, 0.001
    while t < PLUGIN_MAX_DURATION:
        a = -stiffness * (x - 1.0) - c * v
        v += a * dt
        x += v * dt
        t += dt
        if abs(x - 1.0) <= epsilon and abs(v) <= epsilon:
            break
    return t


def curve_glsl(timing):
    """GLSL for `float niri_curve(float t)`, t the linear progress 0..1.

    niri hands shaders the eased progress, so the wrapper eases the plugin's linear one
    the same way. A spring can overshoot 1; niri_clamped_progress clamps it.
    """
    kind = timing["kind"]
    if kind == "spring":
        z, k, d = timing["damping"], timing["stiffness"], timing["duration"]
        w0 = math.sqrt(k)
        head = f"    float s = t * {d:.6f};\n"
        if abs(z - 1.0) < 1e-6:
            body = f"    return 1.0 - exp(-{w0:.6f} * s) * (1.0 + {w0:.6f} * s);\n"
        elif z < 1.0:
            wd = w0 * math.sqrt(1.0 - z * z)
            body = (
                f"    return 1.0 - exp(-{z * w0:.6f} * s) * (cos({wd:.6f} * s)"
                f" + {z * w0 / wd:.6f} * sin({wd:.6f} * s));\n"
            )
        else:
            r = math.sqrt(z * z - 1.0)
            r1, r2 = -w0 * (z - r), -w0 * (z + r)
            body = (
                f"    return 1.0 - ({r2:.6f} * exp({r1:.6f} * s)"
                f" - {r1:.6f} * exp({r2:.6f} * s)) / ({r2 - r1:.6f});\n"
            )
        return f"// A spring: damping ratio {z}, stiffness {k}.\nfloat niri_curve(float t) {{\n{head}{body}}}\n"
    curve = timing["curve"]
    if curve == "linear":
        expr = "t"
    elif curve == "ease-out-quad":
        expr = "1.0 - (1.0 - t) * (1.0 - t)"
    elif curve == "ease-out-cubic":
        expr = "1.0 - pow(1.0 - t, 3.0)"
    elif curve == "ease-out-expo":
        expr = "t >= 1.0 ? 1.0 : 1.0 - pow(2.0, -10.0 * t)"
    elif curve == "cubic-bezier":
        x1, y1, x2, y2 = timing["points"]
        # Find the bezier's parameter for this x by bisection, then its y.
        return (
            f"// cubic-bezier({x1}, {y1}, {x2}, {y2})\n"
            "float niri_bezier(float a, float b, float u) {\n"
            "    float v = 1.0 - u;\n"
            "    return 3.0 * v * v * u * a + 3.0 * v * u * u * b + u * u * u;\n"
            "}\n"
            "float niri_curve(float t) {\n"
            "    float lo = 0.0, hi = 1.0;\n"
            "    for (int i = 0; i < 24; i++) {\n"
            "        float mid = 0.5 * (lo + hi);\n"
            f"        if (niri_bezier({x1:.6f}, {x2:.6f}, mid) < t) lo = mid; else hi = mid;\n"
            "    }\n"
            f"    return niri_bezier({y1:.6f}, {y2:.6f}, 0.5 * (lo + hi));\n"
            "}\n"
        )
    else:
        raise ValueError(f"unknown niri curve {curve!r}")
    return f"// {curve}\nfloat niri_curve(float t) {{\n    return {expr};\n}}\n"


def parse_liixini_config(text):
    timing = {}
    for line in text.splitlines():
        words = line.split()
        if not words:
            continue
        if words[0] == "duration-ms":
            timing["duration"] = int(words[1]) / 1000.0
        elif words[0] == "curve":
            timing["kind"] = "curve"
            timing["curve"] = words[1].strip('"')
            if timing["curve"] == "cubic-bezier":
                timing["points"] = [float(w) for w in words[2:6]]
        elif words[0] == "spring":
            props = dict(w.split("=") for w in words[1:])
            timing["kind"] = "spring"
            timing["damping"] = float(props["damping-ratio"])
            timing["stiffness"] = float(props["stiffness"])
            timing["epsilon"] = float(props["epsilon"])
    return finish_timing(timing)


def finish_timing(timing):
    if timing.get("kind") == "spring":
        timing["duration"] = spring_duration(
            timing["damping"], timing["stiffness"], timing["epsilon"]
        )
    else:
        timing.setdefault("kind", "curve")
        timing.setdefault("curve", "ease-out-cubic")
        timing.setdefault("duration", 0.25)
    timing["duration"] = min(timing["duration"], PLUGIN_MAX_DURATION)
    return timing


# ── Wrapping a niri function ─────────────────────────────────────────────────

WRAPPER = """#version 320 es
// {name} ({kind}), from {collection} ({url}) at {rev}.
// Licence: {licence}; see LICENSE-{collection} beside this folder.
//
// Generated by build-library.py (nixos-config, window-dissolve) from the effect's niri
// custom-shader, below the wrapper: improve the wrapper there rather than this file.
//
// @duration {duration:.3f}
precision highp float;

in vec2 v_texcoord;
out vec4 fragColor;
uniform sampler2D tex;
uniform float progress;
uniform float seed;
uniform vec2 surface_size;
uniform vec4 window_rect;

// niri's inputs, from the plugin's (set in main).
float niri_progress;
float niri_clamped_progress;
float niri_random_seed;
mat3 niri_geo_to_tex;

// niri samples the window's own texture. Outside the window there is nothing: for a
// close, the plugin's texture is a monitor-sized snapshot with the window in
// window_rect.
vec4 niri_sample(vec2 st) {{
    vec2 local = (st - window_rect.xy) / window_rect.zw;
    if (any(lessThan(local, vec2(0.0))) || any(greaterThan(local, vec2(1.0))))
        return vec4(0.0);
    return texture(tex, st);
}}
#define niri_tex tex
#define texture2D(sampler_, st_) niri_sample(st_)

{curve}
// ── The niri custom-shader ──────────────────────────────────────────────────
{body}
// ── End of the niri custom-shader ───────────────────────────────────────────

void main() {{
{guard}    niri_progress = niri_curve(clamp(progress, 0.0, 1.0));
    niri_clamped_progress = clamp(niri_progress, 0.0, 1.0);
    niri_random_seed = seed;
    // Geometry (0..1 across the window) to texture coordinates.
    niri_geo_to_tex = mat3(window_rect.z, 0.0, 0.0,
                           0.0, window_rect.w, 0.0,
                           window_rect.x, window_rect.y, 1.0);
    vec2 geo = (v_texcoord - window_rect.xy) / window_rect.zw;
    vec3 size = vec3(surface_size * window_rect.zw, 1.0);
    fragColor = {entry}(vec3(geo, 1.0), size){tail};
}}
"""

# kitty maps a 1x1 placeholder first and its real frame up to 0.2 s later; the plugin
# shades at the buffer's size, so the effect would paint one pixel over the window.
OPEN_GUARD = """    // kitty and others map a 1x1 placeholder before their first real frame, which
    // the plugin would stretch over the window: show nothing until the real one.
    if (textureSize(tex, 0).x <= 1) {
        fragColor = vec4(0.0);
        return;
    }
"""

# The plugin holds the closing window until @duration ends and requires it to be fully
# transparent by then; a niri effect that leaves a trace would vanish in one frame.
CLOSE_TAIL = " * (1.0 - smoothstep(0.97, 1.0, progress))"


def wrap(body, kind, timing, name, collection, rev):
    entry = f"{kind}_color"
    if not re.search(rf"\bvec4\s+{entry}\s*\(", body):
        raise ValueError(f"{name} ({kind}) has no {entry}()")
    meta = COLLECTIONS[collection]
    return WRAPPER.format(
        name=name,
        kind=kind,
        collection=collection,
        url=meta["url"],
        rev=rev,
        licence=meta["licence"],
        duration=timing["duration"],
        curve=curve_glsl(timing),
        body=body.strip("\n"),
        guard=OPEN_GUARD if kind == "open" else "",
        entry=entry,
        tail=CLOSE_TAIL if kind == "close" else "",
    )


# ── The collections ──────────────────────────────────────────────────────────


def liixini_effects(root):
    for effect in sorted(p for p in root.iterdir() if p.is_dir()):
        if effect.name.startswith("."):
            continue
        kinds = {}
        for kind in ("open", "close"):
            shader = effect / f"{kind}.glsl"
            if not shader.exists():
                continue
            config = effect / f"{kind}-config"
            if not config.exists():
                config = effect / "config"
            text = config.read_text() if config.exists() else ""
            kinds[kind] = (shader.read_text(), parse_liixini_config(text))
        if kinds:
            yield effect.name, "", kinds


def kdl_timing(node):
    timing = {}
    for child in node.nodes:
        if child.name == "duration-ms":
            timing["duration"] = float(child.args[0]) / 1000.0
        elif child.name == "curve":
            timing["kind"] = "curve"
            timing["curve"] = str(child.args[0])
            if timing["curve"] == "cubic-bezier":
                timing["points"] = [float(a) for a in child.args[1:5]]
        elif child.name == "spring":
            timing["kind"] = "spring"
            timing["damping"] = float(child.props["damping-ratio"])
            timing["stiffness"] = float(child.props["stiffness"])
            timing["epsilon"] = float(child.props["epsilon"])
    return finish_timing(timing)


def find_nodes(nodes, name):
    for node in nodes:
        if node.name == name:
            yield node
        yield from find_nodes(node.nodes, name)


def nirimation_effects(root):
    for path in sorted(root.glob("*.kdl")):
        text = path.read_text()
        # The first line of the leading // comment says what the effect does, up to
        # its first full stop; credit lines (links, "Original ...") are skipped, and
        # the rest is notes on tuning.
        description = ""
        for line in text.splitlines():
            if not line.startswith("//"):
                break
            line = line[2:].strip()
            if line and "http" not in line and not line.startswith("Original"):
                description = line.split(". ")[0].rstrip(".") + "."
                break
        document = kdl.parse(text)
        kinds = {}
        for kind in ("open", "close"):
            for node in find_nodes(document.nodes, f"window-{kind}"):
                shader = next((c for c in node.nodes if c.name == "custom-shader"), None)
                if shader is not None:
                    kinds[kind] = (str(shader.args[0]), kdl_timing(node))
        if kinds:
            yield path.stem, description, kinds


# ── Previews for the shell's picker ──────────────────────────────────────────

DECLARATION = re.compile(
    r"^\s*(?:uniform\s+(\w+)\s+(\w+)|in\s+vec2\s+v_texcoord|out\s+vec4\s+fragColor)\s*;.*$",
    re.MULTILINE,
)


def preview(shader):
    """The shader for a Qt ShaderEffect: Vulkan-style GLSL, its uniforms in Qt's block.

    The picker sets each uniform by name (progress, seed, window_rect, surface_size);
    `tex` is the sample window it draws.
    """
    uniforms = []
    for match in DECLARATION.finditer(shader):
        kind, name = match.group(1), match.group(2)
        if name and kind != "sampler2D":
            uniforms.append((kind, name))
    body = DECLARATION.sub("", shader)
    body = re.sub(r"^\s*#version.*$", "", body, flags=re.MULTILINE)
    body = re.sub(r"^\s*precision\s+\w+\s+\w+\s*;.*$", "", body, flags=re.MULTILINE)
    members = "".join(f"    {kind} {name};\n" for kind, name in uniforms)
    return (
        "#version 440\n"
        "layout(location = 0) in vec2 qt_TexCoord0;\n"
        "layout(location = 0) out vec4 fragColor;\n"
        "layout(std140, binding = 0) uniform buf {\n"
        "    mat4 qt_Matrix;\n"
        "    float qt_Opacity;\n"
        f"{members}"
        "};\n"
        "layout(binding = 1) uniform sampler2D tex;\n"
        "#define v_texcoord qt_TexCoord0\n" + body
    )


# ── Main ─────────────────────────────────────────────────────────────────────


def duration_of(shader):
    match = re.search(r"@duration\s+([0-9.]+)", shader)
    return min(float(match.group(1)), PLUGIN_MAX_DURATION) if match else 0.3


class CompileError(Exception):
    pass


def compile_check(command):
    result = subprocess.run(command, capture_output=True, text=True)
    # qsb prints "Shader baking failed" and still exits 0.
    output = (result.stdout + result.stderr).strip()
    if result.returncode != 0 or "failed" in output.lower():
        raise CompileError(output)


def main(argv):
    out, own = Path(argv[0]), Path(argv[1])
    sources = {}
    rest = argv[2:]
    while rest:
        flag, directory, rev = rest[:3]
        sources[flag.lstrip("-")] = (Path(directory), rev)
        rest = rest[3:]

    (out / "shaders").mkdir(parents=True)
    (out / "previews").mkdir()
    index = []
    excluded = []

    def add(effect_id, entry, shaders):
        for kind, shader in shaders.items():
            path = out / "shaders" / f"{effect_id}-{kind}.glsl"
            frag = out / "previews" / f"{effect_id}-{kind}.frag"
            path.write_text(shader)
            frag.write_text(preview(shader))
            try:
                compile_check(["glslangValidator", "-S", "frag", str(path)])
                # SPIR-V for Quickshell's Vulkan renderer, GLSL for the others.
                compile_check(["qsb", "--glsl", "300 es,330", "-o", f"{frag}.qsb", str(frag)])
            except CompileError as error:
                if entry["source"] == "own":
                    sys.exit(f"{path.name} does not compile:\n{error}")
                path.unlink()
                Path(f"{frag}.qsb").unlink(missing_ok=True)
                excluded.append({"id": effect_id, "kind": kind, "error": str(error)})
                print(f"left out {effect_id} ({kind}): it does not compile", file=sys.stderr)
                continue
            finally:
                frag.unlink()
            entry[kind] = {"duration": round(duration_of(shader), 3)}
        if "open" in entry or "close" in entry:
            index.append(entry)

    own_ids = sorted({p.stem.rsplit("-", 1)[0] for p in own.glob("*-*.glsl")})
    for effect_id in own_ids:
        shaders = {
            kind: (own / f"{effect_id}-{kind}.glsl").read_text()
            for kind in ("open", "close")
            if (own / f"{effect_id}-{kind}.glsl").exists()
        }
        name, description = OWN.get(effect_id, (display_name(effect_id), ""))
        entry = {
            "id": effect_id,
            "name": name,
            "source": "own",
            "description": description,
        }
        add(effect_id, entry, shaders)

    readers = {"liixini": liixini_effects, "nirimation": nirimation_effects}
    for collection, (root, rev) in sources.items():
        licence = next(root.glob("LICENSE*"))
        shutil.copyfile(licence, out / f"LICENSE-{collection}")
        effects_root = root / "animations" if collection == "nirimation" else root
        for slug, description, kinds in readers[collection](effects_root):
            name = display_name(slug)
            shaders = {
                kind: wrap(body, kind, timing, name, collection, rev)
                for kind, (body, timing) in kinds.items()
            }
            entry = {
                "id": f"{collection}-{slug}",
                "name": name,
                "source": collection,
                "description": description,
            }
            add(entry["id"], entry, shaders)

    (out / "index.json").write_text(json.dumps(index, indent=2) + "\n")
    (out / "excluded.json").write_text(json.dumps(excluded, indent=2) + "\n")


if __name__ == "__main__":
    main(sys.argv[1:])

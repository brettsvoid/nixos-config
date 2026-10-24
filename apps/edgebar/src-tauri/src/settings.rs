use crate::{apply_theme, reload_theme, resolve_notch_idle, Appearance, Config, ThemeState};
use serde::Serialize;
use serde_json::{Map, Value};
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use tauri::{Emitter, Manager};

const BUNDLED: &str = include_str!("../config.default.json");
const NIX_FILE: &str = "config.json";
const USER_FILE: &str = "settings.json";
const LEGACY_APPEARANCE_FILE: &str = "appearance";

fn empty() -> Value {
    Value::Object(Map::new())
}

fn bundled() -> Value {
    serde_json::from_str(BUNDLED).expect("bundled config.default.json is valid")
}

fn kind(v: &Value) -> &'static str {
    match v {
        Value::Null => "null",
        Value::Bool(_) => "a boolean",
        Value::Number(_) => "a number",
        Value::String(_) => "a string",
        Value::Array(_) => "a list",
        Value::Object(_) => "an object",
    }
}

fn merge(base: Value, over: Value) -> Value {
    match (base, over) {
        (Value::Object(mut base), Value::Object(over)) => {
            for (key, value) in over {
                let merged = match base.remove(&key) {
                    Some(existing) => merge(existing, value),
                    None => value,
                };
                base.insert(key, merged);
            }
            Value::Object(base)
        }
        (_, over) => over,
    }
}

fn set_path(root: &mut Value, path: &[String], value: Value) {
    let mut node = root;
    for key in path {
        if !node.is_object() {
            *node = empty();
        }
        if let Value::Object(map) = node {
            node = map.entry(key.clone()).or_insert(Value::Null);
        }
    }
    *node = value;
}

fn remove_path(root: &mut Value, path: &[String]) {
    let (Some((first, rest)), Value::Object(map)) = (path.split_first(), root) else {
        return;
    };
    if rest.is_empty() {
        map.remove(first);
        return;
    }
    let Some(child) = map.get_mut(first) else {
        return;
    };
    remove_path(child, rest);
    if child.as_object().is_some_and(Map::is_empty) {
        map.remove(first);
    }
}

fn check(defaults: &Value, path: &[String], value: &Value) -> Result<(), String> {
    let mut node = defaults;
    for (depth, key) in path.iter().enumerate() {
        let Value::Object(map) = node else {
            let parent = path[..depth].join(".");
            return Err(format!(
                "`{parent}` is {}, so it has no `{key}`",
                kind(node)
            ));
        };
        if map.is_empty() {
            return Ok(());
        }
        let Some(child) = map.get(key) else {
            return Err(format!("`{}` is not a setting", path[..=depth].join(".")));
        };
        node = child;
    }
    check_value(node, value, &path.join("."))
}

fn check_value(default: &Value, value: &Value, name: &str) -> Result<(), String> {
    match (default, value) {
        (Value::Object(d), Value::Object(v)) if !d.is_empty() => {
            v.iter().try_for_each(|(key, child)| {
                let name = format!("{name}.{key}");
                match d.get(key) {
                    Some(d) => check_value(d, child, &name),
                    None => Err(format!("`{name}` is not a setting")),
                }
            })
        }
        _ if kind(default) == kind(value) => Ok(()),
        _ => Err(format!(
            "`{name}` takes {}, not {}",
            kind(default),
            kind(value)
        )),
    }
}

fn leaves(defaults: &Value, user: &Value) -> Vec<(Vec<String>, Value)> {
    fn walk(
        default: Option<&Value>,
        node: &Value,
        path: &mut Vec<String>,
        out: &mut Vec<(Vec<String>, Value)>,
    ) {
        let (Some(Value::Object(d)), Value::Object(n)) = (default, node) else {
            out.push((path.clone(), node.clone()));
            return;
        };
        for (key, child) in n {
            path.push(key.clone());
            if d.is_empty() {
                out.push((path.clone(), child.clone()));
            } else {
                walk(d.get(key), child, path, out);
            }
            path.pop();
        }
    }
    let mut out = Vec::new();
    walk(Some(defaults), user, &mut Vec::new(), &mut out);
    out
}

fn sanitise(
    defaults: &Value,
    user: &Value,
    accepts: impl Fn(&Value) -> Result<(), String>,
) -> (Value, Vec<String>) {
    let mut kept = empty();
    let mut problems = Vec::new();
    for (path, value) in leaves(defaults, user) {
        let mut candidate = kept.clone();
        set_path(&mut candidate, &path, value.clone());
        let verdict = check(defaults, &path, &value).and_then(|()| {
            accepts(&candidate).map_err(|why| format!("`{}`: {why}", path.join(".")))
        });
        match verdict {
            Ok(()) => kept = candidate,
            Err(why) => problems.push(why),
        }
    }
    (kept, problems)
}

fn split_key(key: &str) -> Result<Vec<String>, String> {
    let path: Vec<String> = key.split('.').map(str::to_owned).collect();
    if path.iter().any(String::is_empty) {
        return Err(format!("`{key}` is not a dotted setting key"));
    }
    Ok(path)
}

pub fn dir() -> Option<PathBuf> {
    std::env::var_os("HOME").map(|home| Path::new(&home).join(".config/edgebar"))
}

pub fn cache_dir() -> Option<PathBuf> {
    std::env::var_os("HOME").map(|home| Path::new(&home).join(".cache/edgebar"))
}

fn read_object(file: &Path) -> Result<Option<Value>, String> {
    let text = match std::fs::read_to_string(file) {
        Ok(text) if text.trim().is_empty() => return Ok(None),
        Ok(text) => text,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(e) => return Err(format!("cannot be read: {e}")),
    };
    match serde_json::from_str::<Value>(&text) {
        Ok(doc @ Value::Object(_)) => Ok(Some(doc)),
        Ok(_) => Err("is not a JSON object".to_string()),
        Err(e) => Err(format!("is not valid JSON: {e}")),
    }
}

pub(crate) fn write_atomic(file: &Path, doc: &impl Serialize) -> Result<(), String> {
    let text = serde_json::to_string_pretty(doc).map_err(|e| e.to_string())? + "\n";
    if let Some(parent) = file.parent() {
        std::fs::create_dir_all(parent)
            .map_err(|e| format!("cannot create {}: {e}", parent.display()))?;
    }
    let tmp = file.with_extension("json.tmp");
    std::fs::write(&tmp, text)
        .and_then(|()| std::fs::rename(&tmp, file))
        .map_err(|e| {
            let _ = std::fs::remove_file(&tmp);
            format!("cannot write {}: {e}", file.display())
        })
}

fn trial(base: &Value, user: &Value) -> Result<(), String> {
    serde_json::from_value::<Config>(merge(base.clone(), user.clone()))
        .map(drop)
        .map_err(|e| e.to_string())
}

fn base_layer(defaults: &Value, dir: Option<&Path>) -> Value {
    let nix = dir
        .and_then(|d| read_object(&d.join(NIX_FILE)).ok().flatten())
        .unwrap_or_else(empty);
    let base = merge(defaults.clone(), nix);
    if trial(&base, &empty()).is_ok() {
        base
    } else {
        defaults.clone()
    }
}

#[derive(Clone, Serialize)]
pub struct Snapshot {
    effective: Value,
    user: Value,
    error: Option<String>,
}

#[derive(Clone)]
pub struct Loaded {
    pub config: Config,
    snapshot: Snapshot,
}

pub fn load(dir: Option<&Path>) -> Loaded {
    let defaults = bundled();
    let base = base_layer(&defaults, dir);
    let mut problems = Vec::new();
    let raw = match dir.map(|d| read_object(&d.join(USER_FILE))) {
        Some(Ok(Some(doc))) => doc,
        Some(Err(why)) => {
            problems.push(format!("settings.json {why}; it is ignored"));
            empty()
        }
        _ => empty(),
    };
    let (user, dropped) = sanitise(&defaults, &raw, |candidate| trial(&base, candidate));
    problems.extend(
        dropped
            .into_iter()
            .map(|why| format!("settings.json: {why}")),
    );
    let effective = merge(base, user.clone());
    let config = serde_json::from_value(effective.clone())
        .expect("every kept override passed `trial` on top of this base");
    Loaded {
        config,
        snapshot: Snapshot {
            effective,
            user,
            error: (!problems.is_empty()).then(|| problems.join("\n")),
        },
    }
}

fn write_override(dir: &Path, key: &str, value: Value) -> Result<bool, String> {
    let path = split_key(key)?;
    let file = dir.join(USER_FILE);
    let raw = read_object(&file)
        .map_err(|why| {
            format!("settings.json {why}; it was left as it is, fix or delete it first")
        })?
        .unwrap_or_else(empty);
    let mut next = raw.clone();
    if value.is_null() {
        remove_path(&mut next, &path);
    } else {
        let defaults = bundled();
        check(&defaults, &path, &value)?;
        let base = base_layer(&defaults, Some(dir));
        let (mut kept, _) = sanitise(&defaults, &raw, |candidate| trial(&base, candidate));
        set_path(&mut kept, &path, value.clone());
        trial(&base, &kept).map_err(|why| format!("`{key}`: {why}"))?;
        set_path(&mut next, &path, value);
    }
    if next == raw {
        return Ok(false);
    }
    write_atomic(&file, &next)?;
    Ok(true)
}

pub fn import_legacy_appearance(dir: &Path) -> Result<(), String> {
    let file = dir.join(LEGACY_APPEARANCE_FILE);
    let text = match std::fs::read_to_string(&file) {
        Ok(text) => text,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(()),
        Err(e) => return Err(format!("cannot read {}: {e}", file.display())),
    };
    let mode = Value::String(text.trim().to_string());
    if serde_json::from_value::<Appearance>(mode.clone()).is_ok() {
        let below = base_layer(&bundled(), Some(dir));
        let value = if below.get("appearance") == Some(&mode) {
            Value::Null
        } else {
            mode
        };
        write_override(dir, "appearance", value)?;
    }
    std::fs::remove_file(&file).map_err(|e| format!("cannot delete {}: {e}", file.display()))
}

#[derive(Debug, Default, PartialEq, Eq)]
struct Changes {
    colors: bool,
    appearance: bool,
    geometry: bool,
    idle: bool,
    rules: bool,
    flash_hold: bool,
    wallpaper: bool,
    toggles: bool,
}

fn changes(prev: &Config, next: &Config) -> Changes {
    Changes {
        colors: prev.colors != next.colors,
        appearance: prev.appearance != next.appearance,
        geometry: prev.geometry != next.geometry,
        idle: prev.notch.idle != next.notch.idle,
        rules: prev.notch.workspaces != next.notch.workspaces,
        flash_hold: prev.notch.transient_ms != next.notch.transient_ms,
        wallpaper: prev.oled != next.oled || prev.wallpaper.tint != next.wallpaper.tint,
        toggles: prev.toggles != next.toggles,
    }
}

fn converge(app: &tauri::AppHandle, prev: &Config, next: &Config) {
    let c = changes(prev, next);

    if c.colors || c.appearance || c.geometry || c.idle {
        let idle = c
            .idle
            .then(|| resolve_notch_idle(next.notch.idle.as_deref()));
        {
            let state = app.state::<Mutex<ThemeState>>();
            let mut ts = state.lock().unwrap();
            if c.colors {
                ts.colors = next.colors.clone();
            }
            if c.geometry {
                ts.geometry = next.geometry.clone();
            }
            if let Some(idle) = idle {
                ts.notch_idle = idle;
            }
        }
        apply_theme(app, next.appearance);
    }

    #[cfg(target_os = "macos")]
    if c.geometry {
        let handle = app.clone();
        let _ = app.run_on_main_thread(move || crate::rebuild_displays(&handle));
    }

    if c.rules || c.flash_hold {
        app.state::<crate::notch::NotchState>()
            .set_config(next.notch.clone());
    }
    if c.rules {
        crate::notch::refresh_workspace(app);
    }

    if c.wallpaper {
        reload_theme(app);
    }

    if c.toggles {
        app.state::<crate::toggles::Toggles>()
            .set_config(app, next.toggles.clone());
    }
}

pub struct Store {
    applied: Mutex<Loaded>,
    writer: Mutex<()>,
}

impl Store {
    pub fn new(loaded: Loaded) -> Self {
        Self {
            applied: Mutex::new(loaded),
            writer: Mutex::new(()),
        }
    }
}

fn set(app: &tauri::AppHandle, key: &str, value: Value) -> Result<Snapshot, String> {
    let store = app.state::<Store>();
    let _writer = store.writer.lock().unwrap();
    let dir = dir().ok_or("HOME is not set")?;
    write_override(&dir, key, value)?;
    let next = load(Some(&dir));
    let prev = std::mem::replace(&mut *store.applied.lock().unwrap(), next.clone());
    converge(app, &prev.config, &next.config);
    let _ = app.emit("settings", &next.snapshot);
    Ok(next.snapshot)
}

#[tauri::command]
pub async fn get_settings(app: tauri::AppHandle) -> Snapshot {
    let store = app.state::<Store>();
    let snapshot = store.applied.lock().unwrap().snapshot.clone();
    snapshot
}

#[tauri::command]
pub async fn set_setting(
    app: tauri::AppHandle,
    key: String,
    value: Value,
) -> Result<Snapshot, String> {
    tauri::async_runtime::spawn_blocking(move || set(&app, &key, value))
        .await
        .map_err(|e| e.to_string())?
}

#[derive(Serialize)]
pub struct Layer {
    name: &'static str,
    path: String,
    detail: String,
}

#[derive(Serialize)]
pub struct Files {
    version: String,
    layers: Vec<Layer>,
}

pub fn tilde(path: &Path) -> String {
    match std::env::var_os("HOME") {
        Some(home) if !home.is_empty() => under_home(path, Path::new(&home)),
        _ => path.display().to_string(),
    }
}

fn under_home(path: &Path, home: &Path) -> String {
    match path.strip_prefix(home) {
        Ok(rest) if rest.as_os_str().is_empty() => "~".to_string(),
        Ok(rest) => format!("~/{}", rest.display()),
        Err(_) => path.display().to_string(),
    }
}

#[tauri::command]
pub fn settings_files(app: tauri::AppHandle) -> Files {
    let dir = dir();
    let nix = dir.as_deref().map(|d| d.join(NIX_FILE));
    let user = dir.as_deref().map(|d| d.join(USER_FILE));
    let overrides = {
        let store = app.state::<Store>();
        let applied = store.applied.lock().unwrap();
        leaves(&bundled(), &applied.snapshot.user).len()
    };
    let nix_detail = if nix.as_deref().is_some_and(Path::exists) {
        "Rendered by modules/home/darwin/edgebar.nix; read-only.".to_string()
    } else {
        "Missing: edgebar runs on its defaults until the Nix config is built.".to_string()
    };
    let user_detail = match (user.as_deref().is_some_and(Path::exists), overrides) {
        (false, _) => "Not created yet: no setting has been changed.".to_string(),
        (true, 1) => "1 changed setting. Only edgebar writes it.".to_string(),
        (true, n) => format!("{n} changed settings. Only edgebar writes it."),
    };
    let shown = |p: Option<PathBuf>| p.map(|p| tilde(&p)).unwrap_or_default();
    Files {
        version: app.package_info().version.to_string(),
        layers: vec![
            Layer {
                name: "Defaults",
                path: "Built into edgebar".to_string(),
                detail: "From apps/edgebar/src-tauri/config.default.json, which also lists every setting."
                    .to_string(),
            },
            Layer {
                name: "Nix config",
                path: shown(nix),
                detail: nix_detail,
            },
            Layer {
                name: "Your settings",
                path: shown(user),
                detail: user_detail,
            },
        ],
    }
}

#[tauri::command]
pub fn open_settings_file(app: tauri::AppHandle) -> Result<(), String> {
    let file = dir().ok_or("HOME is not set")?.join(USER_FILE);
    {
        let store = app.state::<Store>();
        let _writer = store.writer.lock().unwrap();
        if !file.exists() {
            write_atomic(&file, &empty())?;
        }
    }
    std::process::Command::new("/usr/bin/open")
        .arg("-t")
        .arg(&file)
        .spawn()
        .map(drop)
        .map_err(|e| format!("cannot open {}: {e}", file.display()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::scratch::Scratch;
    use serde_json::json;

    fn path(key: &str) -> Vec<String> {
        split_key(key).unwrap()
    }

    fn user_file(dir: &Scratch) -> Value {
        serde_json::from_str(&dir.read(USER_FILE)).unwrap()
    }

    fn config_with(key: &str, value: Value) -> Config {
        let mut doc = bundled();
        set_path(&mut doc, &path(key), value);
        serde_json::from_value(doc).unwrap()
    }

    #[test]
    fn merge_replaces_leaves_and_merges_objects() {
        let base = json!({"a": {"x": 1, "y": 2}, "b": [1, 2], "c": "keep"});
        let over = json!({"a": {"y": 3, "z": 4}, "b": [9], "d": null});
        assert_eq!(
            merge(base, over),
            json!({"a": {"x": 1, "y": 3, "z": 4}, "b": [9], "c": "keep", "d": null})
        );
    }

    #[test]
    fn setting_creates_parents_and_replaces_a_scalar_parent() {
        let mut doc = json!({"notch": 5});
        set_path(
            &mut doc,
            &path("notch.workspaces.1"),
            json!({"source": "none"}),
        );
        assert_eq!(
            doc,
            json!({"notch": {"workspaces": {"1": {"source": "none"}}}})
        );
    }

    #[test]
    fn removing_prunes_emptied_parents_but_not_siblings() {
        let mut doc = json!({
            "appearance": "dark",
            "notch": {"workspaces": {"1": {"source": "none"}}},
            "geometry": {"frameRadius": 40, "frameThickness": 6}
        });
        remove_path(&mut doc, &path("notch.workspaces.1"));
        remove_path(&mut doc, &path("geometry.frameRadius"));
        assert_eq!(
            doc,
            json!({"appearance": "dark", "geometry": {"frameThickness": 6}})
        );
    }

    #[test]
    fn removing_a_missing_key_changes_nothing() {
        let mut doc = json!({"geometry": {"frameRadius": 40}});
        remove_path(&mut doc, &path("geometry.nope"));
        remove_path(&mut doc, &path("notch.idle"));
        assert_eq!(doc, json!({"geometry": {"frameRadius": 40}}));
    }

    #[test]
    fn a_type_mismatch_is_rejected() {
        let defaults = bundled();
        assert_eq!(
            check(&defaults, &path("geometry.frameRadius"), &json!("tall")),
            Err("`geometry.frameRadius` takes a number, not a string".to_string())
        );
        assert_eq!(
            check(&defaults, &path("geometry"), &json!({"frameRadius": true})),
            Err("`geometry.frameRadius` takes a number, not a boolean".to_string())
        );
        assert_eq!(
            check(&defaults, &path("geometry.frameRadius"), &json!(40)),
            Ok(())
        );
    }

    #[test]
    fn an_open_map_takes_any_key_and_any_value() {
        let defaults = bundled();
        let rule = json!({"source": "command", "run": "date", "everyMs": 1000});
        assert_eq!(check(&defaults, &path("notch.workspaces.7"), &rule), Ok(()));
        assert_eq!(
            check(
                &defaults,
                &path("notch.workspaces.*.anything.deeper"),
                &json!(1)
            ),
            Ok(())
        );
        assert_eq!(
            check(&defaults, &path("notch.workspaces"), &json!({"1": rule})),
            Ok(())
        );
        assert_eq!(
            check(&defaults, &path("notch.workspaces"), &json!("none")),
            Err("`notch.workspaces` takes an object, not a string".to_string())
        );
    }

    #[test]
    fn an_unknown_key_is_rejected() {
        let defaults = bundled();
        assert_eq!(
            check(&defaults, &path("geometry.nope"), &json!(1)),
            Err("`geometry.nope` is not a setting".to_string())
        );
        assert_eq!(
            check(&defaults, &path("geometry"), &json!({"nope": 1})),
            Err("`geometry.nope` is not a setting".to_string())
        );
        assert_eq!(
            check(&defaults, &path("appearance.deeper"), &json!(1)),
            Err("`appearance` is a string, so it has no `deeper`".to_string())
        );
        assert_eq!(
            check(&defaults, &path("themeCommand"), &json!("x")),
            Err("`themeCommand` is not a setting".to_string())
        );
    }

    #[test]
    fn the_bundled_defaults_parse_as_a_config() {
        assert!(serde_json::from_value::<Config>(bundled()).is_ok());
    }

    #[test]
    fn load_merges_three_layers_and_drops_bad_overrides() {
        let dir = Scratch::new("layers");
        dir.write(
            NIX_FILE,
            r#"{"geometry": {"frameRadius": 40, "barHeight": 70}, "themeCommand": "gen"}"#,
        );
        dir.write(
            USER_FILE,
            r#"{
                "appearance": "purple",
                "bogus": 1,
                "geometry": {"frameRadius": "tall", "frameThickness": 6},
                "notch": {"transientMs": 900, "workspaces": {"2": {"source": "focusedWindow"}}}
            }"#,
        );
        let loaded = load(Some(&dir.path()));
        assert_eq!(
            loaded.snapshot.user,
            json!({
                "geometry": {"frameThickness": 6},
                "notch": {"transientMs": 900, "workspaces": {"2": {"source": "focusedWindow"}}}
            })
        );
        assert_eq!(
            loaded.snapshot.effective["geometry"]["frameRadius"],
            json!(40)
        );
        assert_eq!(
            loaded.snapshot.effective["geometry"]["frameThickness"],
            json!(6)
        );
        assert_eq!(
            loaded.snapshot.effective["geometry"]["windowHeight"],
            json!(64)
        );
        assert_eq!(loaded.snapshot.effective["themeCommand"], json!("gen"));
        assert_eq!(loaded.config.geometry.frame_thickness, 6.0);
        assert_eq!(loaded.config.notch.transient_ms, Some(900));
        assert_eq!(loaded.config.theme_command.as_deref(), Some("gen"));
        assert_eq!(
            loaded.snapshot.error.as_deref(),
            Some(
                "settings.json: `appearance`: unknown variant `purple`, expected one of `light`, `dark`, `auto`\n\
                 settings.json: `bogus` is not a setting\n\
                 settings.json: `geometry.frameRadius` takes a number, not a string"
            )
        );
    }

    #[test]
    fn an_unparseable_file_is_ignored_whole_and_reported() {
        let dir = Scratch::new("unparseable");
        dir.write(USER_FILE, "{\"geometry\": {\"frameRadius\": 40,");
        let loaded = load(Some(&dir.path()));
        assert_eq!(loaded.snapshot.user, json!({}));
        assert_eq!(loaded.snapshot.effective, bundled());
        assert_eq!(
            loaded.snapshot.error.as_deref(),
            Some("settings.json is not valid JSON: EOF while parsing a value at line 1 column 32; it is ignored")
        );
        assert_eq!(dir.read(USER_FILE), "{\"geometry\": {\"frameRadius\": 40,");
    }

    #[test]
    fn a_missing_or_blank_file_is_no_overrides() {
        let dir = Scratch::new("blank");
        assert_eq!(load(Some(&dir.path())).snapshot.error, None);
        dir.write(USER_FILE, "  \n");
        let loaded = load(Some(&dir.path()));
        assert_eq!(loaded.snapshot.error, None);
        assert_eq!(loaded.snapshot.user, json!({}));
        assert_eq!(load(None).snapshot.effective, bundled());
    }

    #[test]
    fn a_config_json_that_no_longer_fits_is_ignored() {
        let dir = Scratch::new("badnix");
        dir.write(NIX_FILE, r#"{"geometry": {"frameRadius": "tall"}}"#);
        let loaded = load(Some(&dir.path()));
        assert_eq!(loaded.snapshot.effective, bundled());
        assert_eq!(loaded.snapshot.error, None);
    }

    #[test]
    fn set_writes_the_file_and_reset_removes_the_override() {
        let dir = Scratch::new("roundtrip");
        assert_eq!(
            write_override(&dir.path(), "geometry.frameThickness", json!(6)),
            Ok(true)
        );
        assert_eq!(user_file(&dir), json!({"geometry": {"frameThickness": 6}}));
        assert_eq!(load(Some(&dir.path())).config.geometry.frame_thickness, 6.0);

        assert_eq!(
            write_override(&dir.path(), "geometry.frameThickness", Value::Null),
            Ok(true)
        );
        assert_eq!(user_file(&dir), json!({}));
        assert_eq!(load(Some(&dir.path())).config.geometry.frame_thickness, 8.0);
        assert!(!dir.path().join("settings.json.tmp").exists());
    }

    #[test]
    fn setting_the_same_value_twice_changes_nothing_the_second_time() {
        let dir = Scratch::new("idempotent");
        assert_eq!(
            write_override(&dir.path(), "notch.idle", json!("clock")),
            Ok(true)
        );
        let first = dir.read(USER_FILE);
        assert_eq!(
            write_override(&dir.path(), "notch.idle", json!("clock")),
            Ok(false)
        );
        assert_eq!(dir.read(USER_FILE), first);
        assert_eq!(
            write_override(&dir.path(), "geometry.frameRadius", Value::Null),
            Ok(false)
        );
    }

    #[test]
    fn set_rejects_what_load_would_drop_and_writes_nothing() {
        let dir = Scratch::new("rejects");
        for (key, value, why) in [
            (
                "geometry.frameRadius",
                json!("tall"),
                "`geometry.frameRadius` takes a number, not a string",
            ),
            (
                "geometry.nope",
                json!(1),
                "`geometry.nope` is not a setting",
            ),
            (
                "appearance",
                json!("purple"),
                "`appearance`: unknown variant `purple`, expected one of `light`, `dark`, `auto`",
            ),
            (
                "notch.transientMs",
                json!(-5),
                "`notch.transientMs`: invalid value: integer `-5`, expected u64",
            ),
            (
                "geometry..x",
                json!(1),
                "`geometry..x` is not a dotted setting key",
            ),
        ] {
            assert_eq!(write_override(&dir.path(), key, value), Err(why.to_string()));
        }
        assert!(!dir.path().join(USER_FILE).exists());
    }

    #[test]
    fn set_refuses_to_write_over_an_unparseable_file() {
        let dir = Scratch::new("refuses");
        dir.write(USER_FILE, "{oops");
        assert_eq!(
            write_override(&dir.path(), "geometry.frameThickness", json!(6)),
            Err("settings.json is not valid JSON: key must be a string at line 1 column 2; it was left as it is, fix or delete it first".to_string())
        );
        assert_eq!(dir.read(USER_FILE), "{oops");
    }

    #[test]
    fn set_keeps_overrides_that_fail_validation_and_removing_one_is_allowed() {
        let dir = Scratch::new("keeps");
        dir.write(USER_FILE, r#"{"bogus": 1}"#);
        assert_eq!(
            write_override(&dir.path(), "geometry.frameThickness", json!(6)),
            Ok(true)
        );
        assert_eq!(
            user_file(&dir),
            json!({"bogus": 1, "geometry": {"frameThickness": 6}})
        );
        assert_eq!(write_override(&dir.path(), "bogus", Value::Null), Ok(true));
        assert_eq!(user_file(&dir), json!({"geometry": {"frameThickness": 6}}));
    }

    #[test]
    fn a_path_under_home_is_shown_with_a_tilde() {
        let home = Path::new("/Users/brett");
        assert_eq!(under_home(Path::new("/Users/brett"), home), "~");
        assert_eq!(
            under_home(Path::new("/Users/brett/Pictures/Art"), home),
            "~/Pictures/Art"
        );
        assert_eq!(
            under_home(Path::new("/Users/brettx/Art"), home),
            "/Users/brettx/Art"
        );
        assert_eq!(under_home(Path::new("/Volumes/Art"), home), "/Volumes/Art");
    }

    #[test]
    fn the_legacy_appearance_file_becomes_an_override_once() {
        let dir = Scratch::new("legacy-dark");
        dir.write(LEGACY_APPEARANCE_FILE, "dark\n");
        assert_eq!(import_legacy_appearance(&dir.path()), Ok(()));
        assert_eq!(user_file(&dir), json!({"appearance": "dark"}));
        assert!(!dir.path().join(LEGACY_APPEARANCE_FILE).exists());
        assert_eq!(import_legacy_appearance(&dir.path()), Ok(()));
        assert_eq!(user_file(&dir), json!({"appearance": "dark"}));
        assert!(load(Some(&dir.path())).config.appearance == Appearance::Dark);
    }

    #[test]
    fn a_legacy_mode_equal_to_the_layers_below_writes_no_settings_file() {
        let dir = Scratch::new("legacy-auto");
        dir.write(LEGACY_APPEARANCE_FILE, "auto");
        assert_eq!(import_legacy_appearance(&dir.path()), Ok(()));
        assert!(!dir.path().join(USER_FILE).exists());
        assert!(!dir.path().join(LEGACY_APPEARANCE_FILE).exists());
    }

    #[test]
    fn the_legacy_file_wins_over_an_older_override() {
        let dir = Scratch::new("legacy-wins");
        dir.write(USER_FILE, r#"{"appearance": "dark", "oled": true}"#);
        dir.write(LEGACY_APPEARANCE_FILE, "auto");
        assert_eq!(import_legacy_appearance(&dir.path()), Ok(()));
        assert_eq!(user_file(&dir), json!({"oled": true}));
        dir.write(LEGACY_APPEARANCE_FILE, "light");
        assert_eq!(import_legacy_appearance(&dir.path()), Ok(()));
        assert_eq!(
            user_file(&dir),
            json!({"oled": true, "appearance": "light"})
        );
    }

    #[test]
    fn a_legacy_file_without_a_mode_is_dropped() {
        let dir = Scratch::new("legacy-junk");
        dir.write(LEGACY_APPEARANCE_FILE, "purple");
        assert_eq!(import_legacy_appearance(&dir.path()), Ok(()));
        assert!(!dir.path().join(USER_FILE).exists());
        assert!(!dir.path().join(LEGACY_APPEARANCE_FILE).exists());
    }

    #[test]
    fn the_legacy_file_stays_while_settings_json_does_not_parse() {
        let dir = Scratch::new("legacy-blocked");
        dir.write(USER_FILE, "{oops");
        dir.write(LEGACY_APPEARANCE_FILE, "dark");
        assert!(import_legacy_appearance(&dir.path()).is_err());
        assert_eq!(dir.read(USER_FILE), "{oops");
        assert_eq!(dir.read(LEGACY_APPEARANCE_FILE), "dark");
    }

    #[test]
    fn changes_names_the_subsystems_that_differ() {
        let base = config_with("geometry.frameRadius", json!(16));
        assert_eq!(changes(&base, &base), Changes::default());
        assert_eq!(
            changes(&base, &config_with("notch.idle", json!("clock"))),
            Changes {
                idle: true,
                ..Changes::default()
            }
        );
        assert_eq!(
            changes(&base, &config_with("geometry.frameRadius", json!(20))),
            Changes {
                geometry: true,
                ..Changes::default()
            }
        );
        assert_eq!(
            changes(&base, &config_with("colors.dark.accent", json!("red"))),
            Changes {
                colors: true,
                ..Changes::default()
            }
        );
        assert_eq!(
            changes(&base, &config_with("appearance", json!("dark"))),
            Changes {
                appearance: true,
                ..Changes::default()
            }
        );
        assert_eq!(
            changes(
                &base,
                &config_with("notch.workspaces.1", json!({"source": "focusedWindow"}))
            ),
            Changes {
                rules: true,
                ..Changes::default()
            }
        );
        assert_eq!(
            changes(&base, &config_with("notch.transientMs", json!(900))),
            Changes {
                flash_hold: true,
                ..Changes::default()
            }
        );
        for (key, value) in [("oled", json!(true)), ("wallpaper.tint", json!(true))] {
            assert_eq!(
                changes(&base, &config_with(key, value)),
                Changes {
                    wallpaper: true,
                    ..Changes::default()
                },
                "{key}"
            );
        }
        assert_eq!(
            changes(&base, &config_with("toggles.focusShortcut", json!("Focus"))),
            Changes {
                toggles: true,
                ..Changes::default()
            }
        );
        assert_eq!(
            changes(&base, &config_with("wallpaper.folder", json!("~/Pictures"))),
            Changes::default()
        );
    }
}

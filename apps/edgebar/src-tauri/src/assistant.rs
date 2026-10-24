use serde::{Deserialize, Serialize};
use std::io::{BufRead, BufReader, Read, Write};
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};
use tauri::{AppHandle, Emitter, Manager, Runtime};

const SYSTEM_PROMPT: &str = "You are answering in a small chat panel inside a macOS menu bar. \
Keep replies short. Light Markdown is fine (bold, lists, inline code and fenced code blocks).";

#[derive(Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AssistantConfig {
    pub command: String,
    pub model: String,
}

#[derive(Debug, PartialEq)]
enum Failure {
    CliMissing(String),
    NotLoggedIn,
    SessionGone,
    Cli(String),
}

impl Failure {
    fn classify(text: &str) -> Failure {
        if text.contains("Not logged in") {
            Failure::NotLoggedIn
        } else if text.contains("No conversation found") {
            Failure::SessionGone
        } else {
            Failure::Cli(text.trim().to_string())
        }
    }

    fn message(&self) -> String {
        match self {
            Failure::CliMissing(command) => format!(
                "Claude Code (\"{command}\") was not found. Install it, or set assistant.command in the settings."
            ),
            Failure::NotLoggedIn => {
                "Claude Code is not logged in. Run claude in a terminal and sign in with /login."
                    .to_string()
            }
            Failure::SessionGone => {
                "That conversation is no longer stored, so the next message starts a new one."
                    .to_string()
            }
            Failure::Cli(text) => text.clone(),
        }
    }
}

#[derive(Debug, PartialEq)]
enum Line {
    Init,
    Delta(String),
    Done,
    Failed(Failure),
    Other,
}

fn str_at<'a>(value: &'a serde_json::Value, key: &str) -> Option<&'a str> {
    value.get(key)?.as_str()
}

fn parse_line(line: &str) -> Line {
    let Ok(value) = serde_json::from_str::<serde_json::Value>(line) else {
        return Line::Other;
    };
    match str_at(&value, "type") {
        Some("system") if str_at(&value, "subtype") == Some("init") => Line::Init,
        Some("stream_event") => {
            let event = &value["event"];
            let delta = &event["delta"];
            if str_at(event, "type") == Some("content_block_delta")
                && str_at(delta, "type") == Some("text_delta")
            {
                match str_at(delta, "text") {
                    Some(text) if !text.is_empty() => Line::Delta(text.to_string()),
                    _ => Line::Other,
                }
            } else {
                Line::Other
            }
        }
        Some("result") => {
            let is_error = value["is_error"].as_bool().unwrap_or(false);
            if !is_error && str_at(&value, "subtype") == Some("success") {
                return Line::Done;
            }
            let from_result = str_at(&value, "result").filter(|s| !s.is_empty());
            let from_errors = value["errors"].as_array().map(|errors| {
                errors
                    .iter()
                    .filter_map(|e| e.as_str())
                    .collect::<Vec<_>>()
                    .join("; ")
            });
            let text = from_result
                .map(str::to_string)
                .or(from_errors.filter(|s| !s.is_empty()))
                .unwrap_or_else(|| "Claude Code reported an error.".to_string());
            Line::Failed(Failure::classify(&text))
        }
        _ => Line::Other,
    }
}

#[derive(Clone, Debug, PartialEq)]
enum SessionFlag {
    New(String),
    Resume(String),
}

#[derive(Default)]
enum Session {
    #[default]
    Fresh,
    Started(String),
}

struct Turn {
    id: String,
    session: SessionFlag,
    cancelled: AtomicBool,
    child: Mutex<Option<Child>>,
}

impl Turn {
    fn new(session: SessionFlag) -> Turn {
        Turn {
            id: uuid::Uuid::new_v4().to_string(),
            session,
            cancelled: AtomicBool::new(false),
            child: Mutex::new(None),
        }
    }

    fn is_cancelled(&self) -> bool {
        self.cancelled.load(Ordering::SeqCst)
    }

    fn cancel(&self) {
        self.cancelled.store(true, Ordering::SeqCst);
        if let Some(child) = lock(&self.child).as_mut() {
            let _ = child.kill();
        }
    }

    fn attach(&self, child: Child) {
        *lock(&self.child) = Some(child);
        if self.is_cancelled() {
            self.cancel();
        }
    }

    fn reap(&self) -> bool {
        let child = lock(&self.child).take();
        match child {
            Some(mut child) => child.wait().is_ok_and(|status| status.success()),
            None => false,
        }
    }
}

#[derive(Default)]
struct Conversation {
    session: Session,
    running: Option<Arc<Turn>>,
}

impl Conversation {
    fn begin_turn(&mut self) -> Arc<Turn> {
        self.cancel();
        let session = match &self.session {
            Session::Fresh => SessionFlag::New(uuid::Uuid::new_v4().to_string()),
            Session::Started(id) => SessionFlag::Resume(id.clone()),
        };
        let turn = Arc::new(Turn::new(session));
        self.running = Some(turn.clone());
        turn
    }

    fn cancel(&mut self) {
        if let Some(turn) = self.running.take() {
            turn.cancel();
        }
    }

    fn reset(&mut self) {
        self.cancel();
        self.session = Session::Fresh;
    }

    fn established(&mut self, turn: &Turn) {
        if turn.is_cancelled() {
            return;
        }
        if let SessionFlag::New(id) = &turn.session {
            self.session = Session::Started(id.clone());
        }
    }

    fn lost(&mut self, turn: &Turn) {
        if !turn.is_cancelled() && matches!(turn.session, SessionFlag::Resume(_)) {
            self.session = Session::Fresh;
        }
    }

    fn finished(&mut self, turn: &Turn) {
        if self.running.as_ref().is_some_and(|t| t.id == turn.id) {
            self.running = None;
        }
    }
}

#[derive(Default)]
pub struct AssistantState {
    conversation: Mutex<Conversation>,
    slot: Mutex<()>,
}

fn lock<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(PoisonError::into_inner)
}

fn is_executable(path: &Path) -> bool {
    use std::os::unix::fs::PermissionsExt;
    std::fs::metadata(path).is_ok_and(|m| m.is_file() && m.permissions().mode() & 0o111 != 0)
}

pub fn resolve_command(
    command: &str,
    path_var: Option<&std::ffi::OsStr>,
    home: Option<&Path>,
) -> Option<PathBuf> {
    if command.contains('/') {
        let path = PathBuf::from(command);
        return is_executable(&path).then_some(path);
    }
    let on_path = path_var.into_iter().flat_map(std::env::split_paths);
    let local_bin = home.map(|h| h.join(".local/bin"));
    on_path
        .chain(local_bin)
        .map(|dir| dir.join(command))
        .find(|candidate| is_executable(candidate))
}

fn build_args(model: &str, session: &SessionFlag) -> Vec<String> {
    let mut args: Vec<String> = [
        "-p",
        "--output-format",
        "stream-json",
        "--verbose",
        "--include-partial-messages",
        "--tools",
        "",
        "--setting-sources",
        "",
        "--strict-mcp-config",
        "--disable-slash-commands",
        "--append-system-prompt",
        SYSTEM_PROMPT,
        "--model",
        model,
    ]
    .map(String::from)
    .to_vec();
    match session {
        SessionFlag::New(id) => args.extend(["--session-id".to_string(), id.clone()]),
        SessionFlag::Resume(id) => args.extend(["--resume".to_string(), id.clone()]),
    }
    args
}

#[derive(Debug, PartialEq)]
enum Outcome {
    Done,
    Cancelled,
    Failed(Failure),
}

fn settle(
    cancelled: bool,
    verdict: Option<Result<(), Failure>>,
    exited_cleanly: bool,
    stderr: &str,
) -> Outcome {
    if cancelled {
        return Outcome::Cancelled;
    }
    match verdict {
        Some(Ok(())) => Outcome::Done,
        Some(Err(failure)) => Outcome::Failed(failure),
        None if !exited_cleanly => {
            let text = stderr.trim();
            Outcome::Failed(if text.is_empty() {
                Failure::Cli("Claude Code stopped unexpectedly.".to_string())
            } else {
                Failure::classify(text)
            })
        }
        None => Outcome::Failed(Failure::Cli(
            "Claude Code ended without a reply.".to_string(),
        )),
    }
}

fn run_cli(
    config: &AssistantConfig,
    cwd: &Path,
    turn: &Turn,
    prompt: &str,
    mut on_line: impl FnMut(&Line),
) -> Outcome {
    if turn.is_cancelled() {
        return Outcome::Cancelled;
    }
    let home = std::env::var_os("HOME").map(PathBuf::from);
    let path_var = std::env::var_os("PATH");
    let Some(binary) = resolve_command(&config.command, path_var.as_deref(), home.as_deref())
    else {
        return Outcome::Failed(Failure::CliMissing(config.command.clone()));
    };
    if let Err(e) = std::fs::create_dir_all(cwd) {
        return Outcome::Failed(Failure::Cli(format!(
            "Could not create {}: {e}",
            cwd.display()
        )));
    }
    let spawned = Command::new(&binary)
        .args(build_args(&config.model, &turn.session))
        .current_dir(cwd)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn();
    let mut child = match spawned {
        Ok(child) => child,
        Err(e) => {
            return Outcome::Failed(Failure::Cli(format!(
                "Could not start {}: {e}",
                binary.display()
            )))
        }
    };
    let stdin = child.stdin.take();
    let stdout = child.stdout.take();
    let stderr = child.stderr.take();
    turn.attach(child);

    if let Some(mut stdin) = stdin {
        let _ = stdin.write_all(prompt.as_bytes());
    }
    let stderr_reader = std::thread::spawn(move || {
        let mut bytes = Vec::new();
        if let Some(mut stderr) = stderr {
            let _ = stderr.read_to_end(&mut bytes);
        }
        String::from_utf8_lossy(&bytes).into_owned()
    });

    let mut verdict = None;
    if let Some(stdout) = stdout {
        for raw in BufReader::new(stdout).split(b'\n') {
            let Ok(raw) = raw else { break };
            let line = parse_line(&String::from_utf8_lossy(&raw));
            if line == Line::Other {
                continue;
            }
            on_line(&line);
            match line {
                Line::Done => verdict = Some(Ok(())),
                Line::Failed(failure) => verdict = Some(Err(failure)),
                Line::Init | Line::Delta(_) | Line::Other => {}
            }
        }
    }
    let exited_cleanly = turn.reap();
    let stderr = stderr_reader.join().unwrap_or_default();
    settle(turn.is_cancelled(), verdict, exited_cleanly, &stderr)
}

#[derive(Clone, Copy, Serialize)]
#[serde(rename_all = "lowercase")]
enum ChunkKind {
    Delta,
    Done,
    Error,
}

#[derive(Clone, Serialize)]
struct AssistantChunk {
    turn: String,
    kind: ChunkKind,
    text: String,
}

fn emit_chunk<R: Runtime>(app: &AppHandle<R>, turn: &Turn, kind: ChunkKind, text: String) {
    let _ = app.emit(
        "assistant",
        AssistantChunk {
            turn: turn.id.clone(),
            kind,
            text,
        },
    );
}

fn cache_dir() -> PathBuf {
    match crate::settings::cache_dir() {
        Some(dir) => dir.join("assistant"),
        None => std::env::temp_dir().join("edgebar-assistant"),
    }
}

fn run_turn<R: Runtime>(
    app: &AppHandle<R>,
    turn: &Arc<Turn>,
    prompt: &str,
    config: &AssistantConfig,
    cwd: &Path,
) {
    let state = app.state::<AssistantState>();
    let _slot = lock(&state.slot);
    let outcome = run_cli(config, cwd, turn, prompt, |line| match line {
        Line::Init => lock(&state.conversation).established(turn),
        Line::Delta(text) if !turn.is_cancelled() => {
            emit_chunk(app, turn, ChunkKind::Delta, text.clone());
        }
        _ => {}
    });
    {
        let mut conversation = lock(&state.conversation);
        conversation.finished(turn);
        if outcome == Outcome::Failed(Failure::SessionGone) {
            conversation.lost(turn);
        }
    }
    match outcome {
        Outcome::Done | Outcome::Cancelled => {
            emit_chunk(app, turn, ChunkKind::Done, String::new());
        }
        Outcome::Failed(failure) => emit_chunk(app, turn, ChunkKind::Error, failure.message()),
    }
}

#[tauri::command]
pub async fn assistant_send<R: Runtime>(app: AppHandle<R>, prompt: String) -> String {
    let turn = lock(&app.state::<AssistantState>().conversation).begin_turn();
    let id = turn.id.clone();
    tauri::async_runtime::spawn_blocking(move || {
        let config = crate::settings::current(&app).assistant;
        run_turn(&app, &turn, &prompt, &config, &cache_dir());
    });
    id
}

#[tauri::command]
pub async fn assistant_cancel<R: Runtime>(app: AppHandle<R>) {
    lock(&app.state::<AssistantState>().conversation).cancel();
}

#[tauri::command]
pub async fn assistant_reset<R: Runtime>(app: AppHandle<R>) {
    lock(&app.state::<AssistantState>().conversation).reset();
}

fn web_link(url: &str) -> Result<tauri::Url, String> {
    let link = tauri::Url::parse(url).map_err(|e| format!("{url} is not a link: {e}"))?;
    match link.scheme() {
        "http" | "https" => Ok(link),
        scheme => Err(format!("Only web links open from a reply, not {scheme}: links.")),
    }
}

#[tauri::command]
pub fn assistant_open_link(url: String) -> Result<(), String> {
    crate::open_url(web_link(&url)?.as_str())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::scratch::Scratch;
    use std::os::unix::fs::PermissionsExt;
    use std::time::{Duration, Instant};

    const INIT: &str = r#"{"type":"system","subtype":"init","session_id":"47a4e5c8-13f3-4a41-9f96-f10dcdd43e62","mcp_servers":[],"model":"claude-haiku-5-5","permissionMode":"default","apiKeySource":"none","claude_code_version":"2.1.309","output_style":"default"}"#;
    const STATUS: &str = r#"{"type":"system","subtype":"status","status":"requesting","session_id":"47a4e5c8-13f3-4a41-9f96-f10dcdd43e62","uuid":"4d4d0510-4956-4571-a87d-5b866ed82211"}"#;
    const THINKING_START: &str = r#"{"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"thinking","thinking":"","signature":""}},"session_id":"47a4e5c8-13f3-4a41-9f96-f10dcdd43e62","parent_tool_use_id":null,"uuid":"a07e03b4-ef29-4102-a9c7-5f0390d4c156","thinking_display":"updates","api_message_id":"msg_01"}"#;
    const THINKING_DELTA: &str = r#"{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"thinking_delta","thinking":"","estimated_tokens":50}},"session_id":"47a4e5c8-13f3-4a41-9f96-f10dcdd43e62","parent_tool_use_id":null,"uuid":"634db838-f8f4-4bbb-8ca8-0bf59831c82b","thinking_display":"updates","api_message_id":"msg_01"}"#;
    const TEXT_START: &str = r#"{"type":"stream_event","event":{"type":"content_block_start","index":1,"content_block":{"type":"text","text":""}},"session_id":"47a4e5c8-13f3-4a41-9f96-f10dcdd43e62","parent_tool_use_id":null,"uuid":"bb448c2c-ea9c-4304-9048-ec5ed87c7788","api_message_id":"msg_01"}"#;
    const TEXT_1: &str = r#"{"type":"stream_event","event":{"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"Got it:"}},"session_id":"47a4e5c8-13f3-4a41-9f96-f10dcdd43e62","parent_tool_use_id":null,"uuid":"ef647c34-f2b7-42b0-81f8-b6874ed1b8ee","api_message_id":"msg_01"}"#;
    const TEXT_2: &str = r#"{"type":"stream_event","event":{"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":" **"}},"session_id":"47a4e5c8-13f3-4a41-9f96-f10dcdd43e62","parent_tool_use_id":null,"uuid":"ee67898a-4656-4e98-9f7f-263163a6cbb7","api_message_id":"msg_01"}"#;
    const TEXT_3: &str = r#"{"type":"stream_event","event":{"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":"teapot**."}},"session_id":"47a4e5c8-13f3-4a41-9f96-f10dcdd43e62","parent_tool_use_id":null,"uuid":"a2997b0e-7f16-42be-8004-965aa5ad4210","api_message_id":"msg_01"}"#;
    const ASSISTANT_ECHO: &str = r#"{"type":"assistant","message":{"model":"claude-haiku-5-5","id":"msg_01","type":"message","role":"assistant","content":[{"type":"text","text":"Got it: **teapot**."}],"stop_reason":null},"parent_tool_use_id":null,"session_id":"47a4e5c8-13f3-4a41-9f96-f10dcdd43e62"}"#;
    const MESSAGE_STOP: &str = r#"{"type":"stream_event","event":{"type":"message_stop"},"session_id":"47a4e5c8-13f3-4a41-9f96-f10dcdd43e62","parent_tool_use_id":null,"uuid":"0dfa17a6-f760-44c1-9215-b91a5648e15b","api_message_id":"msg_01"}"#;
    const RATE_LIMIT: &str = r#"{"type":"rate_limit_event","rate_limit_info":{"status":"allowed","rateLimitType":"five_hour"},"session_id":"47a4e5c8-13f3-4a41-9f96-f10dcdd43e62"}"#;
    const RESULT_OK: &str = r#"{"type":"result","subtype":"success","is_error":false,"duration_ms":3190,"num_turns":1,"stop_reason":"end_turn","session_id":"47a4e5c8-13f3-4a41-9f96-f10dcdd43e62","terminal_reason":"completed","result":"Got it: **teapot**."}"#;

    const RESULT_NOT_LOGGED_IN: &str = r#"{"type":"result","subtype":"success","is_error":true,"num_turns":1,"stop_reason":"stop_sequence","terminal_reason":"api_error","api_error_status":null,"result":"Not logged in · Please run /login","session_id":"11111111-2222-4333-8444-555555555555"}"#;
    const RESULT_NO_SESSION: &str = r#"{"type":"result","subtype":"error_during_execution","duration_ms":0,"duration_api_ms":0,"is_error":true,"num_turns":0,"stop_reason":null,"session_id":"99999999-2222-4333-8444-555555555555","total_cost_usd":0,"permission_denials":[],"errors":["No conversation found with session ID: 99999999-2222-4333-8444-555555555555"],"result_index":0}"#;
    const RESULT_BAD_MODEL: &str = r#"{"type":"result","subtype":"success","is_error":true,"api_error_status":404,"result":"There's an issue with the selected model (nosuchmodel). It may not exist or you may not have access to it. Run --model to pick a different model."}"#;

    #[test]
    fn a_real_first_turn_parses_to_its_deltas_and_a_single_done() {
        let transcript = [
            INIT,
            STATUS,
            THINKING_START,
            THINKING_DELTA,
            TEXT_START,
            TEXT_1,
            TEXT_2,
            TEXT_3,
            ASSISTANT_ECHO,
            MESSAGE_STOP,
            RATE_LIMIT,
            RESULT_OK,
        ];
        let parsed: Vec<Line> = transcript.iter().map(|l| parse_line(l)).collect();
        assert_eq!(
            parsed,
            vec![
                Line::Init,
                Line::Other,
                Line::Other,
                Line::Other,
                Line::Other,
                Line::Delta("Got it:".into()),
                Line::Delta(" **".into()),
                Line::Delta("teapot**.".into()),
                Line::Other,
                Line::Other,
                Line::Other,
                Line::Done,
            ]
        );
    }

    #[test]
    fn failures_keep_the_clis_wording_unless_they_have_their_own() {
        assert_eq!(
            parse_line(RESULT_NOT_LOGGED_IN),
            Line::Failed(Failure::NotLoggedIn)
        );
        assert_eq!(
            parse_line(RESULT_NO_SESSION),
            Line::Failed(Failure::SessionGone)
        );
        assert_eq!(
            parse_line(RESULT_BAD_MODEL),
            Line::Failed(Failure::Cli(
                "There's an issue with the selected model (nosuchmodel). It may not exist or you may not have access to it. Run --model to pick a different model."
                    .into()
            ))
        );
    }

    #[test]
    fn only_web_links_from_a_reply_reach_open() {
        assert_eq!(
            web_link("https://example.com/a b").map(|u| u.to_string()),
            Ok("https://example.com/a%20b".to_string())
        );
        assert_eq!(
            web_link("HTTP://example.com").map(|u| u.to_string()),
            Ok("http://example.com/".to_string())
        );
        assert_eq!(
            web_link("file:///etc/passwd"),
            Err("Only web links open from a reply, not file: links.".to_string())
        );
        assert_eq!(
            web_link("x-apple.systempreferences:com.apple.wifi-settings-extension"),
            Err("Only web links open from a reply, not x-apple.systempreferences: links.".to_string())
        );
        assert_eq!(
            web_link("-a Terminal"),
            Err("-a Terminal is not a link: relative URL without a base".to_string())
        );
    }

    #[test]
    fn a_failure_with_no_text_still_reports_something() {
        let line = r#"{"type":"result","subtype":"error_max_turns","is_error":true,"num_turns":3}"#;
        assert_eq!(
            parse_line(line),
            Line::Failed(Failure::Cli("Claude Code reported an error.".into()))
        );
    }

    #[test]
    fn junk_and_unknown_lines_are_ignored() {
        assert_eq!(parse_line(""), Line::Other);
        assert_eq!(parse_line("claude: warming up"), Line::Other);
        assert_eq!(parse_line(r#"{"type":"user","message":{}}"#), Line::Other);
        let empty = r#"{"type":"stream_event","event":{"type":"content_block_delta","index":1,"delta":{"type":"text_delta","text":""}}}"#;
        assert_eq!(parse_line(empty), Line::Other);
    }

    #[test]
    fn failure_messages_are_written_for_the_panel() {
        assert_eq!(
            Failure::CliMissing("claude".into()).message(),
            "Claude Code (\"claude\") was not found. Install it, or set assistant.command in the settings."
        );
        assert_eq!(
            Failure::NotLoggedIn.message(),
            "Claude Code is not logged in. Run claude in a terminal and sign in with /login."
        );
    }

    #[test]
    fn the_first_turn_creates_a_session_and_later_ones_resume_it() {
        let mut conversation = Conversation::default();
        let first = conversation.begin_turn();
        let SessionFlag::New(id) = first.session.clone() else {
            panic!("a fresh conversation must create a session");
        };
        conversation.established(&first);
        conversation.finished(&first);

        let second = conversation.begin_turn();
        assert_eq!(second.session, SessionFlag::Resume(id.clone()));
        assert_ne!(second.id, first.id);
        conversation.finished(&second);

        conversation.reset();
        let third = conversation.begin_turn();
        let SessionFlag::New(new_id) = third.session.clone() else {
            panic!("a reset conversation must create a session");
        };
        assert_ne!(new_id, id);
    }

    #[test]
    fn a_turn_that_never_reached_init_leaves_the_conversation_fresh() {
        let mut conversation = Conversation::default();
        let first = conversation.begin_turn();
        conversation.finished(&first);
        let retry = conversation.begin_turn();
        assert!(matches!(retry.session, SessionFlag::New(_)));
        assert_ne!(retry.session, first.session);
    }

    #[test]
    fn sending_cancels_the_running_turn_and_a_cancelled_turn_cannot_establish() {
        let mut conversation = Conversation::default();
        let first = conversation.begin_turn();
        let second = conversation.begin_turn();
        assert!(first.is_cancelled());
        assert!(!second.is_cancelled());

        conversation.established(&first);
        let third = conversation.begin_turn();
        assert!(matches!(third.session, SessionFlag::New(_)));
        assert_ne!(third.session, first.session);
    }

    #[test]
    fn reset_cancels_and_a_stale_init_after_it_is_ignored() {
        let mut conversation = Conversation::default();
        let turn = conversation.begin_turn();
        conversation.reset();
        assert!(turn.is_cancelled());
        conversation.established(&turn);
        assert!(matches!(
            conversation.begin_turn().session,
            SessionFlag::New(_)
        ));
    }

    #[test]
    fn a_vanished_session_sends_the_next_turn_to_a_new_one() {
        let mut conversation = Conversation::default();
        let first = conversation.begin_turn();
        conversation.established(&first);
        conversation.finished(&first);
        let resumed = conversation.begin_turn();
        assert!(matches!(resumed.session, SessionFlag::Resume(_)));
        conversation.lost(&resumed);
        conversation.finished(&resumed);
        assert!(matches!(
            conversation.begin_turn().session,
            SessionFlag::New(_)
        ));
    }

    #[test]
    fn cancel_is_idempotent() {
        let mut conversation = Conversation::default();
        conversation.cancel();
        let turn = conversation.begin_turn();
        conversation.cancel();
        conversation.cancel();
        assert!(turn.is_cancelled());
    }

    #[test]
    fn settle_prefers_the_result_line_over_the_exit_code() {
        assert_eq!(settle(false, Some(Ok(())), true, ""), Outcome::Done);
        assert_eq!(
            settle(false, Some(Err(Failure::NotLoggedIn)), false, "noise"),
            Outcome::Failed(Failure::NotLoggedIn)
        );
        assert_eq!(
            settle(true, Some(Err(Failure::NotLoggedIn)), false, ""),
            Outcome::Cancelled
        );
    }

    #[test]
    fn settle_without_a_result_line_reports_stderr_or_says_what_happened() {
        assert_eq!(
            settle(false, None, false, "  boom\n"),
            Outcome::Failed(Failure::Cli("boom".into()))
        );
        assert_eq!(
            settle(false, None, false, ""),
            Outcome::Failed(Failure::Cli("Claude Code stopped unexpectedly.".into()))
        );
        assert_eq!(
            settle(false, None, true, ""),
            Outcome::Failed(Failure::Cli("Claude Code ended without a reply.".into()))
        );
    }

    #[test]
    fn args_name_the_session_the_way_the_turn_needs() {
        let new = build_args("haiku", &SessionFlag::New("abc".into()));
        assert_eq!(new[new.len() - 2..], ["--session-id", "abc"]);
        let resume = build_args("haiku", &SessionFlag::Resume("abc".into()));
        assert_eq!(resume[resume.len() - 2..], ["--resume", "abc"]);
        let model = new.iter().position(|a| a == "--model").unwrap();
        assert_eq!(new[model + 1], "haiku");
    }

    fn script(scratch: &Scratch, name: &str, body: &str) -> PathBuf {
        let path = scratch.write(name, format!("#!/bin/sh\n{body}\n"));
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755)).unwrap();
        path
    }

    fn config_for(command: &Path) -> AssistantConfig {
        AssistantConfig {
            command: command.display().to_string(),
            model: "stub-model".into(),
        }
    }

    fn collect(
        config: &AssistantConfig,
        cwd: &Path,
        turn: &Turn,
        prompt: &str,
    ) -> (Outcome, Vec<String>) {
        let mut deltas = Vec::new();
        let outcome = run_cli(config, cwd, turn, prompt, |line| {
            if let Line::Delta(text) = line {
                deltas.push(text.clone());
            }
        });
        (outcome, deltas)
    }

    #[test]
    fn a_turn_streams_the_stub_reply_and_passes_prompt_args_and_cwd_through() {
        let scratch = Scratch::new("stream");
        let stub = script(
            &scratch,
            "claude",
            &format!(
                r#"printf '%s\n' "$@" > args.txt
pwd > cwd.txt
cat > prompt.txt
printf '%s\n' '{INIT}'
printf '%s\n' '{TEXT_1}'
printf '%s\n' '{TEXT_2}'
printf '%s\n' '{TEXT_3}'
printf '%s\n' '{RESULT_OK}'"#
            ),
        );
        let cwd = scratch.path().join("work");
        let turn = Turn::new(SessionFlag::Resume("sess-1".into()));
        let (outcome, deltas) =
            collect(&config_for(&stub), &cwd, &turn, "- not a flag\nsecond line");

        assert_eq!(outcome, Outcome::Done);
        assert_eq!(deltas, ["Got it:", " **", "teapot**."]);
        assert_eq!(
            std::fs::read_to_string(cwd.join("prompt.txt")).unwrap(),
            "- not a flag\nsecond line"
        );
        let args = std::fs::read_to_string(cwd.join("args.txt")).unwrap();
        let args: Vec<&str> = args.lines().collect();
        assert_eq!(args[args.len() - 2..], ["--resume", "sess-1"]);
        let model = args.iter().position(|a| *a == "--model").unwrap();
        assert_eq!(args[model + 1], "stub-model");
        let ran_in = std::fs::read_to_string(cwd.join("cwd.txt")).unwrap();
        assert_eq!(
            std::fs::canonicalize(ran_in.trim()).unwrap(),
            std::fs::canonicalize(&cwd).unwrap()
        );
    }

    #[test]
    fn init_reaches_the_caller_before_the_reply_does() {
        let scratch = Scratch::new("init");
        let stub = script(
            &scratch,
            "claude",
            &format!("printf '%s\\n' '{INIT}' '{TEXT_1}' '{RESULT_OK}'"),
        );
        let turn = Turn::new(SessionFlag::New("n".into()));
        let mut seen = Vec::new();
        let outcome = run_cli(&config_for(&stub), scratch.path(), &turn, "hi", |line| {
            seen.push(match line {
                Line::Init => "init".to_string(),
                Line::Delta(t) => format!("delta:{t}"),
                Line::Done => "done".to_string(),
                other => format!("{other:?}"),
            });
        });
        assert_eq!(outcome, Outcome::Done);
        assert_eq!(seen, ["init", "delta:Got it:", "done"]);
    }

    #[test]
    fn a_login_failure_on_stdout_beats_the_exit_code() {
        let scratch = Scratch::new("login");
        let stub = script(
            &scratch,
            "claude",
            &format!("cat > /dev/null\nprintf '%s\\n' '{RESULT_NOT_LOGGED_IN}'\nexit 1"),
        );
        let turn = Turn::new(SessionFlag::New("n".into()));
        let (outcome, deltas) = collect(&config_for(&stub), scratch.path(), &turn, "hi");
        assert_eq!(outcome, Outcome::Failed(Failure::NotLoggedIn));
        assert!(deltas.is_empty());
    }

    #[test]
    fn a_crash_with_no_result_reports_stderr() {
        let scratch = Scratch::new("crash");
        let stub = script(
            &scratch,
            "claude",
            "cat > /dev/null\necho 'segfault, probably' >&2\nexit 3",
        );
        let turn = Turn::new(SessionFlag::New("n".into()));
        let (outcome, _) = collect(&config_for(&stub), scratch.path(), &turn, "hi");
        assert_eq!(
            outcome,
            Outcome::Failed(Failure::Cli("segfault, probably".into()))
        );
    }

    #[test]
    fn a_missing_cli_is_reported_by_name() {
        let scratch = Scratch::new("missing");
        let config = AssistantConfig {
            command: "no-such-claude-binary".into(),
            model: "m".into(),
        };
        let turn = Turn::new(SessionFlag::New("n".into()));
        let (outcome, _) = collect(&config, scratch.path(), &turn, "hi");
        assert_eq!(
            outcome,
            Outcome::Failed(Failure::CliMissing("no-such-claude-binary".into()))
        );
    }

    #[test]
    fn cancelling_from_another_thread_kills_the_process_and_ends_the_turn() {
        let scratch = Scratch::new("cancel");
        // `exec` so the sleep is the process we kill, not a child of a shell.
        let stub = script(
            &scratch,
            "claude",
            &format!("printf '%s\\n' '{INIT}' '{TEXT_1}'\nexec sleep 30"),
        );
        let turn = Arc::new(Turn::new(SessionFlag::New("n".into())));
        let (replied_tx, replied_rx) = std::sync::mpsc::channel();
        let canceller = {
            let turn = turn.clone();
            std::thread::spawn(move || {
                replied_rx.recv().unwrap();
                turn.cancel();
            })
        };
        let started = Instant::now();
        let outcome = run_cli(&config_for(&stub), scratch.path(), &turn, "hi", |line| {
            if matches!(line, Line::Delta(_)) {
                let _ = replied_tx.send(());
            }
        });
        canceller.join().unwrap();
        assert_eq!(outcome, Outcome::Cancelled);
        assert!(
            started.elapsed() < Duration::from_secs(10),
            "cancel took {:?}",
            started.elapsed()
        );
    }

    #[test]
    fn a_turn_cancelled_before_it_starts_spawns_nothing() {
        let scratch = Scratch::new("early-cancel");
        let stub = script(&scratch, "claude", "touch ran.txt\nexec sleep 30");
        let turn = Turn::new(SessionFlag::New("n".into()));
        turn.cancel();
        let (outcome, _) = collect(&config_for(&stub), scratch.path(), &turn, "hi");
        assert_eq!(outcome, Outcome::Cancelled);
        assert!(!scratch.path().join("ran.txt").exists());
    }

    #[test]
    fn resolve_command_checks_paths_then_path_then_local_bin() {
        let scratch = Scratch::new("resolve");
        let on_path = scratch.path().join("on-path");
        let home = scratch.path().join("home");
        std::fs::create_dir_all(&on_path).unwrap();
        std::fs::create_dir_all(home.join(".local/bin")).unwrap();
        let path_var =
            std::env::join_paths([scratch.path().join("empty"), on_path.clone()]).unwrap();

        let local = home.join(".local/bin/claude");
        std::fs::write(&local, "#!/bin/sh\n").unwrap();
        std::fs::set_permissions(&local, std::fs::Permissions::from_mode(0o755)).unwrap();
        assert_eq!(
            resolve_command("claude", Some(&path_var), Some(&home)),
            Some(local.clone())
        );

        let first = on_path.join("claude");
        std::fs::write(&first, "#!/bin/sh\n").unwrap();
        std::fs::set_permissions(&first, std::fs::Permissions::from_mode(0o755)).unwrap();
        assert_eq!(
            resolve_command("claude", Some(&path_var), Some(&home)),
            Some(first.clone())
        );

        std::fs::set_permissions(&first, std::fs::Permissions::from_mode(0o644)).unwrap();
        assert_eq!(
            resolve_command("claude", Some(&path_var), Some(&home)),
            Some(local.clone())
        );

        let given = local.display().to_string();
        assert_eq!(resolve_command(&given, None, None), Some(local));
        assert_eq!(
            resolve_command(&first.display().to_string(), Some(&path_var), Some(&home)),
            None
        );
        assert_eq!(resolve_command("claude", None, None), None);
    }

    fn mock_app() -> tauri::App<tauri::test::MockRuntime> {
        let app = tauri::test::mock_app();
        app.manage(AssistantState::default());
        app
    }

    fn record(app: &tauri::App<tauri::test::MockRuntime>) -> Arc<Mutex<Vec<serde_json::Value>>> {
        use tauri::Listener;
        let events = Arc::new(Mutex::new(Vec::new()));
        let sink = events.clone();
        app.listen("assistant", move |event| {
            lock(&sink).push(serde_json::from_str(event.payload()).unwrap());
        });
        events
    }

    #[test]
    fn turns_reach_the_webview_as_deltas_then_done_and_the_second_resumes_the_first() {
        let scratch = Scratch::new("events");
        let stub = script(
            &scratch,
            "claude",
            &format!(
                "cat > /dev/null\nprintf '%s\\n' \"$@\" >> args.log\necho --- >> args.log\nprintf '%s\\n' '{INIT}' '{TEXT_1}' '{TEXT_3}' '{RESULT_OK}'"
            ),
        );
        let config = config_for(&stub);
        let app = mock_app();
        let events = record(&app);
        let state = app.state::<AssistantState>();

        let first = lock(&state.conversation).begin_turn();
        run_turn(app.handle(), &first, "one", &config, scratch.path());
        let second = lock(&state.conversation).begin_turn();
        run_turn(app.handle(), &second, "two", &config, scratch.path());

        let expected: Vec<serde_json::Value> = [&first, &second]
            .iter()
            .flat_map(|turn| {
                [
                    serde_json::json!({"turn": turn.id, "kind": "delta", "text": "Got it:"}),
                    serde_json::json!({"turn": turn.id, "kind": "delta", "text": "teapot**."}),
                    serde_json::json!({"turn": turn.id, "kind": "done", "text": ""}),
                ]
            })
            .collect();
        assert_eq!(*lock(&events), expected);

        let log = std::fs::read_to_string(scratch.path().join("args.log")).unwrap();
        let runs: Vec<Vec<&str>> = log
            .split("---\n")
            .filter(|run| !run.is_empty())
            .map(|run| run.lines().collect())
            .collect();
        let [one, two] = runs.as_slice() else {
            panic!("expected two CLI runs, got {runs:?}");
        };
        let session = one[one.len() - 1];
        assert_eq!(one[one.len() - 2], "--session-id");
        assert_eq!(two[two.len() - 2..], ["--resume", session]);
    }

    #[test]
    fn a_failed_turn_ends_with_one_error_event_in_words_for_the_panel() {
        let scratch = Scratch::new("error-event");
        let stub = script(
            &scratch,
            "claude",
            &format!("cat > /dev/null\nprintf '%s\\n' '{RESULT_NOT_LOGGED_IN}'\nexit 1"),
        );
        let app = mock_app();
        let events = record(&app);
        let turn = lock(&app.state::<AssistantState>().conversation).begin_turn();
        run_turn(
            app.handle(),
            &turn,
            "hi",
            &config_for(&stub),
            scratch.path(),
        );
        assert_eq!(
            *lock(&events),
            vec![serde_json::json!({
                "turn": turn.id,
                "kind": "error",
                "text": "Claude Code is not logged in. Run claude in a terminal and sign in with /login."
            })]
        );
    }

    #[test]
    fn a_cancelled_turn_still_ends_with_done_and_a_reset_forgets_the_session() {
        let scratch = Scratch::new("cancel-event");
        let stub = script(
            &scratch,
            "claude",
            &format!("printf '%s\\n' '{INIT}' '{TEXT_1}'\nexec sleep 30"),
        );
        let config = config_for(&stub);
        let app = mock_app();
        let events = record(&app);
        let state = app.state::<AssistantState>();
        let turn = lock(&state.conversation).begin_turn();
        let session = turn.session.clone();

        let handle = app.handle().clone();
        std::thread::scope(|scope| {
            let runner = scope.spawn(|| run_turn(&handle, &turn, "hi", &config, scratch.path()));
            while lock(&events).is_empty() {
                std::thread::sleep(Duration::from_millis(20));
            }
            tauri::async_runtime::block_on(assistant_cancel(handle.clone()));
            runner.join().unwrap();
        });
        assert_eq!(
            *lock(&events),
            vec![
                serde_json::json!({"turn": turn.id, "kind": "delta", "text": "Got it:"}),
                serde_json::json!({"turn": turn.id, "kind": "done", "text": ""}),
            ]
        );

        let SessionFlag::New(id) = session else {
            panic!("the first turn must create a session");
        };
        let resumed = lock(&state.conversation).begin_turn();
        assert_eq!(resumed.session, SessionFlag::Resume(id.clone()));
        tauri::async_runtime::block_on(assistant_reset(handle.clone()));
        assert!(resumed.is_cancelled());
        let fresh = lock(&state.conversation).begin_turn();
        assert!(matches!(&fresh.session, SessionFlag::New(new) if *new != id));
    }

    #[test]
    #[ignore = "live: three short turns of the real Claude CLI"]
    fn live_conversation_remembers_and_survives_a_cancel() {
        let config = crate::settings::load(crate::settings::dir().as_deref())
            .config
            .assistant;
        let scratch = Scratch::new("assistant-live");
        let cwd = scratch.path();
        let session = uuid::Uuid::new_v4().to_string();

        let ask = |flag: SessionFlag, prompt: &str| {
            let turn = Turn::new(flag);
            let started = Instant::now();
            let mut first_delta = None;
            let mut established = false;
            let mut reply = String::new();
            let outcome = run_cli(&config, cwd, &turn, prompt, |line| match line {
                Line::Init => established = true,
                Line::Delta(text) => {
                    first_delta.get_or_insert(started.elapsed());
                    reply.push_str(text);
                }
                _ => {}
            });
            println!(
                "turn {:?}: outcome {:?}, init seen {established}, first delta after {:?}, total {:?}, {} chars: {reply:?}",
                turn.session,
                outcome,
                first_delta,
                started.elapsed(),
                reply.len()
            );
            assert_eq!(outcome, Outcome::Done);
            reply
        };

        ask(
            SessionFlag::New(session.clone()),
            "Remember the word teapot.",
        );
        let second = ask(
            SessionFlag::Resume(session.clone()),
            "What word did I ask you to remember?",
        );
        assert!(
            second.to_lowercase().contains("teapot"),
            "the second reply forgot the word: {second:?}"
        );

        let long = Turn::new(SessionFlag::Resume(session.clone()));
        let started = Instant::now();
        let outcome = run_cli(
            &config,
            cwd,
            &long,
            "Count from 1 to 300, one number per line.",
            |line| {
                if matches!(line, Line::Delta(_)) {
                    long.cancel();
                }
            },
        );
        println!("cancelled turn: {outcome:?} after {:?}", started.elapsed());
        assert_eq!(outcome, Outcome::Cancelled);
        assert!(started.elapsed() < Duration::from_secs(15));

        let after = ask(
            SessionFlag::Resume(session),
            "Which word did I ask you to remember? Answer with the word only.",
        );
        assert!(
            after.to_lowercase().contains("teapot"),
            "the conversation did not survive the cancel: {after:?}"
        );
    }
}

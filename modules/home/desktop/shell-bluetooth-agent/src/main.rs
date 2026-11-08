//! A BlueZ pairing agent for the custom Quickshell shell's Bluetooth page, which runs it
//! while the page shows. It registers as the default agent on the system bus, prints each
//! request from BlueZ as a JSON line on stdout and reads the page's answers as JSON lines
//! on stdin. It registers again whenever bluetoothd starts or releases it, and exits when
//! stdin closes. Which device may pair is the page's decision, not the agent's.

use ordered_stream::OrderedStreamExt;
use serde::Serialize;
use serde_json::Value;
use std::collections::HashMap;
use std::io::Write;
use std::num::NonZeroUsize;
use std::sync::{Arc, Mutex};
use zbus::{interface, Connection, ObjectPath};
use zruntime::mpmc;

const AGENT_PATH: ObjectPath<'static> =
    ObjectPath::from_static_str_unchecked("/org/custom_shell/BluetoothAgent");
const BLUEZ: &str = "org.bluez";

/// A request from BlueZ that waits for the page's answer, printed with its id.
#[derive(Serialize)]
#[serde(tag = "method")]
enum Question {
    RequestConfirmation { device: String, passkey: u32 },
    RequestAuthorization { device: String },
    AuthorizeService { device: String, uuid: String },
    RequestPinCode { device: String },
    RequestPasskey { device: String },
}

#[derive(Serialize)]
struct Asked {
    id: u64,
    #[serde(flatten)]
    question: Question,
}

/// What the page is told without being asked.
#[derive(Serialize)]
#[serde(tag = "method")]
enum Notice {
    DisplayPinCode {
        device: String,
        pincode: String,
    },
    DisplayPasskey {
        device: String,
        passkey: u32,
        entered: u16,
    },
    Cancel,
}

#[derive(Debug, PartialEq)]
enum Reply {
    Accept,
    PinCode(String),
    Passkey(u32),
    Reject,
}

/// One line from the page: the id it answers and the answer. A line with an id but a
/// malformed or out-of-range answer rejects; a line with no id answers nothing.
fn parse(line: &str) -> Option<(u64, Reply)> {
    let Ok(Value::Object(fields)) = serde_json::from_str(line) else {
        return None;
    };
    let id = fields.get("id")?.as_u64()?;
    let reply = match (
        fields.get("accept"),
        fields.get("pincode"),
        fields.get("passkey"),
    ) {
        (Some(Value::Bool(true)), None, None) => Reply::Accept,
        (None, Some(Value::String(pin)), None)
            if (1..=16).contains(&pin.len()) && pin.bytes().all(|b| b.is_ascii_alphanumeric()) =>
        {
            Reply::PinCode(pin.clone())
        }
        (None, None, Some(passkey)) => match passkey.as_u64() {
            Some(passkey @ 0..=999_999) => Reply::Passkey(passkey as u32),
            _ => Reply::Reject,
        },
        _ => Reply::Reject,
    };
    Some((id, reply))
}

/// `/org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF` to `AA:BB:CC:DD:EE:FF`, the address Quickshell
/// gives a device.
fn address(device: &str) -> String {
    match device.rsplit_once("/dev_") {
        Some((_, address)) => address.replace('_', ":"),
        None => device.to_owned(),
    }
}

fn print(message: &impl Serialize) {
    let line = serde_json::to_string(message).expect("plain structs serialise");
    let mut stdout = std::io::stdout().lock();
    // The page going away closes stdin too, and that ends the program.
    let _ = writeln!(stdout, "{line}").and_then(|()| stdout.flush());
}

#[derive(Default)]
struct Pending {
    next_id: u64,
    replies: HashMap<u64, mpmc::Sender<Reply>>,
}

#[derive(zbus::DBusError, Debug)]
#[zbus(prefix = "org.bluez.Error")]
enum AgentError {
    Rejected,
    Canceled,
}

struct Agent {
    pending: Arc<Mutex<Pending>>,
}

impl Agent {
    /// Prints the question and waits for its answer. A BlueZ `Cancel` drops the sender,
    /// which ends the wait.
    async fn ask(&self, question: Question) -> Result<Reply, AgentError> {
        let (sender, receiver) = mpmc::bounded(NonZeroUsize::MIN);
        let id = {
            let mut pending = self.pending.lock().unwrap();
            pending.next_id += 1;
            let id = pending.next_id;
            pending.replies.insert(id, sender);
            id
        };
        print(&Asked { id, question });
        receiver.recv().await.map_err(|_| AgentError::Canceled)
    }

    async fn confirm(&self, question: Question) -> Result<(), AgentError> {
        match self.ask(question).await? {
            Reply::Accept => Ok(()),
            _ => Err(AgentError::Rejected),
        }
    }
}

#[interface(name = "org.bluez.Agent1")]
impl Agent {
    async fn request_pin_code(&self, device: ObjectPath<'_>) -> Result<String, AgentError> {
        let device = address(&device);
        match self.ask(Question::RequestPinCode { device }).await? {
            Reply::PinCode(pin) => Ok(pin),
            _ => Err(AgentError::Rejected),
        }
    }

    async fn request_passkey(&self, device: ObjectPath<'_>) -> Result<u32, AgentError> {
        let device = address(&device);
        match self.ask(Question::RequestPasskey { device }).await? {
            Reply::Passkey(passkey) => Ok(passkey),
            _ => Err(AgentError::Rejected),
        }
    }

    async fn request_confirmation(
        &self,
        device: ObjectPath<'_>,
        passkey: u32,
    ) -> Result<(), AgentError> {
        let device = address(&device);
        self.confirm(Question::RequestConfirmation { device, passkey })
            .await
    }

    async fn request_authorization(&self, device: ObjectPath<'_>) -> Result<(), AgentError> {
        let device = address(&device);
        self.confirm(Question::RequestAuthorization { device })
            .await
    }

    async fn authorize_service(
        &self,
        device: ObjectPath<'_>,
        uuid: String,
    ) -> Result<(), AgentError> {
        let device = address(&device);
        self.confirm(Question::AuthorizeService { device, uuid })
            .await
    }

    fn display_pin_code(&self, device: ObjectPath<'_>, pincode: String) {
        let device = address(&device);
        print(&Notice::DisplayPinCode { device, pincode });
    }

    fn display_passkey(&self, device: ObjectPath<'_>, passkey: u32, entered: u16) {
        let device = address(&device);
        print(&Notice::DisplayPasskey {
            device,
            passkey,
            entered,
        });
    }

    fn cancel(&self) {
        self.pending.lock().unwrap().replies.clear();
        print(&Notice::Cancel);
    }

    async fn release(&self, #[zbus(connection)] connection: &Connection) {
        register(connection).await;
    }
}

/// Makes this the default agent, whether or not bluetoothd already knows it.
async fn register(connection: &Connection) {
    const MANAGER: Option<&str> = Some("org.bluez.AgentManager1");
    let registered = connection
        .call_method(
            Some(BLUEZ),
            "/org/bluez",
            MANAGER,
            "RegisterAgent",
            &(AGENT_PATH, "KeyboardDisplay"),
        )
        .await;
    match registered {
        Ok(_) => {}
        Err(zbus::Error::MethodError(name, _, _))
            if name.as_str() == "org.bluez.Error.AlreadyExists" => {}
        Err(e) => return eprintln!("RegisterAgent: {e}"),
    }
    let default = connection
        .call_method(
            Some(BLUEZ),
            "/org/bluez",
            MANAGER,
            "RequestDefaultAgent",
            &(AGENT_PATH,),
        )
        .await;
    if let Err(e) = default {
        eprintln!("RequestDefaultAgent: {e}");
    }
}

async fn serve(agent: Agent) -> zbus::Result<()> {
    let connection = zbus::connection::Builder::system()
        .serve_at(AGENT_PATH, agent)
        .build()
        .await?;
    let bus = zbus::fdo::DBusProxy::new(&connection).await?;
    // Watched before the first look, so a bluetoothd that starts in between is not missed.
    let mut owners = bus
        .receive_name_owner_changed_with_args(&[(0, BLUEZ)])
        .await?;
    if bus.name_has_owner(BLUEZ.try_into()?).await? {
        register(&connection).await;
    }
    while let Some(change) = owners.next().await {
        if change.args()?.new_owner().is_some() {
            register(&connection).await;
        }
    }
    Ok(())
}

fn main() {
    let pending = Arc::new(Mutex::new(Pending::default()));
    let agent = Agent {
        pending: Arc::clone(&pending),
    };
    std::thread::spawn(move || {
        if let Err(e) = zbus::block_on(serve(agent)) {
            eprintln!("system bus: {e}");
        }
    });

    for line in std::io::stdin().lines() {
        let Ok(line) = line else { break };
        let Some((id, reply)) = parse(&line) else {
            eprintln!("not an answer: {line}");
            continue;
        };
        match pending.lock().unwrap().replies.remove(&id) {
            Some(sender) => {
                let _ = sender.try_send(reply);
            }
            None => eprintln!("no request {id}"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn device_path_to_address() {
        assert_eq!(
            address("/org/bluez/hci0/dev_A8_8C_3E_2B_D8_3B"),
            "A8:8C:3E:2B:D8:3B"
        );
        assert_eq!(address("/org/bluez/hci0"), "/org/bluez/hci0");
    }

    #[test]
    fn answers() {
        let cases = [
            (r#"{"id":1,"accept":true}"#, Some((1, Reply::Accept))),
            (r#"{"id":1,"accept":false}"#, Some((1, Reply::Reject))),
            (
                r#"{"id":4,"pincode":"0000"}"#,
                Some((4, Reply::PinCode("0000".into()))),
            ),
            (
                r#"{"id":4,"pincode":"abcDEF0123456789"}"#,
                Some((4, Reply::PinCode("abcDEF0123456789".into()))),
            ),
            (r#"{"id":5,"passkey":123}"#, Some((5, Reply::Passkey(123)))),
            (r#"{"id":5,"passkey":0}"#, Some((5, Reply::Passkey(0)))),
            (
                r#"{"id":5,"passkey":999999}"#,
                Some((5, Reply::Passkey(999_999))),
            ),
            // Malformed or out of range, with an id: rejected.
            (r#"{"id":4,"pincode":""}"#, Some((4, Reply::Reject))),
            (
                r#"{"id":4,"pincode":"abcDEF01234567890"}"#,
                Some((4, Reply::Reject)),
            ),
            (r#"{"id":4,"pincode":"12 4"}"#, Some((4, Reply::Reject))),
            (r#"{"id":4,"pincode":"1234é"}"#, Some((4, Reply::Reject))),
            (r#"{"id":4,"pincode":1234}"#, Some((4, Reply::Reject))),
            (r#"{"id":5,"passkey":1000000}"#, Some((5, Reply::Reject))),
            (r#"{"id":5,"passkey":-1}"#, Some((5, Reply::Reject))),
            (r#"{"id":5,"passkey":1.5}"#, Some((5, Reply::Reject))),
            (r#"{"id":5,"passkey":"123"}"#, Some((5, Reply::Reject))),
            (r#"{"id":1,"accept":"yes"}"#, Some((1, Reply::Reject))),
            (r#"{"id":1}"#, Some((1, Reply::Reject))),
            (
                r#"{"id":1,"accept":true,"pincode":"0000"}"#,
                Some((1, Reply::Reject)),
            ),
            // No id to answer.
            (r#"{"accept":true}"#, None),
            (r#"{"id":-1,"accept":true}"#, None),
            (r#"{"id":"1","accept":true}"#, None),
            (r#"[1,true]"#, None),
            ("accept", None),
            ("", None),
        ];
        for (line, expected) in cases {
            assert_eq!(parse(line), expected, "{line}");
        }
    }

    #[test]
    fn printed_lines() {
        let asked = Asked {
            id: 1,
            question: Question::RequestConfirmation {
                device: "AA:BB:CC:DD:EE:FF".into(),
                passkey: 123456,
            },
        };
        assert_eq!(
            serde_json::to_string(&asked).unwrap(),
            r#"{"id":1,"method":"RequestConfirmation","device":"AA:BB:CC:DD:EE:FF","passkey":123456}"#
        );
        let notice = Notice::DisplayPasskey {
            device: "AA:BB:CC:DD:EE:FF".into(),
            passkey: 42,
            entered: 0,
        };
        assert_eq!(
            serde_json::to_string(&notice).unwrap(),
            r#"{"method":"DisplayPasskey","device":"AA:BB:CC:DD:EE:FF","passkey":42,"entered":0}"#
        );
        assert_eq!(
            serde_json::to_string(&Notice::Cancel).unwrap(),
            r#"{"method":"Cancel"}"#
        );
    }
}

//! The NVIDIA GPU, through NVML loaded at run time, and only while the GPU is awake.
//!
//! A laptop's discrete GPU sleeps when idle (PCI runtime power management), and an NVML
//! query wakes it. So the device's runtime status is read from sysfs first, and NVML is
//! not touched while it is not "active". Where the GPU can sleep (its runtime control is
//! "auto"), NVML is also shut down after every sample, so this program never holds the
//! device open between samples.

use std::ffi::{c_char, c_int, c_uint, c_ulonglong, c_void, CStr, CString};
use std::fs;

type Device = *mut c_void;
type Return = c_int;
const SUCCESS: Return = 0;
const TEMPERATURE_GPU: c_int = 0;

#[repr(C)]
#[derive(Default)]
struct Utilization {
    gpu: c_uint,
    memory: c_uint,
}

#[repr(C)]
#[derive(Default)]
struct Memory {
    total: c_ulonglong,
    free: c_ulonglong,
    used: c_ulonglong,
}

/// nvmlMemory_v2_t: `used` leaves out what the driver reserves, as nvidia-smi shows it.
#[repr(C)]
#[derive(Default)]
struct MemoryV2 {
    version: c_uint,
    total: c_ulonglong,
    reserved: c_ulonglong,
    free: c_ulonglong,
    used: c_ulonglong,
}

/// NVML_STRUCT_VERSION(Memory, 2): the struct's size, with the version in the top byte.
const MEMORY_V2: c_uint = std::mem::size_of::<MemoryV2>() as c_uint | (2 << 24);

/// A symbol's address as the function pointer type `F`.
///
/// # Safety
/// `F` must be the function's real signature.
unsafe fn function<F>(address: *mut c_void) -> F {
    std::mem::transmute_copy::<*mut c_void, F>(&address)
}

/// The NVML functions used here, with their signatures from NVIDIA's nvml.h.
struct Nvml {
    init: unsafe extern "C" fn() -> Return,
    shutdown: unsafe extern "C" fn() -> Return,
    by_bus_id: unsafe extern "C" fn(*const c_char, *mut Device) -> Return,
    name: unsafe extern "C" fn(Device, *mut c_char, c_uint) -> Return,
    utilization: unsafe extern "C" fn(Device, *mut Utilization) -> Return,
    memory: unsafe extern "C" fn(Device, *mut Memory) -> Return,
    memory_v2: Option<unsafe extern "C" fn(Device, *mut MemoryV2) -> Return>,
    temperature: unsafe extern "C" fn(Device, c_int, *mut c_uint) -> Return,
    power: unsafe extern "C" fn(Device, *mut c_uint) -> Return,
}

impl Nvml {
    /// NixOS keeps the driver's libraries in /run/opengl-driver/lib, outside the
    /// default search path.
    fn load() -> Option<Nvml> {
        for name in [
            "libnvidia-ml.so.1",
            "/run/opengl-driver/lib/libnvidia-ml.so.1",
        ] {
            let path = CString::new(name).ok()?;
            // SAFETY: dlopen with a valid C string; a null result is handled.
            let lib = unsafe { libc::dlopen(path.as_ptr(), libc::RTLD_NOW | libc::RTLD_LOCAL) };
            if lib.is_null() {
                continue;
            }
            let symbol = |s: &str| -> Option<*mut c_void> {
                let s = CString::new(s).ok()?;
                // SAFETY: dlsym on the handle just opened; a null result is handled.
                let p = unsafe { libc::dlsym(lib, s.as_ptr()) };
                (!p.is_null()).then_some(p)
            };
            // SAFETY: each symbol has the signature declared for it in `Nvml` (nvml.h).
            // The library stays loaded for the life of the program.
            unsafe {
                return Some(Nvml {
                    init: function(symbol("nvmlInit_v2")?),
                    shutdown: function(symbol("nvmlShutdown")?),
                    by_bus_id: function(symbol("nvmlDeviceGetHandleByPciBusId_v2")?),
                    name: function(symbol("nvmlDeviceGetName")?),
                    utilization: function(symbol("nvmlDeviceGetUtilizationRates")?),
                    memory: function(symbol("nvmlDeviceGetMemoryInfo")?),
                    memory_v2: symbol("nvmlDeviceGetMemoryInfo_v2").map(|p| function(p)),
                    temperature: function(symbol("nvmlDeviceGetTemperature")?),
                    power: function(symbol("nvmlDeviceGetPowerUsage")?),
                });
            }
        }
        None
    }
}

pub enum GpuSample {
    /// No NVIDIA GPU.
    Absent,
    /// Present but sleeping; left alone.
    Asleep,
    /// Awake, but NVML could not be loaded or answered with an error.
    Unavailable,
    Awake {
        name: String,
        /// Percent.
        usage: f64,
        /// Bytes.
        memory_used: f64,
        memory_total: f64,
        /// Degrees Celsius.
        temp: Option<f64>,
        /// Watts.
        power: Option<f64>,
    },
}

pub struct Gpu {
    /// PCI address, as in /sys/bus/pci/devices.
    address: Option<String>,
    can_sleep: bool,
    nvml: Option<Nvml>,
    initialised: bool,
}

impl Gpu {
    pub fn new() -> Self {
        let address = find_nvidia();
        let can_sleep = address
            .as_ref()
            .and_then(|a| {
                fs::read_to_string(format!("/sys/bus/pci/devices/{a}/power/control")).ok()
            })
            .is_some_and(|c| c.trim() == "auto");
        Gpu {
            address,
            can_sleep,
            nvml: None,
            initialised: false,
        }
    }

    pub fn sample(&mut self) -> GpuSample {
        let Some(address) = self.address.clone() else {
            return GpuSample::Absent;
        };
        let status = fs::read_to_string(format!(
            "/sys/bus/pci/devices/{address}/power/runtime_status"
        ))
        .unwrap_or_default();
        // "unsupported" means no runtime power management: always awake.
        if !matches!(status.trim(), "active" | "unsupported") {
            return GpuSample::Asleep;
        }
        if self.nvml.is_none() {
            self.nvml = Nvml::load();
        }
        let Some(nvml) = &self.nvml else {
            return GpuSample::Unavailable;
        };
        if !self.initialised {
            // SAFETY: NVML's documented entry point, called before any query.
            if unsafe { (nvml.init)() } != SUCCESS {
                return GpuSample::Unavailable;
            }
            self.initialised = true;
        }
        let sample = query(nvml, &address);
        if self.can_sleep {
            // SAFETY: balances the nvmlInit_v2 above.
            unsafe { (nvml.shutdown)() };
            self.initialised = false;
        }
        sample
    }
}

fn query(nvml: &Nvml, address: &str) -> GpuSample {
    let Ok(bus_id) = CString::new(address) else {
        return GpuSample::Unavailable;
    };
    let mut device: Device = std::ptr::null_mut();
    let mut name = [0 as c_char; 96];
    let mut utilization = Utilization::default();
    let mut memory = Memory::default();
    let mut temp: c_uint = 0;
    let mut milliwatts: c_uint = 0;
    // SAFETY: NVML calls with out-pointers to locals of the declared types.
    unsafe {
        if (nvml.by_bus_id)(bus_id.as_ptr(), &mut device) != SUCCESS
            || (nvml.utilization)(device, &mut utilization) != SUCCESS
        {
            return GpuSample::Unavailable;
        }
        // The v2 call where the driver has it (it reports the reserve apart), else v1.
        let mut v2 = MemoryV2 {
            version: MEMORY_V2,
            ..Default::default()
        };
        let (memory_used, memory_total) = match nvml.memory_v2 {
            Some(f) if f(device, &mut v2) == SUCCESS => (v2.used, v2.total),
            _ => {
                if (nvml.memory)(device, &mut memory) != SUCCESS {
                    return GpuSample::Unavailable;
                }
                (memory.used, memory.total)
            }
        };
        let name = if (nvml.name)(device, name.as_mut_ptr(), name.len() as c_uint) == SUCCESS {
            CStr::from_ptr(name.as_ptr()).to_string_lossy().into_owned()
        } else {
            String::from("NVIDIA GPU")
        };
        let temp = ((nvml.temperature)(device, TEMPERATURE_GPU, &mut temp) == SUCCESS)
            .then_some(temp as f64);
        let power = ((nvml.power)(device, &mut milliwatts) == SUCCESS)
            .then_some(milliwatts as f64 / 1000.0);
        GpuSample::Awake {
            name,
            usage: utilization.gpu as f64,
            memory_used: memory_used as f64,
            memory_total: memory_total as f64,
            temp,
            power,
        }
    }
}

/// The first NVIDIA display controller (vendor 0x10de, PCI class 0x03xxxx).
fn find_nvidia() -> Option<String> {
    for entry in fs::read_dir("/sys/bus/pci/devices").ok()?.flatten() {
        let dir = entry.path();
        let vendor = fs::read_to_string(dir.join("vendor")).unwrap_or_default();
        let class = fs::read_to_string(dir.join("class")).unwrap_or_default();
        if vendor.trim() == "0x10de" && class.trim().starts_with("0x03") {
            return Some(entry.file_name().to_string_lossy().into_owned());
        }
    }
    None
}

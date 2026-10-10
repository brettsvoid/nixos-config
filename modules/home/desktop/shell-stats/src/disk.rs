//! Usage of the main filesystems: one mount per block device (the shortest path, since
//! btrfs subvolumes of one device share their numbers), leaving out /boot and /efi.

use std::collections::BTreeMap;
use std::ffi::CString;
use std::fs;

pub struct DiskSample {
    pub mount: String,
    pub total: f64,
    pub used: f64,
}

pub fn sample() -> Vec<DiskSample> {
    let mounts = fs::read_to_string("/proc/self/mounts").unwrap_or_default();
    let mut by_device: BTreeMap<String, String> = BTreeMap::new();
    for line in mounts.lines() {
        let mut fields = line.split_whitespace();
        let (Some(device), Some(mount)) = (fields.next(), fields.next()) else {
            continue;
        };
        if !device.starts_with("/dev/") || mount.starts_with("/boot") || mount.starts_with("/efi") {
            continue;
        }
        // /proc/self/mounts writes spaces in paths as \040.
        let mount = mount.replace("\\040", " ");
        let entry = by_device
            .entry(device.to_string())
            .or_insert_with(|| mount.clone());
        if mount.len() < entry.len() {
            *entry = mount;
        }
    }
    let mut out: Vec<DiskSample> = by_device
        .into_values()
        .filter_map(|mount| usage(&mount))
        .collect();
    out.sort_by(|a, b| a.mount.cmp(&b.mount));
    out
}

fn usage(mount: &str) -> Option<DiskSample> {
    let path = CString::new(mount).ok()?;
    let mut stat: libc::statvfs = unsafe { std::mem::zeroed() };
    // SAFETY: a valid C string and a zeroed statvfs for the call to fill.
    if unsafe { libc::statvfs(path.as_ptr(), &mut stat) } != 0 {
        return None;
    }
    let block = stat.f_frsize as f64;
    let total = stat.f_blocks as f64 * block;
    // Used as `df` counts it: blocks not free, root's reserve included.
    let used = (stat.f_blocks - stat.f_bfree) as f64 * block;
    Some(DiskSample {
        mount: mount.to_string(),
        total,
        used,
    })
}

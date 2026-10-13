#!/usr/bin/env python3
"""vnode-watch — record what fills the kernel's vnode table.

When every vnode is referenced and none can be recycled, XNU's new_vnode()
gives up with ENFILE (bsd/vfs/vfs_subr.c), so any path lookup or page-in
fails with "Too many open files in system", however few files are open.
Processes that page in code at that moment die with SIGBUS, and launchd can
drop the agents for good. The kernel logs the counts that would explain it
("vnode: table is full", then "... desired, ... numvnodes, ..."), but kernel
logs on a busy Mac last only hours.

So this runs as root from boot and:

  - samples the vnode and open-file counters every second. It writes every
    sample for the first --boot-window seconds after boot and while usage is
    high, and one a minute otherwise;
  - writes the top processes by vnode fds and by disk reads every 30 s in
    the boot window, and every 5 s while vnodes in use exceed --threshold of
    the table;
  - once per episode over the threshold, starts lsof (which also lists
    mmapped files and working directories, the vnodes held without an fd)
    and a spindump, then saves the kernel's "table is full" lines when the
    episode ends.

kern.num_files against vnodes in use says which kind of holder it is: if
open files track the climb, a process is holding fds; if they stay flat,
the vnodes are held some other way.

A process that pages in code during exhaustion dies too, so everything is
imported and run once at start-up, and the samples go to a file opened at
start, which needs no new vnode to write.
"""

import argparse
import ctypes
import ctypes.util
import glob
import os
import subprocess
import sys
import time
from datetime import datetime

LIBC = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)
# Declared, not left to ctypes' int default: on arm64 a 32-bit int in a
# 64-bit register leaves the top half undefined, and proc_pidinfo's `arg`
# is a uint64_t.
_P, _I, _U32 = ctypes.c_void_p, ctypes.c_int, ctypes.c_uint32
LIBC.sysctlbyname.argtypes = [
    ctypes.c_char_p,
    _P,
    ctypes.POINTER(ctypes.c_size_t),
    _P,
    ctypes.c_size_t,
]
LIBC.proc_listallpids.argtypes = [_P, _I]
LIBC.proc_pidinfo.argtypes = [_I, _I, ctypes.c_uint64, _P, _I]
LIBC.proc_pid_rusage.argtypes = [_I, _I, _P]
LIBC.proc_pidpath.argtypes = [_I, _P, _U32]
LIBC.proc_name.argtypes = [_I, _P, _U32]

PROC_PIDLISTFDS = 1
PROX_FDTYPE_VNODE = 1
PROC_PIDPATHINFO_MAXSIZE = 4096
RUSAGE_INFO_V2 = 2
# ri_diskio_bytesread in struct rusage_info_v2: a 16-byte uuid, then 16
# uint64 fields before it (sys/resource.h).
RUSAGE_V2_SIZE = 16 + 18 * 8
RUSAGE_V2_BYTESREAD = 16 + 16 * 8

COUNTERS = {
    "num": "kern.num_vnodes",
    "free": "kern.free_vnodes",
    "max": "kern.maxvnodes",
    "files": "kern.num_files",
    "dead": "vfs.vnstats.num_dead_vnodes",
    "async": "vfs.vnstats.num_async_work_vnodes",
    "rapid": "vfs.vnstats.num_rapid_aging_vnodes",
    "busy": "vfs.vnstats.num_deallocable_busy_vnodes",
    "rage": "kern.rage_vnode",
    "newvn": "vfs.vnstats.num_newvnode_calls",
}

KERNEL_PREDICATE = (
    'process == "kernel" AND '
    '(eventMessage CONTAINS "table is full" OR eventMessage CONTAINS "numvnodes")'
)

# ------------------------------------------------------------ kernel reads


def sysctl_raw(name, size=64):
    buf = ctypes.create_string_buffer(size)
    length = ctypes.c_size_t(size)
    if LIBC.sysctlbyname(name.encode(), buf, ctypes.byref(length), None, 0) != 0:
        return None
    return buf.raw[: length.value]


def sysctl_int(name):
    """An int or long sysctl; the kernel says which by the length it returns.

    -1 when it does not exist, so a counter a later macOS drops reads as -1
    instead of stopping the recorder.
    """
    raw = sysctl_raw(name)
    if raw is None or len(raw) not in (4, 8):
        return -1
    return int.from_bytes(raw, sys.byteorder)


def boot_time():
    # struct timeval: a 64-bit tv_sec comes first.
    raw = sysctl_raw("kern.boottime") or b""
    return int.from_bytes(raw[:8], sys.byteorder)


def counters():
    return {key: sysctl_int(name) for key, name in COUNTERS.items()}


def all_pids():
    count = LIBC.proc_listallpids(None, 0)
    if count <= 0:
        return []
    pids = (ctypes.c_int * (count + 256))()
    count = LIBC.proc_listallpids(pids, ctypes.sizeof(pids))
    return [pid for pid in pids[: max(count, 0)] if pid > 0]


def fd_counts(pid):
    """(vnode fds, all fds), or None when the process is gone or off limits."""
    size = LIBC.proc_pidinfo(pid, PROC_PIDLISTFDS, 0, None, 0)
    if size <= 0:
        return None
    # Room for fds opened between the two calls.
    buf = ctypes.create_string_buffer(size + 64 * 8)
    size = LIBC.proc_pidinfo(pid, PROC_PIDLISTFDS, 0, buf, len(buf))
    if size <= 0:
        return None
    # struct proc_fdinfo { int32_t proc_fd; uint32_t proc_fdtype; }
    raw = buf.raw[:size]
    vnodes = sum(
        1
        for i in range(0, size, 8)
        if int.from_bytes(raw[i + 4 : i + 8], sys.byteorder) == PROX_FDTYPE_VNODE
    )
    return vnodes, size // 8


def bytes_read(pid):
    buf = ctypes.create_string_buffer(RUSAGE_V2_SIZE)
    if LIBC.proc_pid_rusage(pid, RUSAGE_INFO_V2, buf) != 0:
        return None
    raw = buf.raw[RUSAGE_V2_BYTESREAD : RUSAGE_V2_BYTESREAD + 8]
    return int.from_bytes(raw, sys.byteorder)


def proc_path(pid):
    buf = ctypes.create_string_buffer(PROC_PIDPATHINFO_MAXSIZE)
    if LIBC.proc_pidpath(pid, buf, len(buf)) <= 0:
        buf = ctypes.create_string_buffer(256)
        if LIBC.proc_name(pid, buf, len(buf)) <= 0:
            return "?"
    return buf.value.decode(errors="replace")


# ------------------------------------------------------------------ output


class Recorder:
    def __init__(self, args):
        self.args = args
        self.boot = boot_time()
        os.makedirs(args.dir, exist_ok=True)
        self.prefix = os.path.join(
            args.dir, datetime.fromtimestamp(self.boot).strftime("%Y%m%d-%H%M%S")
        )
        self.out = open(self.prefix + ".log", "a", buffering=1)
        self.last_read = {}
        self.last_read_at = None
        self.children = []
        self.episodes = 0
        self.episode_start = None
        self.calm_since = None

    def write(self, line):
        self.out.write(f"{datetime.now().isoformat(timespec='seconds')} {line}\n")

    def sample(self, c, rate):
        in_use = c["num"] - c["free"]
        share = in_use / c["max"]
        self.write(
            f"up={int(time.time()) - self.boot} inuse={in_use} ({share:.1%}) "
            f"num={c['num']} free={c['free']} max={c['max']} files={c['files']} "
            f"dead={c['dead']} async={c['async']} rapid={c['rapid']} "
            f"busy={c['busy']} rage={c['rage']} newvn/s={rate:.0f}"
        )
        return share

    def table(self, why):
        """Top processes by vnode fds and by disk reads since the last table."""
        now = time.monotonic()
        rows = []
        for pid in all_pids():
            fds = fd_counts(pid)
            if fds is None:
                continue
            read = bytes_read(pid) or 0
            delta = read - self.last_read.get(pid, read)
            self.last_read[pid] = read
            rows.append((pid, fds[0], fds[1], delta))
        span = now - self.last_read_at if self.last_read_at else 0
        self.last_read_at = now
        self.write(f"TABLE {why}: {len(rows)} processes readable")
        top_fds = sorted(rows, key=lambda r: r[1], reverse=True)[: self.args.top]
        reading = [r for r in rows if r[3] > 0]
        top_read = sorted(reading, key=lambda r: r[3], reverse=True)[: self.args.top]
        for title, picked in (("by vnode fds", top_fds), ("by disk reads", top_read)):
            self.out.write(f"  {title} (reads over {span:.0f} s):\n")
            for pid, vnodes, total, delta in picked:
                self.out.write(
                    f"  {pid:>7} vnode_fds={vnodes:>7} fds={total:>7} "
                    f"read_MB={delta / 1e6:>9.1f} {proc_path(pid)}\n"
                )

    def spawn(self, name, argv):
        """Start a capture; "{path}" in argv is its output file, else stdout is."""
        path = f"{self.prefix}-ep{self.episodes}-{name}.txt"
        argv = [arg.replace("{path}", path) for arg in argv]
        try:
            if any(arg == path for arg in argv):
                sink = open(path + ".stderr", "w")
            else:
                sink = open(path, "w")
            child = subprocess.Popen(argv, stdout=sink, stderr=subprocess.STDOUT)
            sink.close()
            self.children.append((child, time.monotonic()))
            self.write(f"started {name} (pid {child.pid}) -> {path}")
        except OSError as error:
            self.write(f"could not start {name}: {error}")

    def reap(self):
        alive = []
        for child, started in self.children:
            if child.poll() is not None:
                continue
            if time.monotonic() - started > self.args.child_timeout:
                child.kill()
                child.wait()
                self.write(f"killed pid {child.pid} after {self.args.child_timeout} s")
                continue
            alive.append((child, started))
        self.children = alive

    def episode(self, share, now):
        """Track one stretch over the threshold, with captures at its start."""
        threshold = self.args.threshold
        if self.episode_start is None:
            if share < threshold:
                return
            self.episodes += 1
            self.episode_start = now
            self.calm_since = None
            self.write(f"EPISODE {self.episodes} START: {share:.1%} of vnodes in use")
            self.table(f"episode {self.episodes} start")
            if self.episodes <= self.args.max_episodes:
                self.spawn("lsof", ["/usr/sbin/lsof", "-n", "-P", "-w"])
                self.spawn(
                    "spindump",
                    ["/usr/sbin/spindump", "-noTarget", "3", "10", "-o", "{path}"],
                )
            return
        if share >= threshold * 0.8:
            self.calm_since = None
            return
        self.calm_since = self.calm_since or now
        if now - self.calm_since < 30:
            return
        self.write(
            f"EPISODE {self.episodes} END after {now - self.episode_start:.0f} s"
        )
        if self.episodes <= self.args.max_episodes:
            start = datetime.fromtimestamp(self.episode_start - 120)
            self.spawn(
                "kernel-log",
                [
                    "/usr/bin/log",
                    "show",
                    "--start",
                    start.strftime("%Y-%m-%d %H:%M:%S"),
                    "--predicate",
                    KERNEL_PREDICATE,
                    "--style",
                    "compact",
                ],
            )
        self.episode_start = None

    def prune(self):
        """Keep the files of the newest --keep-boots boots."""
        stamps = sorted(
            {
                os.path.basename(p)[:15]
                for p in glob.glob(os.path.join(self.args.dir, "2*"))
            }
        )
        for stamp in stamps[: -self.args.keep_boots]:
            for path in glob.glob(os.path.join(self.args.dir, stamp + "*")):
                os.remove(path)

    def run(self):
        self.prune()
        c = counters()
        if min(c["num"], c["free"], c["max"]) < 0 or self.boot <= 0:
            sys.exit(
                "vnode-watch: kern.num_vnodes, free_vnodes, maxvnodes or boottime missing"
            )
        self.write(
            f"vnode-watch start pid={os.getpid()} "
            f"boot={datetime.fromtimestamp(self.boot).isoformat()} "
            f"maxvnodes={c['max']} maxfiles={sysctl_int('kern.maxfiles')} "
            f"maxfilesperproc={sysctl_int('kern.maxfilesperproc')} "
            f"threshold={self.args.threshold:.0%}"
        )
        # Warm-up: run every path once, so none has to page in later.
        self.table("start")
        last_newvn, last_at = c["newvn"], time.time()
        last_written = last_table = 0.0
        while True:
            time.sleep(1)
            now = time.time()
            c = counters()
            rate = (c["newvn"] - last_newvn) / max(now - last_at, 1e-3)
            last_newvn, last_at = c["newvn"], now
            share = (c["num"] - c["free"]) / c["max"]
            in_window = now - self.boot < self.args.boot_window
            busy = share >= self.args.threshold * 0.8 or self.episode_start
            if in_window or busy or now - last_written >= 60:
                self.sample(c, rate)
                last_written = now
            self.episode(share, now)
            period = 5 if self.episode_start else 30 if in_window else None
            if period and now - last_table >= period:
                self.table("episode" if self.episode_start else "boot window")
                last_table = now
            self.reap()


def main():
    parser = argparse.ArgumentParser(
        description="Record what fills the kernel's vnode table."
    )
    parser.add_argument("--dir", default="/var/log/vnode-watch")
    parser.add_argument(
        "--threshold",
        type=float,
        default=0.5,
        help="share of the vnode table in use that starts an episode",
    )
    parser.add_argument(
        "--boot-window",
        type=int,
        default=900,
        help="seconds after boot to write every sample",
    )
    parser.add_argument("--top", type=int, default=15)
    parser.add_argument(
        "--max-episodes",
        type=int,
        default=3,
        help="episodes per boot that get lsof, spindump and the kernel log",
    )
    parser.add_argument("--child-timeout", type=int, default=180)
    parser.add_argument("--keep-boots", type=int, default=10)
    Recorder(parser.parse_args()).run()


if __name__ == "__main__":
    main()

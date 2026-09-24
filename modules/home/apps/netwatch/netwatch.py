#!/usr/bin/env python3
"""netwatch — locate where a brief network drop happens, by layer.

Probes three points continuously and records every outage with its exact
start, end and duration:

  air   ICMP to the default gateway    -> the local hop + the router itself
  dns   DNS query to the LAN resolver  -> the LAN path + your own resolver
  wan   ICMP to a public address       -> everything beyond the router

A drop that hits all three at once is the link or the router. A drop that
spares "air" but kills "wan" is upstream. A drop that only hits "dns" is the
resolver, not the network. Running this on a wired host and a wireless one at
the same time is what separates "the router/mains died" from "the radio
stalled" — that comparison is the whole point of the tool.

It also watches for the reports macOS writes when configd, which owns routes,
DNS and interface state, hangs or crashes, and raises a notification.

No privileges needed: Darwin allows unprivileged ICMP through
SOCK_DGRAM/IPPROTO_ICMP, provided we compute the checksum ourselves.
"""

import argparse
import csv
import glob
import os
import random
import re
import signal
import socket
import struct
import subprocess
import sys
import threading
import time
from collections import defaultdict, deque
from datetime import date, datetime, timedelta

# --------------------------------------------------------------- probes


def _cksum(b):
    if len(b) % 2:
        b += b"\x00"
    s = sum(struct.unpack("!%dH" % (len(b) // 2), b))
    while s >> 16:
        s = (s & 0xFFFF) + (s >> 16)
    return ~s & 0xFFFF


def icmp_echo(ident, seq, body=b"netwatch"):
    hdr = struct.pack("!BBHHH", 8, 0, 0, ident, seq)
    return struct.pack("!BBHHH", 8, 0, _cksum(hdr + body), ident, seq) + body


def icmp_reply(data):
    """(identifier, sequence) from an echo reply, or None if it is not one."""
    if not data:
        return None
    ihl = (data[0] & 0x0F) * 4 if (data[0] >> 4) == 4 else 0
    icmp = data[ihl:]
    if len(icmp) < 8 or icmp[0] != 0:
        return None
    return struct.unpack("!HH", icmp[4:8])


class IcmpProbe:
    """Echo request to a host.

    Four Darwin quirks, all found the hard way.

    1. The kernel does NOT fill in the checksum for SOCK_DGRAM sockets. An
       unchecksummed packet is dropped silently and looks exactly like 100%
       loss.
    2. Replies arrive with the full IP header still attached, so the ICMP
       header starts at IHL*4.
    3. The socket must be kept OPEN across probes. Opening a fresh one per
       probe costs hundreds of milliseconds under load, and that shows up as
       network latency that is not there.
    4. These sockets are PROMISCUOUS. Every SOCK_DGRAM ICMP socket sees every
       echo reply, and setting a distinct identifier per socket does not
       change that — measured, not assumed. So a reply must be matched on its
       SOURCE ADDRESS as well as on identifier and sequence.

    Quirk 4 is not academic. With two probes matching on sequence alone, and
    both counters starting at 1, each happily accepted the other's replies and
    reported the other's latency; when the counters drifted apart one probe
    starved and reported a 98-second outage that never happened, while its
    own traffic was flowing perfectly the whole time.
    """

    kind = "icmp"

    def __init__(self, host):
        self.host = host
        self.seq = 0
        self.sock = None
        # Non-zero and per-instance. Not sufficient on its own (see quirk 4),
        # but it makes a stray match that much less likely.
        self.ident = random.randint(1, 0xFFFF)

    def _socket(self):
        if self.sock is None:
            self.sock = socket.socket(
                socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_ICMP
            )
        return self.sock

    def _drop(self):
        if self.sock is not None:
            try:
                self.sock.close()
            finally:
                self.sock = None

    def probe(self, timeout):
        self.seq = (self.seq + 1) & 0xFFFF
        seq = self.seq
        try:
            s = self._socket()
            t0 = time.monotonic()
            deadline = t0 + timeout
            s.settimeout(timeout)
            s.sendto(icmp_echo(self.ident, seq), (self.host, 0))
            while True:
                left = deadline - time.monotonic()
                if left <= 0:
                    return None, "timeout"
                s.settimeout(left)
                data, addr = s.recvfrom(2048)
                got = icmp_reply(data)
                # Skip anything that is not this probe's own reply: another
                # target's traffic, or a reply to an earlier already-timed-out
                # probe of ours. Crediting either one would be a fabrication.
                if addr[0] == self.host and got == (self.ident, seq):
                    return (time.monotonic() - t0) * 1000.0, "ok"
        except socket.timeout:
            return None, "timeout"
        except OSError as e:
            self._drop()
            return None, "err:%s" % (e.errno,)


class DnsProbe:
    """A real DNS query.

    Deliberately asks for a FIXED name so the answer is served from cache:
    this measures whether the resolver is answering at all, not how fast the
    internet is. Pick a random name here and you would be timing recursion.
    """

    kind = "dns"

    def __init__(self, host, name="example.com", port=53):
        self.host, self.name, self.port = host, name, port

    def probe(self, timeout):
        tid = random.randint(0, 0xFFFF)
        labels = b"".join(bytes([len(x)]) + x.encode() for x in self.name.split("."))
        pkt = (
            struct.pack("!HHHHHH", tid, 0x0100, 1, 0, 0, 0)
            + labels
            + b"\x00"
            + struct.pack("!HH", 1, 1)
        )
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            t0 = time.monotonic()
            deadline = t0 + timeout
            s.settimeout(timeout)
            s.sendto(pkt, (self.host, self.port))
            while True:
                left = deadline - time.monotonic()
                if left <= 0:
                    return None, "timeout"
                s.settimeout(left)
                data, _ = s.recvfrom(2048)
                if len(data) >= 2 and struct.unpack("!H", data[:2])[0] == tid:
                    return (time.monotonic() - t0) * 1000.0, "ok"
        except socket.timeout:
            return None, "timeout"
        except OSError as e:
            return None, "err:%s" % (e.errno,)
        finally:
            s.close()


# --------------------------------------------------------------- discovery


def primary_route():
    """Gateway and interface of the default route.

    Must come from the route table, not from "the Wi-Fi port": on the mini the
    primary interface is wired en0 and Wi-Fi is en1, so asking networksetup for
    the Wi-Fi device would probe the wrong path entirely.
    """
    out = subprocess.run(
        ["route", "-n", "get", "default"], capture_output=True, text=True
    ).stdout
    gw = re.search(r"gateway:\s*(\S+)", out)
    iface = re.search(r"interface:\s*(\S+)", out)
    return (gw.group(1) if gw else None, iface.group(1) if iface else None)


def lan_resolvers(iface):
    out = subprocess.run(
        ["ipconfig", "getpacket", iface], capture_output=True, text=True
    ).stdout
    m = re.search(r"domain_name_server \(ip_mult\): \{([^}]*)\}", out)
    if m:
        return [x.strip() for x in m.group(1).split(",") if x.strip()]
    # A statically configured or PPP interface has no DHCP packet to read.
    out = subprocess.run(["scutil", "--dns"], capture_output=True, text=True).stdout
    return re.findall(r"nameserver\[\d+\] : (\S+)", out)[:1]


def link_snapshot(iface):
    """Interface state at the moment of a drop.

    Returns only up/down, and deliberately so. SSID and BSSID would be far
    more useful — a BSSID change is a roam, which is what most of these drops
    turn out to be — but macOS gates both behind Location Services and hands
    an unauthorised caller "<redacted>" from `ipconfig getsummary`, while
    `networksetup -getairportnetwork` answers "You are not associated with an
    AirPort network" on a link that is plainly up. A launchd agent has no such
    authorisation, so recording either one would mean writing down a value
    that is always empty and sometimes actively misleading.

    Interface status alone has already earned its place: the false outage this
    tool recorded on its first run read "active", the real one read
    "inactive".
    """
    st = subprocess.run(["ifconfig", iface], capture_output=True, text=True).stdout
    return "active" if re.search(r"status:\s*active", st) else "inactive"


# --------------------------------------------------------------- configd


REPORTS_DIR = "/Library/Logs/DiagnosticReports"
CONFIGD_POLL_S = 15.0

# terminal-notifier rather than osascript: macOS ties notification permission
# to the delivering app, and both Macs have already granted it to this
# Homebrew copy (see homebrew.nix). An absolute path, because launchd's default
# PATH does not include /opt/homebrew/bin.
NOTIFIER = "/opt/homebrew/bin/terminal-notifier"


def notify(title, message):
    """Post a desktop notification, and never fail the caller over it.

    The log line is the record. This is only the tap on the shoulder.
    """
    try:
        subprocess.run(
            [NOTIFIER, "-title", title, "-message", message, "-sound", "default"],
            capture_output=True,
            timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        pass


def report_kind(name):
    """'crash' for an .ips, else the kind macOS names in the file's suffix.

    configd_2026-09-24-110938_brett-m1-mbp.userspace_watchdog_timeout.spin
    reads as "userspace watchdog timeout".
    """
    if name.endswith(".ips"):
        return "crash"
    m = re.search(r"\.([a-z_]+)\.(?:spin|diag)$", name)
    return m.group(1).replace("_", " ") if m else "report"


class ConfigdWatch:
    """Announce every new report macOS writes about configd.

    configd owns routes, DNS and interface state. On 24 Sep 2026 its
    IPMonitorQueue blocked in the kernel two minutes into a 3.5-minute outage
    in which the Mac stopped transmitting while its radio stayed healthy. The
    only trace was a userspace_watchdog_timeout report and two crash reports,
    found by hand afterwards, so this goes looking for them.

    It is an after-the-fact signal: that report was written two minutes after
    traffic stopped. The .ips crash reports also get moved away within minutes
    of being written, which is why this polls rather than waiting to be asked.

    The newest report seen is kept on disk. A hang bad enough to need a
    restart writes its reports before the restart, and they should still be
    announced when the agent comes back.
    """

    PATTERN = re.compile(r"^configd[-_.]")

    def __init__(self, outdir, reports_dir, say):
        self.reports_dir, self.say = reports_dir, say
        self.state = os.path.join(outdir, "configd-seen")
        try:
            with open(self.state) as f:
                self.seen = float(f.read())
        except (OSError, ValueError):
            # First run: reports written before netwatch looked are history,
            # not news.
            self.seen = time.time()
            self._save()

    def _save(self):
        with open(self.state, "w") as f:
            f.write("%.6f\n" % self.seen)

    def check(self):
        try:
            names = os.listdir(self.reports_dir)
        except OSError:
            return
        new = []
        for name in names:
            if not self.PATTERN.match(name):
                continue
            try:
                st = os.stat(os.path.join(self.reports_dir, name))
            except OSError:
                continue  # moved away between listdir and stat
            # Birth, not modification: a report touched again later is not a
            # new hang.
            born = getattr(st, "st_birthtime", st.st_mtime)
            if born > self.seen:
                new.append((born, name))
        if not new:
            return
        new.sort()
        for born, name in new:
            self.say(
                "\033[35m%s  CONFIGD  %s  %s/%s\033[0m"
                % (
                    datetime.fromtimestamp(born).strftime("%H:%M:%S"),
                    report_kind(name),
                    self.reports_dir,
                    name,
                ),
                always=True,
            )
        # One notification per sweep: a single hang writes several reports
        # within a minute, and one alert says all that needs saying.
        born, name = new[0]
        more = " (+%d more)" % (len(new) - 1) if len(new) > 1 else ""
        notify(
            "netwatch: configd %s" % report_kind(name),
            "%s%s. Networking may stall. See /tmp/netwatch.log."
            % (datetime.fromtimestamp(born).strftime("%H:%M:%S"), more),
        )
        self.seen = new[-1][0]
        self._save()


# --------------------------------------------------------------- watcher


EVENT_COLUMNS = [
    "start",
    "end",
    "duration_s",
    "target",
    "concurrent",
    "verdict",
    "ended",
    "link_status",
]


def classify(target, concurrent, n_targets):
    """What a single target going quiet actually means.

    This is the judgement the tool exists to make, and getting it wrong is
    worse than not making it. A layer that goes silent while the layers BEHIND
    it keep answering has not lost connectivity — traffic to the WAN and to
    the LAN resolver both traverse the gateway, so if those are flowing, the
    gateway is up and forwarding whatever the ICMP probe thinks.
    """
    if len(concurrent) >= n_targets - 1:
        return "outage"  # every layer went quiet: the link or the router
    if not concurrent:
        return "probe-only"  # nothing else noticed; suspect the probe itself
    return "partial"  # upstream of whatever still answered


class Watcher:
    def __init__(
        self, targets, outdir, interval, timeout, trip, iface, quiet, retain, reports_dir
    ):
        self.targets = targets
        self.interval, self.timeout, self.trip = interval, timeout, trip
        self.iface, self.quiet, self.retain = iface, quiet, retain
        self.lock = threading.Lock()
        self.bucket = defaultdict(list)
        self.recent = {n: deque(maxlen=trip) for n in targets}
        self.down_since = {}
        self.pending = {}
        self.stop = threading.Event()
        self.outdir = outdir
        os.makedirs(outdir, exist_ok=True)
        self.day = None
        self.sf = self.sw = None
        self.ef = self._open_events(os.path.join(outdir, "events.csv"))
        self.ew = csv.writer(self.ef)
        if self.ef.tell() == 0:
            self.ew.writerow(EVENT_COLUMNS)
            # Flush now. Otherwise the header sits in the buffer until the
            # first outage, the file reads as zero bytes for however long the
            # link behaves, and a SIGKILL loses it entirely.
            self.ef.flush()
        self._roll()
        self.configd = ConfigdWatch(outdir, reports_dir, self._say)

    # ---------------- files

    @staticmethod
    def _open_events(path):
        """Open events.csv, moving aside any file written to the old schema.

        Appending wider rows to a narrower file produces a CSV that every
        reader mis-parses, so an old file is preserved under its own name
        rather than corrupted or silently deleted.
        """
        if os.path.exists(path) and os.path.getsize(path) > 0:
            with open(path, newline="") as f:
                header = next(csv.reader(f), [])
            if header != EVENT_COLUMNS:
                legacy = path.replace(".csv", ".v1.csv")
                os.rename(path, legacy)
                sys.stderr.write("netwatch: old events.csv moved to %s\n" % legacy)
        return open(path, "a", newline="")

    def _roll(self):
        """One samples file per day, and prune beyond the retention window.

        At 4 Hz this writes roughly 15 MB a day. Left unbounded on a machine
        that runs it for months that is the kind of thing you discover when a
        disk fills, so retention is part of the design, not an afterthought.
        """
        today = date.today()
        if today == self.day:
            return
        if self.sf:
            self.sf.flush()
            self.sf.close()
        self.day = today
        path = os.path.join(self.outdir, "samples-%s.csv" % today.isoformat())
        self.sf = open(path, "a", newline="")
        self.sw = csv.writer(self.sf)
        if self.sf.tell() == 0:
            self.sw.writerow(
                ["ts", "target", "sent", "recv", "loss_pct", "min_ms", "avg_ms", "max_ms"]
            )
        cutoff = today - timedelta(days=self.retain)
        for old in glob.glob(os.path.join(self.outdir, "samples-*.csv")):
            m = re.search(r"samples-(\d{4}-\d{2}-\d{2})\.csv$", old)
            if m and date.fromisoformat(m.group(1)) < cutoff:
                os.remove(old)

    # ---------------- probing

    def _run_target(self, name, probe):
        while not self.stop.is_set():
            t0 = time.monotonic()
            rtt, status = probe.probe(self.timeout)
            with self.lock:
                self.bucket[name].append((status, rtt))
                self.recent[name].append(status == "ok")
                self._edge(name)
            slack = self.interval - (time.monotonic() - t0)
            if slack > 0:
                self.stop.wait(slack)

    def _edge(self, name):
        """Trip after N consecutive failures, recover on the first success.

        Called with the lock held.
        """
        r = self.recent[name]
        if r and not r[-1]:
            # Credit this failure to every event currently open on another
            # target, which is what lets a verdict be reached at event end.
            for other, info in self.pending.items():
                if other != name:
                    info["with"].add(name)
        if name not in self.down_since:
            if len(r) == r.maxlen and not any(r):
                # Back-date the start to the first failed probe, not the Nth.
                began = time.time() - self.trip * self.interval
                self.down_since[name] = (time.monotonic(), began)
                status = link_snapshot(self.iface)
                # Seed with whatever else is already failing, so a target that
                # trips a moment later than its neighbours is still credited.
                self.pending[name] = {
                    "status": status,
                    "with": {o for o in self.down_since if o != name},
                }
                self._say(
                    "\033[31m%s  DOWN  %-4s  (link=%s)\033[0m"
                    % (datetime.now().strftime("%H:%M:%S"), name, status),
                    always=True,
                )
        elif r and r[-1]:
            t_mono, t_wall = self.down_since.pop(name)
            dur = (time.monotonic() - t_mono) + self.trip * self.interval
            self._write_event(name, t_wall, dur, "recovered")

    def _write_event(self, name, t_wall, dur, ended):
        info = self.pending.pop(name, {"status": "?", "with": set()})
        others = sorted(info["with"])
        verdict = classify(name, others, len(self.targets))
        self.ew.writerow(
            [
                datetime.fromtimestamp(t_wall).isoformat(timespec="milliseconds"),
                datetime.now().isoformat(timespec="milliseconds"),
                "%.2f" % dur,
                name,
                "+".join(others) if others else "-",
                verdict,
                ended,
                info["status"],
            ]
        )
        self.ef.flush()
        colour = "\033[32m" if ended == "recovered" else "\033[33m"
        self._say(
            "%s%s  %-9s %-4s  after %.1fs  [%s, with %s]\033[0m"
            % (
                colour,
                datetime.now().strftime("%H:%M:%S"),
                "UP" if ended == "recovered" else "TRUNCATED",
                name,
                dur,
                verdict,
                "+".join(others) if others else "nothing else",
            ),
            always=True,
        )

    def _flush_open_events(self):
        """Record outages still in progress when we stop.

        An agent restart, or a laptop going to sleep, lands squarely in the
        middle of the longest and most interesting drops. Discarding those
        would bias the record towards short ones.
        """
        with self.lock:
            for name in list(self.down_since):
                t_mono, t_wall = self.down_since.pop(name)
                dur = (time.monotonic() - t_mono) + self.trip * self.interval
                self._write_event(name, t_wall, dur, "truncated")

    def _say(self, msg, always=False):
        if always or not self.quiet:
            sys.stderr.write(msg + "\n")
            sys.stderr.flush()

    def _aggregate(self):
        while not self.stop.is_set():
            self.stop.wait(1.0)
            self._roll()
            ts = datetime.now().isoformat(timespec="seconds")
            with self.lock:
                bucket, self.bucket = self.bucket, defaultdict(list)
            line = []
            for name in self.targets:
                rows = bucket.get(name, [])
                if not rows:
                    continue
                rtts = [r for s, r in rows if s == "ok" and r is not None]
                self.sw.writerow(
                    [
                        ts,
                        name,
                        len(rows),
                        len(rtts),
                        "%.0f" % (100.0 * (len(rows) - len(rtts)) / len(rows)),
                        "%.2f" % min(rtts) if rtts else "",
                        "%.2f" % (sum(rtts) / len(rtts)) if rtts else "",
                        "%.2f" % max(rtts) if rtts else "",
                    ]
                )
                line.append(
                    "%s %s"
                    % (
                        name,
                        "%5.1fms" % (sum(rtts) / len(rtts))
                        if rtts
                        else "\033[31m LOSS \033[0m",
                    )
                )
            self.sf.flush()
            if line and not self.quiet:
                sys.stdout.write(
                    "\r%s  %s   " % (datetime.now().strftime("%H:%M:%S"), "  ".join(line))
                )
                sys.stdout.flush()

    def _watch_configd(self):
        # Its own thread: the notifier is a subprocess that can take seconds,
        # and the aggregator must not miss a second of samples waiting on it.
        while not self.stop.wait(CONFIGD_POLL_S):
            self.configd.check()

    def run(self):
        probers = [
            threading.Thread(target=self._run_target, args=(n, p), daemon=True)
            for n, p in self.targets.items()
        ]
        agg = threading.Thread(target=self._aggregate, daemon=True)
        cfg = threading.Thread(target=self._watch_configd, daemon=True)
        for t in probers + [agg, cfg]:
            t.start()
        signal.signal(signal.SIGINT, lambda *_: self.stop.set())
        signal.signal(signal.SIGTERM, lambda *_: self.stop.set())
        while not self.stop.wait(1.0):
            pass
        # Teardown has to survive a second Ctrl-C, or the CSVs are left
        # unflushed and the last minutes of a capture are lost.
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        # Join the aggregator BEFORE closing its files. Closing underneath a
        # thread that is mid-writerow raises on a file it no longer owns, and
        # launchd would log that traceback on every single stop.
        agg.join(timeout=3.0)
        self._flush_open_events()
        for f in (self.sf, self.ef):
            try:
                f.flush()
                f.close()
            except Exception:
                pass
        self._say("\nwrote %s" % self.outdir, always=True)


# --------------------------------------------------------------- burst


def burst(host, seconds, interval):
    """Short, high-rate profile of one hop.

    Sample slower than ~100 ms and a periodic stall aliases into a completely
    fictitious slow cycle — a 0.46 s stall period reads as a ~10 s one at
    0.25 s spacing. That is why this mode exists separately from the daemon,
    which samples coarsely on purpose.

    Sending and receiving are decoupled, as ping does it. A blocking
    send-then-wait loop cannot hold its cadence once replies start arriving
    late: it stretches the send interval by exactly the delay it is trying to
    measure, and reports the sum as latency.
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_ICMP)
    ident = random.randint(1, 0xFFFF)
    sent, rtt, lock, done = {}, {}, threading.Lock(), threading.Event()

    def receiver():
        sock.settimeout(0.25)
        while not done.is_set():
            try:
                data, addr = sock.recvfrom(2048)
            except socket.timeout:
                continue
            except OSError:
                return
            now = time.monotonic()
            got = icmp_reply(data)
            # Same promiscuity problem as IcmpProbe: the agent is probably
            # running while this burst is, and its replies land here too.
            if addr[0] != host or not got or got[0] != ident:
                continue
            seq = got[1]
            with lock:
                if seq in sent and seq not in rtt:
                    rtt[seq] = (now - sent[seq]) * 1000.0

    rx = threading.Thread(target=receiver, daemon=True)
    rx.start()

    t_start = next_send = time.monotonic()
    seq = 0
    while time.monotonic() < t_start + seconds:
        seq = (seq + 1) & 0xFFFF
        with lock:
            sent[seq] = time.monotonic()
        try:
            sock.sendto(icmp_echo(ident, seq), (host, 0))
        except OSError:
            pass
        # Absolute schedule, so a slow send does not drift the cadence.
        next_send += interval
        slack = next_send - time.monotonic()
        if slack > 0:
            time.sleep(slack)
        else:
            next_send = time.monotonic()
    time.sleep(1.0)  # let the stragglers land before we judge them lost
    done.set()
    rx.join(timeout=1.0)
    sock.close()

    with lock:
        samples = [(sent[s], rtt.get(s)) for s in sorted(sent, key=lambda k: sent[k])]
    good = [(t, v) for t, v in samples if v is not None]
    if not good:
        print("no replies from %s" % host)
        return
    vals = sorted(v for _, v in good)
    n = len(vals)

    def q(p):
        return vals[min(int(n * p), n - 1)]

    print("\n%s — %d probes over %.0fs at %.0f Hz, %.1f%% loss"
          % (host, len(samples), seconds, 1.0 / interval,
             100.0 * (len(samples) - n) / len(samples)))
    print("  floor(p10) %7.1f ms   <- what the link is actually capable of" % q(0.10))
    for label, p in (("median", 0.5), ("p90", 0.9), ("p99", 0.99)):
        print("  %-10s %7.1f ms" % (label, q(p)))
    print("  max        %7.1f ms" % vals[-1])

    # Threshold off the FLOOR, never the median. Keying it to the median
    # breaks in precisely the case that matters: when the link is stalled more
    # often than not, the median is itself a stall, the threshold floats up
    # above the damage, and the tool cheerfully reports a clean hop.
    thr = max(q(0.10) * 3, q(0.10) + 5)
    bursts, cur = [], None
    t0 = good[0][0]
    for t, v in good:
        if v > thr:
            cur = [t, t, v] if cur is None else [cur[0], t, max(cur[2], v)]
        elif cur:
            bursts.append(cur)
            cur = None
    if cur:
        bursts.append(cur)
    if not bursts:
        print("\n  no stalls above %.1f ms — this hop is clean" % thr)
        return

    # State the damage in terms of the floor, so a uniformly bad link cannot
    # read as a good one.
    inflated = sum(1 for _, v in good if v > thr)
    print("\n  %d of %d replies (%.1f%%) came back above %.1f ms, against a %.1f ms floor"
          % (inflated, n, 100.0 * inflated / n, thr, q(0.10)))

    print("\n  %d stalls above %.1f ms" % (len(bursts), thr))
    # A single-sample stall is one probe interval wide, not zero.
    widths = sorted((b[1] - b[0]) * 1000 + interval * 1000 for b in bursts)
    print("  median stall width %.0f ms, worst peak %.1f ms"
          % (widths[len(widths) // 2], max(b[2] for b in bursts)))
    gaps = sorted(b2[0] - b1[0] for b1, b2 in zip(bursts, bursts[1:]))
    if gaps:
        med = gaps[len(gaps) // 2]
        print("  median gap between stalls %.2f s" % med)
        if med and (gaps[-1] - gaps[0]) / med < 0.5:
            print("\n  -> TIGHTLY PERIODIC. Something is time-slicing this radio.")
            print("     On macOS the usual answer is AWDL (AirDrop/Universal Control/")
            print("     Sidecar sharing the chip). Check it with:")
            print("       ifconfig awdl0")
            print("       log show --last 5m --predicate 'eventMessage CONTAINS \"LQM-WiFi:AWDL\"'")
            print("     A DutyCycle line there tells you what share of the radio it took.")
    print("\n  first stalls (seconds from start):")
    for b in bursts[:10]:
        print("    %7.2f  width %4.0f ms  peak %6.1f ms"
              % (b[0] - t0, (b[1] - b[0]) * 1000 + interval * 1000, b[2]))


# --------------------------------------------------------------- report


def _load(outdir, pattern):
    rows = []
    for p in sorted(glob.glob(os.path.join(outdir, pattern))):
        try:
            rows += list(csv.DictReader(open(p)))
        except FileNotFoundError:
            pass
    return rows


def coverage(outdir):
    """How much of the elapsed time was actually observed.

    A laptop suspends this agent whenever it sleeps, so a night of Power Nap
    leaves the record full of 15-minute holes. Reporting "no outages" without
    saying that would be the tool lying by omission: it cannot see a drop that
    happened while it was frozen.
    """
    rows = [r for r in _load(outdir, "samples-*.csv") if r["target"] == "air"]
    if not rows:
        return
    ts = sorted(datetime.fromisoformat(r["ts"]) for r in rows)
    span = (ts[-1] - ts[0]).total_seconds()
    if span <= 0:
        return
    gaps = [(a, (b - a).total_seconds()) for a, b in zip(ts, ts[1:])
            if (b - a).total_seconds() > 30]
    print("\nobserved %s -> %s" % (ts[0].strftime("%d %b %H:%M"),
                                   ts[-1].strftime("%d %b %H:%M")))
    print("  %.1f h of %.1f h elapsed = %.0f%% coverage, %d gaps over 30s"
          % (len(ts) / 3600.0, span / 3600.0, 100.0 * len(ts) / span, len(gaps)))
    if gaps:
        lost = sum(g for _, g in gaps) / 3600.0
        print("  %.1f h unobserved — most likely sleep; a drop in there is invisible"
              % lost)


def report(outdir, stall_ms):
    coverage(outdir)
    events = _load(outdir, "events.csv")
    if not events:
        print("\nno events recorded yet")
    if events:
        by_verdict = defaultdict(list)
        for r in events:
            by_verdict[r.get("verdict", "?")].append(r)
        print("\n%d events recorded" % len(events))
        for v, label in (
            ("outage", "every layer down — the link or the router"),
            ("partial", "some layers still answering — upstream of those"),
            ("probe-only", "only this target went quiet — suspect the probe, not the network"),
            ("?", "recorded before verdicts existed — unclassified"),
        ):
            if by_verdict.get(v):
                print("  %-11s %4d   %s" % (v, len(by_verdict[v]), label))

        # Only real outages belong in the histograms below. Mixing the others
        # in is how a tooling artefact gets mistaken for a network pattern.
        real = by_verdict.get("outage", []) + by_verdict.get("?", [])
        if not real:
            print("\nno genuine outages to analyse")
            events = []
        else:
            events = real
            by_target = defaultdict(list)
            for r in events:
                by_target[r["target"]].append(r)
            print("\n%-6s %6s %9s %9s %9s" % ("target", "count", "median", "p90", "max"))
            for name, rs in sorted(by_target.items()):
                d = sorted(float(r["duration_s"]) for r in rs)
                print("%-6s %6d %8.1fs %8.1fs %8.1fs"
                      % (name, len(d), d[len(d) // 2], d[int(len(d) * 0.9)], d[-1]))

    if events:
        print("\nminute past the hour — a spike here means something SCHEDULED,")
        print("which is neither a compressor cycling nor a router dying of old age:")
        mins = defaultdict(int)
        for r in events:
            mins[datetime.fromisoformat(r["start"]).minute] += 1
        for m in range(0, 60, 5):
            n = sum(mins.get(x, 0) for x in range(m, m + 5))
            print("  :%02d-:%02d %s %d" % (m, m + 4, "#" * n, n))

        print("\nhour of day — correlate this with when the dehumidifier runs:")
        hours = defaultdict(int)
        for r in events:
            hours[datetime.fromisoformat(r["start"]).hour] += 1
        for h in range(24):
            print("  %02d:00 %s %d" % (h, "#" * hours.get(h, 0), hours.get(h, 0)))

    rows = [r for r in _load(outdir, "samples-*.csv") if r["target"] == "air" and r["max_ms"]]
    if not rows:
        return
    mx = sorted(float(r["max_ms"]) for r in rows)
    n = len(mx)
    print("\nair hop — worst RTT in each of %d sampled seconds:" % n)
    for label, p in (("floor(p10)", 0.10), ("median", 0.5), ("p90", 0.9), ("p99", 0.99)):
        print("  %-10s %7.1f ms" % (label, mx[min(int(n * p), n - 1)]))
    print("  %-10s %7.1f ms" % ("max", mx[-1]))
    spiky = [r for r in rows if float(r["max_ms"]) > stall_ms]
    print("  %d of %d seconds (%.1f%%) exceeded %d ms"
          % (len(spiky), n, 100.0 * len(spiky) / n, stall_ms))
    print("\n  Stalls like these never trip the outage detector above, but they are")
    print("  what you feel in a call. Profile one with:  netwatch --burst 30")


# --------------------------------------------------------------- main


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--outdir", default=os.path.expanduser("~/.local/share/netwatch"))
    ap.add_argument("--interval", type=float, default=0.25, help="seconds between probes")
    ap.add_argument("--timeout", type=float, default=1.0)
    ap.add_argument("--trip", type=int, default=3,
                    help="consecutive failures before calling it a drop")
    # Cloudflare's public resolver; deliberately an address and not a name,
    # so the WAN probe never depends on the resolver it is meant to isolate.
    ap.add_argument("--wan", default="1.1.1.1")  # gitleaks:allow
    ap.add_argument("--retain-days", type=int, default=30)
    ap.add_argument("--quiet", action="store_true",
                    help="suppress the live line; outages are still printed")
    ap.add_argument("--stall-ms", type=int, default=50,
                    help="air-hop RTT above this counts as a stall in --report")
    ap.add_argument("--report", action="store_true", help="analyse what was recorded, then exit")
    ap.add_argument("--burst", type=float, metavar="SECONDS", default=None,
                    help="high-rate profile of the air hop, then exit")
    ap.add_argument("--burst-interval", type=float, default=0.02)
    ap.add_argument("--reports-dir", default=REPORTS_DIR,
                    help="where macOS writes crash and watchdog reports (for testing)")
    args = ap.parse_args()

    if args.report:
        report(args.outdir, args.stall_ms)
        return

    gw, iface = primary_route()
    if not gw:
        sys.exit("netwatch: no default route")

    if args.burst is not None:
        burst(gw, args.burst, args.burst_interval)
        return

    resolvers = lan_resolvers(iface)
    targets = {"air": IcmpProbe(gw), "wan": IcmpProbe(args.wan)}
    if resolvers:
        targets["dns"] = DnsProbe(resolvers[0])

    print("netwatch  iface=%s  air=%s  wan=%s  dns=%s"
          % (iface, gw, args.wan, resolvers[0] if resolvers else "none"))
    print("probing every %.2fs; a drop is %d consecutive failures (~%.2fs); -> %s\n"
          % (args.interval, args.trip, args.trip * args.interval, args.outdir))
    Watcher(targets, args.outdir, args.interval, args.timeout, args.trip,
            iface, args.quiet, args.retain_days, args.reports_dir).run()


if __name__ == "__main__":
    main()

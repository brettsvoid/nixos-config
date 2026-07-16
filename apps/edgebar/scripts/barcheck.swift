// Multi-monitor regression check for the running edgebar: every NSScreen must
// have (a) a bar window (level 5) spanning its full width at its top edge and
// (b) a native frame window (level 6) matching its full bounds. Exits 0 on
// PASS. There is no headless seam for NSWindow layout, so this live check is
// the regression test for stale/missing per-display geometry.
//
//   DEVELOPER_DIR=/Library/Developer/CommandLineTools \
//     /Library/Developer/CommandLineTools/usr/bin/swiftc \
//     -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
//     -o /tmp/barcheck scripts/barcheck.swift
//   /tmp/barcheck "$(pgrep -f edgebar | head -1)" 64        # 64 = windowHeight
//
// (The direct CLT paths matter: the bare `swiftc` shim defers to the Nix
// xcrun on this machine and fails with "tool not found".)

import AppKit
import CoreGraphics

let pid = Int32(CommandLine.arguments[1])!
let barH = CommandLine.arguments.count > 2 ? Double(CommandLine.arguments[2])! : 64.0

guard let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) else {
    print("FAIL: no primary screen"); exit(1)
}
let primaryMaxY = primary.frame.maxY

struct Win { let x, y, w, h: Double; let layer: Int; let onscreen: Bool }
guard let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
    print("FAIL: no window list"); exit(1)
}
var wins: [Win] = []
for w in list {
    guard let owner = w[kCGWindowOwnerPID as String] as? Int32, owner == pid,
          let b = w[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
    wins.append(Win(x: Double(b["X"]!), y: Double(b["Y"]!), w: Double(b["Width"]!), h: Double(b["Height"]!),
                    layer: w[kCGWindowLayer as String] as? Int ?? -999,
                    onscreen: w[kCGWindowIsOnscreen as String] as? Bool ?? false))
}

let eps = 2.0
var ok = true
for s in NSScreen.screens {
    let f = s.frame
    let cgTop = Double(primaryMaxY - f.maxY)
    let x = Double(f.origin.x), w = Double(f.size.width), h = Double(f.size.height)

    let bar = wins.first(where: { $0.layer == 5 && abs($0.x - x) < eps && abs($0.y - cgTop) < eps
        && abs($0.w - w) < eps && abs($0.h - barH) < eps })
    let frame = wins.first(where: { $0.layer == 6 && abs($0.x - x) < eps && abs($0.y - cgTop) < eps
        && abs($0.w - w) < eps && abs($0.h - h) < eps })
    let barOK = bar != nil, frameOK = frame != nil
    if !barOK || !frameOK { ok = false }
    print("\(s.localizedName) [\(Int(w))x\(Int(h)) @\(s.backingScaleFactor)x top=(\(Int(x)),\(Int(cgTop)))]: "
        + "bar=\(barOK ? "OK" : "MISSING") frame=\(frameOK ? "OK" : "MISSING")")
}
let bars = wins.filter { $0.layer == 5 }.count
let frames = wins.filter { $0.layer == 6 }.count
print("totals: \(bars) bar / \(frames) frame windows for \(NSScreen.screens.count) screens")
if bars != NSScreen.screens.count || frames != NSScreen.screens.count { ok = false }
print(ok ? "PASS" : "FAIL")
exit(ok ? 0 : 1)

import QtQuick

// A number that follows `target` like a damped spring of mass 1, which is how Material 3
// specifies motion (Theme's spring* values). It keeps its velocity when the target
// changes part-way, so an interrupted open turns smoothly into a close, and it stops
// ticking once it has settled.
FrameAnimation {
    id: root

    // { damping, stiffness }: one of Theme's springs. Damping above 1 counts as 1.
    property var spec: ({ damping: 1, stiffness: 1600 })
    property real target: 0
    property real value: 0
    property real velocity: 0
    // Settled once the distance to the target is below this, and the speed below ten
    // times it per second.
    property real precision: 0.001

    onTargetChanged: running = true

    // Each frame steps the exact solution of the spring from where it is now, so the
    // motion does not depend on the frame rate.
    onTriggered: {
        // A long gap (the window was hidden) lands on the result instead of jumping
        // through it.
        const t = Math.min(frameTime, 0.1);
        const w = Math.sqrt(spec.stiffness);
        const z = Math.min(spec.damping, 1);
        const x0 = value - target;
        const v0 = velocity;
        let x, v;
        if (z < 1) {
            const a = z * w;
            const wd = w * Math.sqrt(1 - z * z);
            const e = Math.exp(-a * t);
            const c = Math.cos(wd * t);
            const s = Math.sin(wd * t);
            x = e * (x0 * c + (v0 + a * x0) / wd * s);
            v = e * (v0 * c - (a * v0 + w * w * x0) / wd * s);
        } else {
            const e = Math.exp(-w * t);
            const b = v0 + w * x0;
            x = e * (x0 + b * t);
            v = e * (v0 - w * b * t);
        }
        if (Math.abs(x) < precision && Math.abs(v) < precision * 10) {
            value = target;
            velocity = 0;
            running = false;
        } else {
            value = target + x;
            velocity = v;
        }
    }
}

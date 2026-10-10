import QtQuick
import QtQuick.Shapes
import "../theme"

// A filled line of recent percentages, newest at the right. It is a Shape, so the GPU
// draws it, and it only changes when `values` does (once a sample).
Shape {
    id: root

    // 0 to 100, oldest first.
    property var values: []
    property int capacity: 60
    property color colour: Theme.primary

    readonly property real step: root.width / Math.max(root.capacity - 1, 1)
    readonly property var points: {
        const n = root.values.length;
        const out = [];
        for (let i = 0; i < n; ++i)
            out.push(Qt.point(root.width - (n - 1 - i) * root.step, root.height * (1 - Math.max(0, Math.min(100, root.values[i])) / 100)));
        return out;
    }

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: root.colour
        strokeWidth: 2
        fillColor: Qt.alpha(root.colour, 0.2)
        joinStyle: ShapePath.RoundJoin

        PathPolyline {
            // Down to the baseline at both ends, so the area under the line fills.
            path: root.points.length < 2 ? [] : [Qt.point(root.points[0].x, root.height)].concat(root.points, [Qt.point(root.width, root.height)])
        }
    }
}

import QtQuick

// Draws the frame and the boxes joined to it as one shape with a soft shadow
// (shaders/frame.frag). The frame is this item minus `hole`. Anything else that grows
// out of the frame, such as the bar or an open drawer, is an entry in `shapes`; the
// shader takes up to eight.
ShaderEffect {
    id: root

    // The area inside the frame, with its corner radius. It may reach past this item's
    // edges, which leaves that side of the frame out.
    property rect hole
    property real holeRadius
    // Each entry is { x, y, width, height, radius } in this item's coordinates.
    property var shapes: []
    // Radius of the curve that fills each concave corner where two parts meet.
    property real fillet
    property real shadowSize
    property color fillColor
    property color shadowColor

    readonly property vector2d viewSize: Qt.vector2d(width, height)
    readonly property int shapeCount: Math.min(shapes.length, 8)
    readonly property rect shape0: shapeRect(0)
    readonly property rect shape1: shapeRect(1)
    readonly property rect shape2: shapeRect(2)
    readonly property rect shape3: shapeRect(3)
    readonly property rect shape4: shapeRect(4)
    readonly property rect shape5: shapeRect(5)
    readonly property rect shape6: shapeRect(6)
    readonly property rect shape7: shapeRect(7)
    readonly property vector4d shapeRadii: Qt.vector4d(shapeRadius(0), shapeRadius(1), shapeRadius(2), shapeRadius(3))
    readonly property vector4d shapeRadii2: Qt.vector4d(shapeRadius(4), shapeRadius(5), shapeRadius(6), shapeRadius(7))

    function shapeRect(i) {
        const s = shapes[i];
        return s ? Qt.rect(s.x, s.y, s.width, s.height) : Qt.rect(0, 0, 0, 0);
    }

    function shapeRadius(i) {
        return shapes[i]?.radius ?? 0;
    }

    fragmentShader: Qt.resolvedUrl("../shaders/frame.frag.qsb")
}

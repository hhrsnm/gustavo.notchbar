import QtQuick
import QtQuick.Shapes

Item {
  id: notch

  property real radius: 8
  property real contentWidth: 100
  property real contentHeight: 32
  property color color: Qt.rgba(0.1, 0.1, 0.12, 0.50)
  property color borderColor: Qt.rgba(1, 1, 1, 0.18)
  property real borderWidth: 1
  property bool shadowEnabled: true
  property string attachSide: "none" // "none" | "left" | "right"

  // Total notch width is content width + fillet wings
  implicitWidth: {
    if (attachSide === "left" || attachSide === "right") {
      return Math.ceil(contentWidth + radius)
    }
    return Math.ceil(contentWidth + radius * 2)
  }
  implicitHeight: Math.ceil(contentHeight + (attachSide !== "none" ? radius : 0))
  width: implicitWidth
  height: implicitHeight

  readonly property real x0: attachSide === "right" ? 0 : radius
  readonly property real x1: attachSide === "left" ? width : width - radius

  // Translucent Frosted Base Fill & Optical Border (Zero-FBO vector rasterization)
  Shape {
    id: fillShape
    anchors.fill: parent
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer

    // Floating island: a plain rounded rectangle, no fillet wings. The old wing
    // space stays in the width (transparent) so layout doesn't shift; on a
    // screen-attached side it becomes the gap from the screen edge.
    ShapePath {
      strokeColor: "transparent"
      strokeWidth: 0
      fillColor: notch.color

      startX: notch.x0 + notch.radius
      startY: 0

      PathLine { x: notch.x1 - notch.radius; y: 0 }
      PathArc { x: notch.x1; y: notch.radius; radiusX: notch.radius; radiusY: notch.radius }
      PathLine { x: notch.x1; y: notch.contentHeight - notch.radius }
      PathArc { x: notch.x1 - notch.radius; y: notch.contentHeight; radiusX: notch.radius; radiusY: notch.radius }
      PathLine { x: notch.x0 + notch.radius; y: notch.contentHeight }
      PathArc { x: notch.x0; y: notch.contentHeight - notch.radius; radiusX: notch.radius; radiusY: notch.radius }
      PathLine { x: notch.x0; y: notch.radius }
      PathArc { x: notch.x0 + notch.radius; y: 0; radiusX: notch.radius; radiusY: notch.radius }
    }

    ShapePath {
      strokeColor: notch.borderWidth > 0 ? notch.borderColor : "transparent"
      strokeWidth: notch.borderWidth
      fillColor: "transparent"

      startX: notch.x0 + notch.radius
      startY: 0

      PathLine { x: notch.x1 - notch.radius; y: 0 }
      PathArc { x: notch.x1; y: notch.radius; radiusX: notch.radius; radiusY: notch.radius }
      PathLine { x: notch.x1; y: notch.contentHeight - notch.radius }
      PathArc { x: notch.x1 - notch.radius; y: notch.contentHeight; radiusX: notch.radius; radiusY: notch.radius }
      PathLine { x: notch.x0 + notch.radius; y: notch.contentHeight }
      PathArc { x: notch.x0; y: notch.contentHeight - notch.radius; radiusX: notch.radius; radiusY: notch.radius }
      PathLine { x: notch.x0; y: notch.radius }
      PathArc { x: notch.x0 + notch.radius; y: 0; radiusX: notch.radius; radiusY: notch.radius }
    }
  }
}

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
  id: root

  required property var settings

  readonly property int iconSize: settings.iconSize || 52
  readonly property real magnification: settings.magnification || 1.65
  readonly property real magnificationRadius: settings.magnificationRadius || 110
  readonly property int edgeMargin: settings.margin === undefined ? 10 : settings.margin
  readonly property bool reserveSpace: settings.reserveSpace === undefined ? true : settings.reserveSpace
  readonly property string clickAction: settings.clickAction || "focus-or-launch"
  readonly property var pinned: settings.pinned || []
  readonly property int itemSize: iconSize + 14
  readonly property int reservedHeight: iconSize + 24 + edgeMargin
  readonly property int horizontalPadding: 10
  readonly property real pointerX: pointer.hovered ? pointer.point.position.x : -10000

  anchors { bottom: true }
  margins.bottom: edgeMargin
  implicitWidth: dockBackground.width
  implicitHeight: Math.ceil(iconSize * magnification + 48)
  color: "transparent"
  exclusionMode: reserveSpace ? ExclusionMode.Normal : ExclusionMode.Ignore
  WlrLayershell.exclusiveZone: reserveSpace ? reservedHeight : 0
  WlrLayershell.namespace: "hyprland-dock"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  Rectangle {
    id: dockBackground

    width: dockRow.width + root.horizontalPadding * 2
    height: root.iconSize + 24
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    radius: 20
    color: Qt.rgba(0.08, 0.09, 0.11, 0.88)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.18)

    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      radius: parent.radius - 1
      color: "transparent"
      border.width: 1
      border.color: Qt.rgba(0, 0, 0, 0.28)
    }

    Row {
      id: dockRow

      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 6

      Repeater {
        model: root.pinned

        DockItem {
          required property string modelData

          desktopId: modelData
          slotSize: root.itemSize
          iconSize: root.iconSize
          magnification: root.magnification
          magnificationRadius: root.magnificationRadius
          pointerX: root.pointerX - dockRow.x
          clickAction: root.clickAction
        }
      }
    }
  }

  HoverHandler {
    id: pointer
  }
}

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
  id: root

  required property var settings
  signal reorderRequested(int from, int to)

  property int dragSource: -1
  property int dragTarget: -1

  readonly property int iconSize: settings.iconSize || 52
  readonly property real magnification: settings.magnification || 1.65
  readonly property real magnificationRadius: settings.magnificationRadius || 110
  readonly property int edgeMargin: settings.margin === undefined ? 10 : settings.margin
  readonly property real backgroundOpacity: {
    var value = Number(settings.backgroundOpacity)
    return settings.backgroundOpacity === undefined || isNaN(value)
      ? 0.88
      : Math.max(0, Math.min(1, value))
  }
  readonly property bool reserveSpace: settings.reserveSpace === undefined ? true : settings.reserveSpace
  readonly property string clickAction: settings.clickAction || "focus-or-launch"
  readonly property string requestedPosition: settings.position || "bottom"
  readonly property string position: ["top", "bottom", "left", "right"].indexOf(requestedPosition) >= 0
    ? requestedPosition
    : "bottom"
  readonly property bool vertical: position === "left" || position === "right"
  readonly property bool fullLength: settings.fullLength === undefined ? false : settings.fullLength
  readonly property var pinned: settings.pinned || []
  readonly property int itemSize: iconSize + 14
  readonly property int reservedSize: iconSize + 24 + edgeMargin
  readonly property int mainPadding: 10
  readonly property int crossExtent: vertical
    ? Math.ceil(iconSize * magnification + 80)
    : Math.ceil(iconSize * magnification + 48)
  readonly property real pointerPosition: !pointer.hovered
    ? -10000
    : vertical
      ? pointer.point.position.y - dockLayout.y
      : pointer.point.position.x - dockLayout.x

  function reorderOffset(index) {
    if (dragSource < dragTarget && index > dragSource && index <= dragTarget)
      return -itemSize
    if (dragSource > dragTarget && index >= dragTarget && index < dragSource)
      return itemSize
    return 0
  }

  function updateDragTarget(position) {
    dragTarget = Math.max(0, Math.min(pinned.length - 1, Math.floor(position / itemSize)))
  }

  function finishDrag() {
    var from = dragSource
    var to = dragTarget
    dragSource = -1
    dragTarget = -1
    if (from >= 0 && to >= 0 && from !== to)
      reorderRequested(from, to)
  }

  anchors {
    top: position === "top" || (vertical && fullLength)
    bottom: position === "bottom" || (vertical && fullLength)
    left: position === "left" || (!vertical && fullLength)
    right: position === "right" || (!vertical && fullLength)
  }
  margins {
    top: position === "top" ? edgeMargin : 0
    bottom: position === "bottom" ? edgeMargin : 0
    left: position === "left" ? edgeMargin : 0
    right: position === "right" ? edgeMargin : 0
  }

  implicitWidth: vertical
    ? crossExtent
    : fullLength ? 0 : dockLayout.implicitWidth + mainPadding * 2
  implicitHeight: vertical
    ? fullLength ? 0 : dockLayout.implicitHeight + mainPadding * 2
    : crossExtent
  color: "transparent"
  exclusionMode: reserveSpace ? ExclusionMode.Normal : ExclusionMode.Ignore
  WlrLayershell.exclusiveZone: reserveSpace ? reservedSize : 0
  WlrLayershell.namespace: "hyprland-dock"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  Rectangle {
    id: dockBackground

    x: root.position === "right" ? parent.width - width : 0
    y: root.position === "bottom" ? parent.height - height : 0
    width: root.vertical ? root.iconSize + 24 : parent.width
    height: root.vertical ? parent.height : root.iconSize + 24
    radius: 20
    color: Qt.rgba(0.08, 0.09, 0.11, root.backgroundOpacity)
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

    Grid {
      id: dockLayout

      // Offset the layout toward the screen edge so the icon itself, rather
      // than the icon-plus-indicator slot, is centered in the background.
      x: root.vertical
        ? root.position === "left" ? 6 : parent.width - implicitWidth - 6
        : (parent.width - implicitWidth) / 2
      y: root.vertical
        ? (parent.height - implicitHeight) / 2
        : root.position === "top" ? 6 : parent.height - implicitHeight - 6

      // Keep one spare cell so a settings reload cannot transiently reduce the
      // grid capacity before the repeater updates its delegates.
      columns: root.vertical ? 1 : Math.max(1, root.pinned.length + 1)
      rows: root.vertical ? Math.max(1, root.pinned.length + 1) : 1

      Repeater {
        model: root.pinned

        DockItem {
          required property string modelData
          required property int index

          desktopId: modelData
          itemIndex: index
          slotSize: root.itemSize
          iconSize: root.iconSize
          magnification: root.magnification
          magnificationRadius: root.magnificationRadius
          pointerPosition: root.pointerPosition
          clickAction: root.clickAction
          position: root.position
          vertical: root.vertical
          reorderOffset: root.reorderOffset(index)
          onDragStarted: itemIndex => {
            root.dragSource = itemIndex
            root.dragTarget = itemIndex
          }
          onDragMoved: mainPosition => root.updateDragTarget(mainPosition)
          onDragFinished: root.finishDrag()
        }
      }
    }
  }

  HoverHandler {
    id: pointer
  }
}

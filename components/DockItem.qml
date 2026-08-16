import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

Item {
  id: root

  required property string desktopId
  required property int slotSize
  required property int iconSize
  required property real magnification
  required property real magnificationRadius
  required property real pointerPosition
  required property string clickAction
  required property string position
  required property bool vertical

  // Reading the model makes this binding update when Quickshell finishes its
  // asynchronous desktop-entry scan. Calling byId() alone is not reactive.
  readonly property var applications: DesktopEntries.applications.values || []
  readonly property var entry: {
    var modelRevision = applications.length
    return DesktopEntries.byId(desktopId)
  }
  readonly property var toplevels: ToplevelManager.toplevels.values || []
  readonly property var runningToplevel: {
    var modelRevision = toplevels.length
    return findRunningToplevel()
  }
  readonly property real itemCenter: vertical ? y + height / 2 : x + width / 2
  readonly property real distance: Math.abs(pointerPosition - itemCenter)
  readonly property real influence: pointerPosition < -1000
    ? 0
    : Math.exp(-(distance * distance) / (magnificationRadius * magnificationRadius))
  readonly property real iconScale: 1 + (magnification - 1) * influence

  function normalizedId(value) {
    return String(value || "").toLowerCase().replace(/\.desktop$/, "")
  }

  function matchesEntry(toplevel) {
    if (!toplevel) return false
    var appId = normalizedId(toplevel.appId)
    if (!appId) return false

    var ids = [desktopId]
    if (entry) ids.push(entry.id, entry.startupClass)
    for (var i = 0; i < ids.length; ++i) {
      var id = normalizedId(ids[i])
      if (id && appId === id) return true
    }
    return false
  }

  function findRunningToplevel() {
    for (var i = 0; i < toplevels.length; ++i) {
      if (matchesEntry(toplevels[i])) return toplevels[i]
    }
    return null
  }

  function launch() {
    if (entry)
      entry.execute()
    else
      Quickshell.execDetached(["gtk-launch", desktopId + ".desktop"])
  }

  function activateOrLaunch() {
    if (clickAction === "focus-or-launch" && runningToplevel) {
      runningToplevel.activate()
      return
    }
    launch()
  }

  width: vertical ? slotSize + 6 : slotSize
  height: vertical ? slotSize : slotSize + 6

  Item {
    id: iconContainer

    x: root.vertical
      ? root.position === "left" ? 6 : root.width - root.iconSize - 6
      : (root.width - root.iconSize) / 2
    y: root.vertical
      ? (root.height - root.iconSize) / 2
      : root.position === "top" ? 6 : root.height - root.iconSize - 6
    width: root.iconSize
    height: root.iconSize
    transformOrigin: root.position === "top"
      ? Item.Top
      : root.position === "left"
        ? Item.Left
        : root.position === "right" ? Item.Right : Item.Bottom
    scale: root.iconScale

    Behavior on scale {
      NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
    }

    Rectangle {
      anchors.fill: parent
      anchors.margins: -4
      radius: 14
      color: mouse.hovered ? Qt.rgba(1, 1, 1, 0.10) : "transparent"

      Behavior on color { ColorAnimation { duration: 100 } }
    }

    IconImage {
      anchors.fill: parent
      source: root.entry && root.entry.icon
        ? Quickshell.iconPath(root.entry.icon, true)
        : Quickshell.iconPath("application-x-executable", true)
      asynchronous: true
    }

    Rectangle {
      width: 4
      height: 4
      radius: 2
      x: root.position === "left"
        ? iconContainer.width + 4
        : root.position === "right"
          ? -8
          : (iconContainer.width - width) / 2
      y: root.position === "top"
        ? -8
        : root.position === "bottom"
          ? iconContainer.height + 4
          : (iconContainer.height - height) / 2
      color: root.runningToplevel ? "#f5f5f5" : "transparent"
    }
  }

  Rectangle {
    id: tooltip

    visible: mouse.hovered
    x: root.position === "left"
      ? iconContainer.x + iconContainer.width + 12
      : root.position === "right"
        ? iconContainer.x - width - 12
        : (root.width - width) / 2
    y: root.position === "top"
      ? iconContainer.y + iconContainer.height + 12
      : root.position === "bottom"
        ? iconContainer.y - height - 12
        : (root.height - height) / 2
    width: tooltipText.implicitWidth + 18
    height: tooltipText.implicitHeight + 10
    radius: 8
    color: Qt.rgba(0.08, 0.09, 0.11, 0.96)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.16)
    z: 10

    Text {
      id: tooltipText
      anchors.centerIn: parent
      text: root.entry ? root.entry.name : root.desktopId
      color: "#f5f5f5"
      font.pixelSize: 13
    }
  }

  HoverHandler {
    id: mouse
    cursorShape: Qt.PointingHandCursor
  }

  TapHandler {
    acceptedButtons: Qt.LeftButton
    onTapped: root.activateOrLaunch()
  }
}

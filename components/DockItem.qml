import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

Item {
  id: root

  required property string desktopId
  required property int slotSize
  required property int iconSize
  required property real magnification
  required property real magnificationRadius
  required property real pointerX
  required property string clickAction
  required property bool warpCursorOnFocus

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
  readonly property real distance: Math.abs(pointerX - (x + width / 2))
  readonly property real influence: pointerX < -1000
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

  function hyprlandAddress(toplevel) {
    var clients = Hyprland.toplevels.values || []
    for (var i = 0; i < clients.length; ++i) {
      if (clients[i].wayland === toplevel) {
        var address = String(clients[i].address || "")
        return address.indexOf("0x") === 0 ? address : "0x" + address
      }
    }
    return ""
  }

  function activateWithoutWarp(toplevel) {
    var address = hyprlandAddress(toplevel)
    if (!address) {
      // Fall back to the standard protocol if Hyprland has not associated its
      // IPC client with the Wayland toplevel yet.
      toplevel.activate()
      return
    }

    // Hyprland's focus dispatcher obeys cursor:warp_on_change_workspace. Turn
    // it off only for this dispatch, then restore the user's runtime value.
    Quickshell.execDetached([
      "bash", "-c",
      "old=$(hyprctl getoption cursor:warp_on_change_workspace -j | jq -r '.int // 0'); " +
        "trap 'hyprctl keyword cursor:warp_on_change_workspace \"$old\" >/dev/null' EXIT; " +
        "hyprctl keyword cursor:warp_on_change_workspace 0 >/dev/null; " +
        "hyprctl dispatch focuswindow \"address:$1\" >/dev/null",
      "hyprland-dock-focus", address
    ])
  }

  function activateOrLaunch() {
    if (clickAction === "focus-or-launch" && runningToplevel) {
      if (warpCursorOnFocus)
        runningToplevel.activate()
      else
        activateWithoutWarp(runningToplevel)
      return
    }
    launch()
  }

  width: slotSize
  height: slotSize + 6

  Item {
    id: iconContainer

    width: root.iconSize
    height: root.iconSize
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 6
    transformOrigin: Item.Bottom
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
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.bottom
      anchors.topMargin: 4
      color: root.runningToplevel ? "#f5f5f5" : "transparent"
    }
  }

  Rectangle {
    id: tooltip

    visible: mouse.hovered
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: iconContainer.top
    anchors.bottomMargin: 12
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

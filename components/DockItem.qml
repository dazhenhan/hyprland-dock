import QtQuick
import Quickshell
import Quickshell.Widgets

Item {
  id: root

  required property string desktopId
  required property bool pinned
  required property var windowController
  required property int itemIndex
  required property int slotSize
  required property int iconSize
  required property real magnification
  required property real magnificationRadius
  required property real pointerPosition
  required property string clickAction
  required property bool autoHide
  required property string position
  required property bool vertical
  property real reorderOffset: 0
  signal dragStarted(int itemIndex)
  signal dragMoved(real mainPosition)
  signal dragFinished()
  signal addApplicationRequested()
  signal pinRequested(string desktopId)
  signal removeRequested(string desktopId)
  signal autoHideToggled(bool enabled)
  signal contextMenuVisibilityChanged(bool visible)

  // Reading the model makes this binding update when Quickshell finishes its
  // asynchronous desktop-entry scan. Calling byId() alone is not reactive.
  readonly property var applications: DesktopEntries.applications.values || []
  readonly property var entry: {
    var modelRevision = applications.length
    return DesktopEntries.byId(desktopId)
  }
  readonly property bool running: windowController.hasRunningWindow(desktopId, entry)
  readonly property real dragOffset: dragHandler.active
    ? vertical ? dragHandler.activeTranslation.y : dragHandler.activeTranslation.x
    : 0
  readonly property real itemCenter: (vertical ? y + height / 2 : x + width / 2)
    + dragOffset + reorderOffset
  readonly property real distance: Math.abs(pointerPosition - itemCenter)
  readonly property real influence: pointerPosition < -1000
    ? 0
    : Math.exp(-(distance * distance) / (magnificationRadius * magnificationRadius))
  readonly property real iconScale: 1 + (magnification - 1) * influence

  function launch() {
    if (entry)
      entry.execute()
    else
      Quickshell.execDetached(["gtk-launch", desktopId + ".desktop"])
  }

  function activateOrLaunch() {
    if (clickAction === "focus-or-launch" || clickAction === "toggle-minimize-or-launch") {
      if (windowController.toggleApplication(desktopId, entry)) return
    }
    launch()
  }

  function closeRunning() {
    windowController.closeApplication(desktopId, entry)
  }

  width: vertical ? slotSize + 6 : slotSize
  height: vertical ? slotSize : slotSize + 6
  z: dragHandler.active ? 2 : 0
  transform: Translate {
    x: root.vertical ? 0 : root.dragOffset + root.reorderOffset
    y: root.vertical ? root.dragOffset + root.reorderOffset : 0
  }

  Behavior on reorderOffset {
    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
  }

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
        ? iconContainer.width + 2
        : root.position === "right"
          ? -6
          : (iconContainer.width - width) / 2
      y: root.position === "top"
        ? -6
        : root.position === "bottom"
          ? iconContainer.height + 2
          : (iconContainer.height - height) / 2
      color: root.running ? "#f5f5f5" : "transparent"
    }
  }

  Rectangle {
    id: tooltip

    visible: mouse.hovered && !contextMenu.visible
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

  TapHandler {
    acceptedButtons: Qt.RightButton
    onTapped: contextMenu.open()
  }

  DragHandler {
    id: dragHandler

    target: null
    acceptedButtons: Qt.LeftButton
    enabled: root.pinned
    xAxis.enabled: !root.vertical
    yAxis.enabled: root.vertical
    onActiveChanged: {
      if (active)
        root.dragStarted(root.itemIndex)
      else
        root.dragFinished()
    }
    onActiveTranslationChanged: {
      if (active)
        root.dragMoved((root.vertical ? root.y + root.height / 2 : root.x + root.width / 2)
          + (root.vertical ? activeTranslation.y : activeTranslation.x))
    }
  }

  DockContextMenu {
    id: contextMenu

    anchorItem: root
    position: root.position
    pinned: root.pinned
    canClose: root.running
    autoHide: root.autoHide
    onVisibleChanged: root.contextMenuVisibilityChanged(visible)
    onOpenNewWindow: root.launch()
    onCloseWindow: root.closeRunning()
    onAddApplication: root.addApplicationRequested()
    onPinToDock: root.pinRequested(root.desktopId)
    onRemoveFromDock: root.removeRequested(root.desktopId)
    onToggleAutoHide: root.autoHideToggled(!root.autoHide)
  }
}

import QtQuick
import Quickshell

DockHost {
  // Properties injected by the Omarchy shell plugin host.
  property var shell: null
  property var manifest: null

  configPath: Quickshell.env("HOME") + "/.config/hyprland-dock/dock.json"
}

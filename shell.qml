import QtQuick
import Quickshell

ShellRoot {
  DockHost {
    configPath: Quickshell.env("HYPRLAND_DOCK_CONFIG")
      || Quickshell.shellDir + "/config/dock.json"
  }
}

import QtQuick
import Quickshell
import Quickshell.Io
import "components"

ShellRoot {
  id: root

  property var settings: ({
    iconSize: 48,
    magnification: 1.3,
    magnificationRadius: 95,
    margin: 10,
    reserveSpace: true,
    clickAction: "focus-or-launch",
    pinned: [
      "org.gnome.Nautilus",
      "com.mitchellh.ghostty",
      "chromium",
      "code",
      "obsidian"
    ]
  })

  function loadSettings(raw) {
    try {
      var parsed = JSON.parse(raw)
      if (!parsed.pinned || !Array.isArray(parsed.pinned))
        throw new Error("'pinned' must be an array")
      settings = parsed
    } catch (error) {
      console.warn("Dock: could not load config/dock.json:", error)
    }
  }

  FileView {
    path: Quickshell.shellDir + "/config/dock.json"
    watchChanges: true
    onLoaded: root.loadSettings(text())
    onFileChanged: root.loadSettings(text())
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      Dock {
        required property var modelData
        screen: modelData
        settings: root.settings
      }
    }
  }
}

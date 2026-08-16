pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "components"

Item {
  id: root

  required property string configPath

  property var settings: ({
    iconSize: 42,
    magnification: 1.2,
    magnificationRadius: 95,
    margin: 10,
    position: "bottom",
    fullLength: false,
    reserveSpace: true,
    clickAction: "focus-or-launch",
    pinned: [
      "org.gnome.Nautilus",
      "com.mitchellh.ghostty",
      "com.google.Chrome",
      "code",
      "obsidian",
      "chatgpt"
    ]
  })

  function loadSettings(raw) {
    try {
      var parsed = JSON.parse(raw)
      if (!parsed.pinned || !Array.isArray(parsed.pinned))
        throw new Error("'pinned' must be an array")
      settings = parsed
    } catch (error) {
      console.warn("Dock: could not load " + configPath + ":", error)
    }
  }

  FileView {
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadSettings(text())
    // FileView.text() is still stale inside onFileChanged. Reload first and
    // parse the fresh contents when onLoaded fires.
    onFileChanged: reload()
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

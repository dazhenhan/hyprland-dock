pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "components"

Item {
  id: root

  required property string configPath

  readonly property string minimizedWorkspace: "special:dock-minimized"
  readonly property var hyprlandToplevels: Hyprland.toplevels.values || []
  readonly property var desktopApplications: DesktopEntries.applications.values || []
  property var minimizedWindows: ({})
  property var showDesktopWindows: ({})
  property var pendingFrontRequests: []

  // Dock item bindings depend on this lightweight revision instead of
  // traversing every toplevel while Hyprland is applying a batched IPC update.
  // Quickshell 0.3.1 can crash if QML reads lastIpcObject inside that property
  // update group, so a timer advances the snapshot from the next event loop.
  property int clientRevision: 0
  readonly property int desktopApplicationCount: desktopApplications.length
  property var runningUnpinnedDesktopIds: []

  property var settings: ({
    iconSize: 42,
    magnification: 1.2,
    magnificationRadius: 95,
    margin: 10,
    backgroundOpacity: 0.88,
    position: "bottom",
    fullLength: false,
    reserveSpace: true,
    autoHide: false,
    screens: [],
    showRunningApplications: true,
    clickAction: "toggle-minimize-or-launch",
    pinned: [
      "org.gnome.Nautilus",
      "com.mitchellh.ghostty",
      "com.google.Chrome",
      "code",
      "obsidian",
      "chatgpt"
    ]
  })

  readonly property int screenCount: (Quickshell.screens || []).length
  property var enabledScreens: []

  function refreshEnabledScreens() {
    var result = []
    var availableScreens = Quickshell.screens || []
    for (var i = 0; i < availableScreens.length; ++i) {
      if (screenIsEnabled(availableScreens[i])) result.push(availableScreens[i])
    }
    enabledScreens = result
  }

  onDesktopApplicationCountChanged: dynamicApplicationsTimer.restart()
  onScreenCountChanged: screenTimer.restart()
  onSettingsChanged: {
    dynamicApplicationsTimer.restart()
    screenTimer.restart()
  }

  function normalizedId(value) {
    return String(value || "").trim().toLowerCase().replace(/\.desktop$/, "")
  }

  function screenIsEnabled(screen) {
    var configuredScreens = settings.screens
    if (!Array.isArray(configuredScreens) || configuredScreens.length === 0) return true
    var screenName = screen ? String(screen.name || "") : ""
    return configuredScreens.indexOf(screenName) >= 0
  }

  function compactId(value) {
    return normalizedId(value).replace(/[^a-z0-9]/g, "")
  }

  function executableId(entry) {
    if (!entry || !entry.command || entry.command.length === 0) return ""

    var wrappers = ["env", "uwsm", "uwsm-app", "flatpak", "snap"]
    for (var i = 0; i < entry.command.length; ++i) {
      var value = String(entry.command[i] || "")
      if (!value || value[0] === "-" || value.indexOf("=") >= 0) continue
      var slash = value.lastIndexOf("/")
      var executable = slash >= 0 ? value.slice(slash + 1) : value
      if (wrappers.indexOf(executable) >= 0) continue
      return normalizedId(executable).replace(/-(stable|beta|dev|bin)$/, "")
    }
    return ""
  }

  function commandClasses(entry) {
    var result = []
    if (!entry || !entry.command) return result

    for (var i = 0; i < entry.command.length; ++i) {
      var value = String(entry.command[i] || "")
      var match = value.match(/^--(?:class|name|app-id)=(.+)$/i)
      if (match) result.push(match[1])
    }
    return result
  }

  function webAppId(entry) {
    if (!entry || !entry.command) return ""

    for (var i = 0; i < entry.command.length; ++i) {
      var match = String(entry.command[i]).match(/https?:\/\/[^?#\s]+/i)
      if (!match) continue

      var url = match[0].replace(/^https?:\/\//i, "").replace(/\/$/, "")
      try {
        url = decodeURIComponent(url)
      } catch (error) {
        // The encoded URL is still useful for matching generated web-app IDs.
      }
      return compactId(url)
    }
    return ""
  }

  function sameDesktopEntry(desktopId, candidateClass) {
    if (!candidateClass) return false
    var found = DesktopEntries.heuristicLookup(String(candidateClass))
    return found && normalizedId(found.id) === normalizedId(desktopId)
  }

  function clientMatches(desktopId, entry, toplevel) {
    if (!toplevel) return false
    var ipc = toplevel.lastIpcObject || {}
    if (ipc.mapped === false) return false

    var classes = [ipc.class, ipc.initialClass, ipc.xdgTag]
    if (toplevel.wayland) classes.push(toplevel.wayland.appId)

    var ids = [desktopId]
    if (entry) ids.push(entry.id, entry.startupClass, executableId(entry))
    ids = ids.concat(commandClasses(entry))

    for (var i = 0; i < classes.length; ++i) {
      var appClass = normalizedId(classes[i])
      if (!appClass) continue

      for (var j = 0; j < ids.length; ++j) {
        var id = normalizedId(ids[j])
        if (!id) continue
        if (appClass === id || compactId(appClass) === compactId(id)) return true

        // Reverse-DNS desktop IDs commonly end in the actual WM class
        // (org.gnome.Nautilus -> nautilus). Keep this suffix fallback exact and
        // long enough to avoid broad substring matches.
        var classKey = compactId(appClass)
        var idKey = compactId(id)
        if (classKey.length >= 5 && idKey.endsWith(classKey)) return true
      }

      if (sameDesktopEntry(desktopId, appClass)) return true
    }

    var generatedWebAppId = webAppId(entry)
    if (generatedWebAppId.length >= 6) {
      for (var k = 0; k < classes.length; ++k) {
        if (compactId(classes[k]).indexOf(generatedWebAppId) >= 0) return true
      }
    }
    if (entry && ipc.title && entry.name
        && normalizedId(ipc.title) === normalizedId(entry.name)) return true
    return false
  }

  function desktopIdForToplevel(toplevel) {
    var pinned = settings.pinned || []
    for (var i = 0; i < pinned.length; ++i) {
      var pinnedEntry = DesktopEntries.byId(pinned[i])
      if (clientMatches(pinned[i], pinnedEntry, toplevel)) return pinned[i]
    }

    var ipc = toplevel ? toplevel.lastIpcObject || {} : {}
    var classes = [ipc.class, ipc.initialClass, ipc.xdgTag]
    if (toplevel && toplevel.wayland) classes.push(toplevel.wayland.appId)
    for (var j = 0; j < classes.length; ++j) {
      if (!classes[j]) continue
      var found = DesktopEntries.heuristicLookup(String(classes[j]))
      if (found && found.id && clientMatches(found.id, found, toplevel)) return found.id
    }

    for (var k = 0; k < desktopApplications.length; ++k) {
      var entry = desktopApplications[k]
      if (!entry || !entry.id) continue
      if (ipc.title && entry.name
          && normalizedId(ipc.title) === normalizedId(entry.name)) return entry.id
      if (clientMatches(entry.id, entry, toplevel)) return entry.id
    }
    return ""
  }

  function collectRunningUnpinnedDesktopIds() {
    var pinned = settings.pinned || []
    var pinnedIds = ({})
    for (var i = 0; i < pinned.length; ++i) pinnedIds[normalizedId(pinned[i])] = true

    var result = []
    var seen = ({})
    for (var j = 0; j < hyprlandToplevels.length; ++j) {
      var ipc = hyprlandToplevels[j].lastIpcObject || {}
      if (ipc.mapped === false) continue

      var desktopId = desktopIdForToplevel(hyprlandToplevels[j])
      var key = normalizedId(desktopId)
      // Quickshell popup/helper windows are implementation details of the
      // desktop shell, not applications that belong in an application dock.
      if (!key || key === "org.quickshell" || pinnedIds[key] || seen[key]) continue
      seen[key] = true
      result.push(desktopId)
    }
    return result
  }

  function refreshRunningApplications() {
    runningUnpinnedDesktopIds = collectRunningUnpinnedDesktopIds()
  }

  function windowAddress(toplevel) {
    var address = normalizedId(toplevel ? toplevel.address : "")
    if (!address) return ""
    return address.startsWith("0x") ? address : "0x" + address
  }

  function workspaceName(toplevel) {
    if (toplevel && toplevel.workspace) return String(toplevel.workspace.name || "")
    var ipc = toplevel ? toplevel.lastIpcObject || {} : {}
    return ipc.workspace ? String(ipc.workspace.name || "") : ""
  }

  function focusHistoryId(toplevel) {
    var ipc = toplevel ? toplevel.lastIpcObject || {} : {}
    var value = Number(ipc.focusHistoryID)
    return isNaN(value) ? 2147483647 : value
  }

  function matchingWindows(desktopId, entry) {
    // Reading the revision makes callers in property bindings react to class
    // and workspace changes as well as window creation/destruction.
    var revision = clientRevision
    var result = []
    var liveAddresses = ({})

    for (var i = 0; i < hyprlandToplevels.length; ++i) {
      var toplevel = hyprlandToplevels[i]
      var address = windowAddress(toplevel)
      if (address) liveAddresses[address] = true
      if (clientMatches(desktopId, entry, toplevel)) result.push(toplevel)
    }

    // Window addresses are stable for a client lifetime. Sorting gives the
    // multi-window policy deterministic dispatch order on every screen.
    result.sort(function(left, right) {
      return windowAddress(left).localeCompare(windowAddress(right))
    })

    var state = minimizedWindows
    for (var savedAddress in state) {
      if (!liveAddresses[savedAddress]) delete state[savedAddress]
    }
    return result
  }

  function hasRunningWindow(desktopId, entry) {
    return matchingWindows(desktopId, entry).length > 0
  }

  function dispatchMove(address, workspace) {
    if (!address || !workspace) return
    var selector = "address:" + address
    if (Hyprland.usingLua) {
      Hyprland.dispatch("hl.dsp.window.move({ workspace = "
        + JSON.stringify(String(workspace)) + ", window = hl.get_window("
        + JSON.stringify(selector) + "), follow = false })")
    } else {
      Hyprland.dispatch("dispatch movetoworkspacesilent " + workspace + "," + selector)
    }
  }

  function dispatchToFront(address, focusWindow) {
    if (!address) return
    var selector = "address:" + address
    if (Hyprland.usingLua) {
      var windowExpression = "hl.get_window(" + JSON.stringify(selector) + ")"
      if (focusWindow)
        Hyprland.dispatch("hl.dsp.focus({ window = " + windowExpression + " })")
      Hyprland.dispatch("hl.dsp.window.alter_zorder({ mode = \"top\", window = "
        + windowExpression + " })")
    } else {
      if (focusWindow) Hyprland.dispatch("dispatch focuswindow " + selector)
      Hyprland.dispatch("dispatch alterzorder top," + selector)
    }
  }

  function queueFrontRequests(requests) {
    if (!requests || requests.length === 0) return
    // If applications are restored in rapid succession, the most recent Dock
    // click owns focus. Each request still contains every window for that app.
    pendingFrontRequests = requests
    frontTimer.restart()
  }

  function flushFrontRequests() {
    var requests = pendingFrontRequests
    pendingFrontRequests = []
    if (requests.length === 0) return

    var activeWorkspaces = activeWorkspaceNames()
    var focusTarget = null
    for (var i = 0; i < requests.length; ++i) {
      var request = requests[i]
      if (!activeWorkspaces[request.workspace]) continue
      if (!focusTarget || request.focusHistoryId < focusTarget.focusHistoryId)
        focusTarget = request
    }

    // Raise every restored window on its own workspace. Raise and focus the
    // most recently used window last so it wins against another maximized
    // window without switching to a workspace that is not currently visible.
    for (var j = 0; j < requests.length; ++j) {
      if (!focusTarget || requests[j].address !== focusTarget.address)
        dispatchToFront(requests[j].address, false)
    }
    if (focusTarget) dispatchToFront(focusTarget.address, true)
  }

  // Returns false only when no live instance exists. If at least one matched
  // window is visible, every visible instance is minimized; if all are hidden,
  // every instance is restored to its own recorded workspace.
  function toggleApplication(desktopId, entry) {
    var windows = matchingWindows(desktopId, entry)
    if (windows.length === 0) return false

    var hasVisible = false
    for (var i = 0; i < windows.length; ++i) {
      if (workspaceName(windows[i]) !== minimizedWorkspace) {
        hasVisible = true
        break
      }
    }

    var state = minimizedWindows
    if (hasVisible) {
      for (var j = 0; j < windows.length; ++j) {
        var window = windows[j]
        var workspace = workspaceName(window)
        if (!workspace || workspace === minimizedWorkspace) continue
        var address = windowAddress(window)
        state[address] = {
          workspace: workspace,
          desktopId: normalizedId(desktopId),
          focusHistoryId: focusHistoryId(window)
        }
        dispatchMove(address, minimizedWorkspace)
      }
    } else {
      var fallbackWorkspace = Hyprland.focusedWorkspace
        ? String(Hyprland.focusedWorkspace.name || "") : ""
      var restoredWindows = []
      for (var k = 0; k < windows.length; ++k) {
        var hiddenAddress = windowAddress(windows[k])
        var saved = state[hiddenAddress] || showDesktopWindows[hiddenAddress]
        var restoreWorkspace = saved && saved.workspace ? saved.workspace : fallbackWorkspace
        dispatchMove(hiddenAddress, restoreWorkspace)
        restoredWindows.push({
          address: hiddenAddress,
          workspace: restoreWorkspace,
          focusHistoryId: saved && saved.focusHistoryId !== undefined
            ? saved.focusHistoryId : focusHistoryId(windows[k])
        })
        delete state[hiddenAddress]
        delete showDesktopWindows[hiddenAddress]
      }
      queueFrontRequests(restoredWindows)
    }

    minimizedWindows = state
    showDesktopWindows = showDesktopWindows
    refreshTimer.restart()
    return true
  }

  function activeWorkspaceNames() {
    var result = ({})
    var monitors = Hyprland.monitors.values || []
    for (var i = 0; i < monitors.length; ++i) {
      var workspace = monitors[i].activeWorkspace
      if (workspace && workspace.name) result[String(workspace.name)] = true
    }
    return result
  }

  function hideVisibleWindows() {
    var state = showDesktopWindows
    var liveAddresses = ({})
    for (var i = 0; i < hyprlandToplevels.length; ++i) {
      var address = windowAddress(hyprlandToplevels[i])
      if (!address) continue
      liveAddresses[address] = true
    }

    for (var savedAddress in state) {
      if (!liveAddresses[savedAddress]) delete state[savedAddress]
    }

    var activeWorkspaces = activeWorkspaceNames()
    for (var j = 0; j < hyprlandToplevels.length; ++j) {
      var toplevel = hyprlandToplevels[j]
      var ipc = toplevel.lastIpcObject || {}
      var workspace = workspaceName(toplevel)
      if (ipc.mapped === false || !activeWorkspaces[workspace]
          || workspace === minimizedWorkspace) continue

      var windowAddressValue = windowAddress(toplevel)
      if (!windowAddressValue) continue
      state[windowAddressValue] = {
        workspace: workspace,
        focusHistoryId: focusHistoryId(toplevel)
      }
      dispatchMove(windowAddressValue, minimizedWorkspace)
    }

    showDesktopWindows = state
    refreshTimer.restart()
  }

  function closeApplication(desktopId, entry) {
    var windows = matchingWindows(desktopId, entry)
    if (windows.length === 0) return

    var selector = "address:" + windowAddress(windows[0])
    if (Hyprland.usingLua) {
      Hyprland.dispatch("hl.dsp.window.close({ window = hl.get_window("
        + JSON.stringify(selector) + ") })")
    } else {
      Hyprland.dispatch("dispatch closewindow " + selector)
    }
  }

  function launchDesktopId(desktopId) {
    var entry = DesktopEntries.byId(desktopId)
    if (entry)
      entry.execute()
    else
      Quickshell.execDetached(["gtk-launch", desktopId + ".desktop"])
  }

  function toggleDesktopId(desktopId) {
    var entry = DesktopEntries.byId(desktopId)
    if (!toggleApplication(desktopId, entry)) {
      launchDesktopId(desktopId)
      return "launched"
    }
    return "toggled"
  }

  function inspectDesktopId(desktopId) {
    var entry = DesktopEntries.byId(desktopId)
    var windows = matchingWindows(desktopId, entry)
    var result = []
    for (var i = 0; i < windows.length; ++i) {
      var ipc = windows[i].lastIpcObject || {}
      result.push({
        address: windowAddress(windows[i]),
        workspace: workspaceName(windows[i]),
        class: ipc.class || "",
        initialClass: ipc.initialClass || ""
      })
    }
    return JSON.stringify(result)
  }

  function restoreManagedWindows() {
    var minimizedState = minimizedWindows
    var desktopState = showDesktopWindows
    for (var address in minimizedState) {
      var saved = minimizedState[address]
      if (saved && saved.workspace) dispatchMove(address, saved.workspace)
      delete minimizedState[address]
      delete desktopState[address]
    }
    for (var desktopAddress in desktopState) {
      var desktopSaved = desktopState[desktopAddress]
      if (desktopSaved && desktopSaved.workspace)
        dispatchMove(desktopAddress, desktopSaved.workspace)
      delete desktopState[desktopAddress]
    }
    minimizedWindows = minimizedState
    showDesktopWindows = desktopState
  }

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

  function reorderPinned(from, to) {
    if (from === to || from < 0 || to < 0
        || from >= settings.pinned.length || to >= settings.pinned.length)
      return

    var pinned = settings.pinned.slice()
    var moved = pinned.splice(from, 1)[0]
    pinned.splice(to, 0, moved)

    savePinned(pinned)
  }

  function pinApplication(desktopId) {
    if (!desktopId || settings.pinned.indexOf(desktopId) >= 0) return

    var pinned = settings.pinned.slice()
    pinned.push(desktopId)
    savePinned(pinned)
  }

  function unpinApplication(desktopId) {
    var index = settings.pinned.indexOf(desktopId)
    if (index < 0) return

    var pinned = settings.pinned.slice()
    pinned.splice(index, 1)
    savePinned(pinned)
  }

  function savePinned(pinned) {
    saveSetting("pinned", pinned)
  }

  function saveSetting(key, value) {
    var updated = {}
    for (var setting in settings)
      updated[setting] = settings[setting]
    updated[key] = value

    settings = updated
    configFile.setText(JSON.stringify(updated, null, 2) + "\n")
  }

  FileView {
    id: configFile

    path: root.configPath
    watchChanges: true
    printErrors: false
    blockWrites: true
    onLoaded: root.loadSettings(text())
    // FileView.text() is still stale inside onFileChanged. Reload first and
    // parse the fresh contents when onLoaded fires.
    onFileChanged: reload()
    onSaveFailed: error => console.warn("Dock: could not save " + root.configPath + ":", error)
  }

  Timer {
    id: refreshTimer

    interval: 80
    onTriggered: Hyprland.refreshToplevels()
  }

  Timer {
    id: frontTimer

    interval: 120
    onTriggered: root.flushFrontRequests()
  }

  Timer {
    id: screenTimer

    interval: 50
    onTriggered: root.refreshEnabledScreens()
  }

  Timer {
    id: dynamicApplicationsTimer

    interval: 250
    repeat: true
    running: true
    onTriggered: {
      root.clientRevision += 1
      root.refreshRunningApplications()
    }
  }

  IpcHandler {
    target: "hyprland-dock"

    function inspect(desktopId: string): string {
      return root.inspectDesktopId(desktopId)
    }

    function toggle(desktopId: string): string {
      return root.toggleDesktopId(desktopId)
    }

    function hideDesktop(): string {
      root.hideVisibleWindows()
      return "hidden"
    }

    function runningApplications(): string {
      return JSON.stringify(root.runningUnpinnedDesktopIds)
    }
  }

  Component.onCompleted: {
    dynamicApplicationsTimer.restart()
    screenTimer.restart()
  }
  Component.onDestruction: restoreManagedWindows()

  Variants {
    model: root.enabledScreens

    delegate: Component {
      Dock {
        required property var modelData
        screen: modelData
        settings: root.settings
        windowController: root
        onReorderRequested: (from, to) => root.reorderPinned(from, to)
        onPinRequested: desktopId => root.pinApplication(desktopId)
        onUnpinRequested: desktopId => root.unpinApplication(desktopId)
        onAutoHideRequested: enabled => root.saveSetting("autoHide", enabled)
      }
    }
  }
}

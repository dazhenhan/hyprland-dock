# Hyprland Dock

A lightweight macOS-inspired application dock for Hyprland, built with Quickshell and Qt/QML.

## Features

- Smooth pointer-distance magnification
- Freedesktop application icons and launching
- Focuses an existing application on another workspace
- Running-application indicators
- Optional reserved screen space
- Live JSON configuration reload
- Multi-monitor support

## Requirements

- Hyprland
- Quickshell 0.3 or newer
- A working freedesktop icon theme

## Run

```bash
./scripts/run
```

Quickshell watches the QML files, so UI changes reload while developing.

## Configure

Edit [`config/dock.json`](config/dock.json):

```json
{
  "iconSize": 48,
  "magnification": 1.3,
  "magnificationRadius": 95,
  "margin": 10,
  "reserveSpace": true,
  "clickAction": "focus-or-launch",
  "pinned": [
    "org.gnome.Nautilus",
    "com.mitchellh.ghostty",
    "chromium"
  ]
}
```

### Options

| Option | Description |
| --- | --- |
| `iconSize` | Base icon size in pixels |
| `magnification` | Maximum icon scale under the pointer |
| `magnificationRadius` | Distance over which nearby icons magnify |
| `margin` | Distance between the dock and screen edge |
| `reserveSpace` | When `true`, tiled windows stop above the dock |
| `clickAction` | `focus-or-launch` focuses an existing window; `launch` always starts a new instance |
| `pinned` | Ordered desktop-entry IDs displayed in the dock |

Pinned values are desktop-entry filenames without the `.desktop` suffix. List available IDs with:

```bash
find /usr/share/applications ~/.local/share/applications \
  -type f -name '*.desktop' 2>/dev/null \
  | sed 's#.*/##; s/\.desktop$//' | sort -u
```

The configuration file is watched and updates automatically.

### Disable cursor warping

Hyprland controls whether the pointer moves when focus switches to a window on another workspace. This is compositor-wide behavior and cannot be reliably overridden by the dock.

On Omarchy, add this override to `~/.config/hypr/looknfeel.lua`:

```lua
hl.config({
  cursor = {
    warp_on_change_workspace = 0,
  },
})
```

Hyprland normally reloads after the file is saved. Validate the configuration with:

```bash
hyprctl reload
hyprctl configerrors
```

This disables cursor warping for all workspace changes, not only dock clicks.

## Roadmap

- Auto-hide and edge reveal
- Pinning and drag-to-reorder
- Context menus
- Theme integration

## License

[MIT](LICENSE)

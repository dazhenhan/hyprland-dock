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
  "warpCursorOnFocus": true,
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
| `warpCursorOnFocus` | Whether Hyprland moves the pointer into a focused window on another workspace |
| `pinned` | Ordered desktop-entry IDs displayed in the dock |

Pinned values are desktop-entry filenames without the `.desktop` suffix. List available IDs with:

```bash
find /usr/share/applications ~/.local/share/applications \
  -type f -name '*.desktop' 2>/dev/null \
  | sed 's#.*/##; s/\.desktop$//' | sort -u
```

The configuration file is watched and updates automatically.

## Roadmap

- Auto-hide and edge reveal
- Pinning and drag-to-reorder
- Context menus
- Theme integration

## License

[MIT](LICENSE)

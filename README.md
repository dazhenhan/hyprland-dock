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

## Install

Make sure Quickshell is installed, then run:

```bash
curl -fsSL https://raw.githubusercontent.com/nick-friedrich/hyprland-dock/master/install.sh | bash
```

The installer uses only user directories, requires no `sudo`, and creates an XDG autostart entry. To install without autostart:

```bash
curl -fsSL https://raw.githubusercontent.com/nick-friedrich/hyprland-dock/master/install.sh | bash -s -- --no-autostart
```

Run the dock immediately with:

```bash
hyprland-dock --daemonize
```

Manage autostart later from the CLI:

```bash
hyprland-dock autostart status
hyprland-dock autostart enable
hyprland-dock autostart disable
```

Run `hyprland-dock help` to see every available command.

If your Hyprland session does not process XDG autostart entries, add one of these manually:

```lua
-- Omarchy: ~/.config/hypr/autostart.lua
o.launch_on_start("hyprland-dock")
```

```ini
# Standard Hyprland: ~/.config/hypr/hyprland.conf
exec-once = hyprland-dock
```

### Update or remove

```bash
hyprland-dock update
hyprland-dock restart
hyprland-dock uninstall
```

The older `--update`, `--restart`, and `--uninstall` forms remain supported. Uninstalling preserves the configuration; remove it too with `hyprland-dock uninstall --purge`.

### Development

Clone the repository and run directly from it:

```bash
./scripts/run
```

Quickshell watches the QML files, so UI changes reload while developing.

## Configure

Installed copies use `~/.config/hyprland-dock/dock.json`. When running from the repository, edit [`config/dock.json`](config/dock.json):

```json
{
  "iconSize": 42,
  "magnification": 1.2,
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

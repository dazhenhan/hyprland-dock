# AGENTS.md

## Project overview

This is a Hyprland application dock implemented with Quickshell and Qt/QML.

## Development

- Run the dock with `./scripts/run`.
- Keep the entry point at `shell.qml`.
- Put reusable visual components in `components/`.
- Keep user-facing defaults in `config/dock.json` and mirror fallback defaults in `shell.qml`.
- Prefer Quickshell APIs over shelling out to external commands.
- Use freedesktop desktop-entry IDs without the `.desktop` suffix.
- Preserve live configuration reloads.

## Validation

Before committing changes:

```bash
timeout 6s ./scripts/run --no-color
git diff --check
```

A portal warning about an application ID already being registered can occur when another Quickshell process is running; it is not a dock failure.

## Style

- Use two-space indentation in QML.
- Keep JavaScript helpers small and local to the component that owns the behavior.
- Add new configuration options to both `config/dock.json` and the README.

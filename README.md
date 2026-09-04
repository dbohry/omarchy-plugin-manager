# Plugin Manager

Bar plugin that lists every installed Omarchy shell plugin with an
enable/disable switch, plus a button to restart the shell.

<img width="593" height="867" alt="image" src="https://github.com/user-attachments/assets/3ed7799d-7998-4782-bdb8-cd94b8a6c7b9" />


## Usage

Click the puzzle-piece icon in the bar to open the panel:

- **Restart Shell** — runs `omarchy restart shell`.
- **Plugin list** — one row per plugin (name, id, enable/disable switch).
  Plugins that can't be disabled (like the bar itself) show a dimmed,
  non-interactive switch.
- Middle-click the bar icon to refresh the list without opening the panel.

## Files

- `manifest.json` — plugin manifest (id: `plugin-manager`).
- `Panel.qml` — bar icon + popup panel.

## Moving it in the bar

```bash
omarchy bar move plugin-manager --section left|center|right
```

## Uninstalling

```bash
omarchy plugin remove plugin-manager
```

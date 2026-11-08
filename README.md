# WoW Dual Window Manager (AutoHotkey v2)

Runs two World of Warcraft clients as borderless windows, default settings is one large main window and one small alt window on top, but you can do as you want.
Swap, resize, move them with hotkeys, change displays.

## Requirements

- Windows 10/11, [AutoHotkey v2](https://www.autohotkey.com/)
- WoW display mode: **Windowed** (windowed fullscreen also works)
- Edit the `CONFIG` block: `WowPath`, main and alt position/size

## Principles

- **Borderless:** title bar and border are removed from both WoW windows.
- **Main + alt:** main fills the main screen, alt sits in a corner, on top while WoW is active, behind other apps otherwise.
- **Swap:** main and alt exchange position and size. Each swap makes WoW re-render, so it takes a moment.
- **Front = active** when the alt covers the main (full size), so the window you control is always the visible one.
- **Window management only:** no input broadcasting, one key press = one action in one client.
- **Physical keys:** Ctrl/Win binds read physical key state, so they work alongside a script that swaps LWin/LCtrl. Start this script after such a script.
- **Safe and fast:** asynchronous window calls, no waiting on a frozen WoW, held keys throttled, toggles fire once per press.
- **Cleanup on exit:** no window left stuck on top; hover setting restored if changed.

## Keybinds

Ctrl / Win below refer to the author's swapped layout (physical LWin = Ctrl, physical LCtrl = Win).

| Group | Action | Keys |
|---|---|---|
| Windows | Launch missing instances + apply layout | Alt + F9 |
| Windows | Swap main / alt | Ctrl + Alt + Numpad6 |
| Windows | Alt always on top on/off | Ctrl + Numpad6 |
| Windows | Hover-activate on/off | Win + Numpad6 |
| Windows | Alt same size as main (again: back) | Alt + F7 |
| Windows | Alt to next screen (cycles, then back) | Ctrl + Alt + F7 |
| Move alt (WoW active) | 1 px / 10 px | Alt + Arrows / Alt + Shift + Arrows |
| Resize alt (WoW active) | ±1 px / ±10 px | Alt + Numpad+/− / Alt + Shift + Numpad+/− |
| Info | Help | Alt + F8 |
| Info | Alt position / size | Alt + F10 |
| Info | Debug | Ctrl + Alt + F10 |
| Info | Position / size check | Alt + F11 |
| Info | Auto re-apply layout on/off | Alt + F12 |

# WoW Dual Window Manager (AutoHotkey v2)

Runs two World of Warcraft clients as borderless windows: one large main window and one alt window, either in a corner of the main screen or on another screen. Swap, move, and resize them with hotkeys.

## Requirements

- Windows 10/11, [AutoHotkey v2](https://www.autohotkey.com/)
- WoW display mode: **Windowed** (not fullscreen / windowed fullscreen)

## Setup (CONFIG block)

| Setting | Meaning |
|---|---|
| `WowPath` | Path to `Wow.exe` |
| `MainX, MainY, MainW, MainH` | Main window position and size |
| `AltX, AltY, AltW, AltH` | Alt window in the corner of the main screen |
| `AltStartScreen` | `0` = corner layout, `1`, `2`, … = alt fills that other screen (counted left to right) |
| `OtherFill` | `true` = alt fills other screens, `false` = uses `OtherW` x `OtherH` |
| `OnTopOverAllApps` | `true` = alt stays above non-WoW apps too |

## Principles

- **Borderless:** title bar and border are removed from both WoW windows.
- **Main + alt:** alt is on top while WoW is active, behind other apps otherwise.
- **Multi-screen:** screens are detected automatically; the alt can start on any screen and cycle between them.
- **Swap:** main and alt exchange position and size. WoW re-renders after a resize, so a swap takes a moment (instant when both are the same size).
- **Front = active** when the alt covers the main, so the window you control is always the visible one.
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

## Contributors

- [ftkun](https://github.com/ftkun): author, design, testing
- Claude (Anthropic): code, review, testing

#Requires AutoHotkey v2.0
#SingleInstance Force
#HotIfTimeout 150                 ; Numpad6/F7/F10 never wait more than 150 ms on this script
ProcessSetPriority("High")        ; hotkeys stay responsive while 2 clients load the CPU
KeyHistory(0)                     ; no key logging overhead
ListLines(false)                  ; no line logging overhead
A_MaxHotkeysPerInterval := 1000   ; no "too many hotkeys" dialog when holding move/scale keys
SetWinDelay(-1)                   ; no 100 ms pause after window commands
CoordMode("ToolTip", "Screen")
DllCall("SetThreadDpiAwarenessContext", "Ptr", -4, "Ptr")   ; per-monitor DPI: exact pixels on both screens

; ===== CONFIG =====
WowPath     := "D:\World of Warcraft\_forever_\Wow.exe"
WowExe      := "Wow.exe"
StartDelay  := 4000    ; ms after launching before first layout
VerifyDelay := 1500    ; ms after layout before launch report

; Slot 1 = main (full 4K), Slot 2 = alt (small, bottom-right)
MainX := 0,    MainY := 0,    MainW := 3840, MainH := 2160
AltX  := 2583, AltY  := 1659, AltW  := 890,  AltH  := 501

AltMinW      := 320    ; smallest alt width
OtherFill := true                ; Ctrl+Alt+F7: alt fills each other screen (WQHD = 2560x1440)
OtherW := 2560, OtherH := 1440   ; used only if OtherFill := false (clamped to the screen)
MoveApplyMs  := 33     ; max alt move updates while key held (~30/s)
ScaleApplyMs := 100    ; max alt resize updates while key held (10/s, each resize = WoW re-render)

OnTopOverAllApps := false   ; true = alt-on-top ON also keeps alt above non-WoW apps
HOVER_DELAY_MS   := 0       ; hover-activate delay (0 = instant)
RAISE_WINDOW     := false   ; hover-activate also raises window

; Tooltip screen positions [x, y]
TipPos   := [10, 10]     ; short status tips
PosPos   := [10, 120]    ; Alt+F10
DebugPos := [10, 260]    ; Ctrl+Alt+F10
HelpPos  := [900, 260]   ; Alt+F8

; Alt-key hotkeys (Alt is not remapped by the rebind script)
KeyAltFull := "!F7"     ; alt same size as main (press again: back)
KeyHelp    := "!F8"
KeyLaunch  := "!F9"
KeyPos     := "!F10"
KeyInfo    := "!F11"
KeyEnforce := "!F12"
; Only while a WoW window is active:
KeyScale := Map("!NumpadAdd", 1, "!NumpadSub", -1, "!+NumpadAdd", 10, "!+NumpadSub", -10)
KeyMove  := Map("!Left", [-1, 0], "!Right", [1, 0], "!Up", [0, -1], "!Down", [0, 1]
              , "!+Left", [-10, 0], "!+Right", [10, 0], "!+Up", [0, -10], "!+Down", [0, 10])
; Ctrl/Win binds (Numpad6, Ctrl+Alt+F7, Ctrl+Alt+F10) are defined below with physical-key checks.
; ==================

wins := []              ; [mainHwnd, altHwnd]
enforce := false
launching := false
altTop := true          ; alt on top on/off (Ctrl+Numpad6)
altDirty := false, altThrottle := false, altThrottleMs := MoveApplyMs
altMode := "normal"     ; normal | full (Alt+F7) | other (Ctrl+Alt+F7)
altOtherIdx := 0        ; which other screen in the Ctrl+Alt+F7 cycle
altSaved := 0           ; alt layout before full/other, restored on second press
hoverTouched := false   ; hover setting restored on exit only if this script changed it

; Keyboard hook first in chain -> sees physical keys before the rebind script remaps them
InstallKeybdHook(true, true)

HoverOrig := HoverGet()   ; restored on exit

; Foreground change hook (skip own process)
FgCallback := CallbackCreate(OnForeground, , 7)
FgHook := DllCall("SetWinEventHook", "UInt", 3, "UInt", 3, "Ptr", 0, "Ptr", FgCallback
    , "UInt", 0, "UInt", 0, "UInt", 2, "Ptr")   ; EVENT_SYSTEM_FOREGROUND, OUTOFCONTEXT|SKIPOWNPROCESS

OnExit(OnScriptExit)

; Toggles fire once per key press (holding the key does not repeat them)
Hotkey(KeyAltFull, Once(() => AltModeToggle("full")))
Hotkey(KeyHelp,    Once(HelpToggle))
Hotkey(KeyLaunch,  Once(WowLaunch))
Hotkey(KeyPos,     Once(PosToggle))
Hotkey(KeyInfo,    Once(() => Tip(WowCheck(&ok), 4000)))
Hotkey(KeyEnforce, Once(WowToggleEnforce))

HotIf((*) => WowIsActive())
for k, d in KeyScale
    Hotkey(k, ScaleFn(d))
for k, d in KeyMove
    Hotkey(k, MoveFn(d[1], d[2]))
HotIf()

Housekeep()                    ; baseline
SetTimer(Housekeep, 1000)      ; closed-window check + hook priority recovery

if WowAdopt()
    WowApply()

; ---------- Ctrl / Win binds (your swapped keys) ----------
PAlt()     => GetKeyState("LAlt", "P") || GetKeyState("RAlt", "P")
PShift()   => GetKeyState("LShift", "P") || GetKeyState("RShift", "P")
PCtrlKey() => GetKeyState("LWin", "P")     ; your Ctrl = physical LWin
PWinKey()  => GetKeyState("LCtrl", "P")    ; your Win  = physical LCtrl
PhysCtrlAlt() => PCtrlKey() && PAlt() && !PWinKey() && !PShift()
PhysCtrl()    => PCtrlKey() && !PAlt() && !PWinKey() && !PShift()
PhysWin()     => PWinKey() && !PCtrlKey() && !PAlt() && !PShift()

; Path 1: physical keys (NumLock forced off -> physical Numpad6 = NumpadRight)
#HotIf PhysCtrlAlt()
*NumpadRight::OnceRun(WowSwap)
*F7::OnceRun(AltOtherCycle)
*F10::OnceRun(DebugToggle)
#HotIf PhysCtrl()
*NumpadRight::OnceRun(AltTopToggle)
#HotIf PhysWin()
*NumpadRight::OnceRun(HoverToggle)
#HotIf

; Path 2: logical keys from rebind script (requires "#InputLevel 1" there)
^!Numpad6::OnceRun(WowSwap)
^Numpad6::OnceRun(AltTopToggle)
#Numpad6::OnceRun(HoverToggle)
^!F7::OnceRun(AltOtherCycle)
^!F10::OnceRun(DebugToggle)

Once(fn) => (*) => OnceRun(fn)

OnceRun(fn) {
    ; Run action, then wait until the key is released: key auto-repeat cannot re-trigger it
    key := RegExReplace(A_ThisHotkey, "^[*~$!^+#<>]+")
    fn()
    Critical("Off")
    if key != ""
        KeyWait(key, "T3"), KeyWait(key, "L T3")
}

; ---------- Window helpers (no exceptions, no blocking) ----------
IsWin(h)     => h && DllCall("IsWindow", "Ptr", h)
IsMin(h)     => DllCall("IsIconic", "Ptr", h)
IsHung(h)    => DllCall("IsHungAppWindow", "Ptr", h)
Usable(h)    => IsWin(h) && !IsMin(h) && !IsHung(h)
WinLong(h, i) => DllCall(A_PtrSize = 8 ? "GetWindowLongPtr" : "GetWindowLong", "Ptr", h, "Int", i, "Ptr")
IsTopmost(h) => WinLong(h, -20) & 0x8
FgWin()      => DllCall("GetForegroundWindow", "Ptr")
AltCoversMain() => AltX <= MainX && AltY <= MainY && AltX + AltW >= MainX + MainW && AltY + AltH >= MainY + MainH
AltOnTop()   => altTop && !AltCoversMain()   ; alt covering main (Alt+F7 or max size): front = active window

Responsive(h, ms := 150) {
    ; True if the window answers within ms (never blocks longer)
    r := 0
    return DllCall("SendMessageTimeout", "Ptr", h, "UInt", 0, "Ptr", 0, "Ptr", 0
        , "UInt", 0x2, "UInt", ms, "Ptr*", &r)   ; WM_NULL, SMTO_ABORTIFHUNG
}

GetRect(h, &x, &y, &w, &hh) {
    rc := Buffer(16, 0)
    if !DllCall("GetWindowRect", "Ptr", h, "Ptr", rc)
        return false
    x := NumGet(rc, 0, "Int"), y := NumGet(rc, 4, "Int")
    w := NumGet(rc, 8, "Int") - x, hh := NumGet(rc, 12, "Int") - y
    return true
}

Area(h) => GetRect(h, &x, &y, &w, &hh) ? w * hh : 0

; Async SetWindowPos: z-order only (NOSIZE|NOMOVE|NOACTIVATE|ASYNCWINDOWPOS)
SWP(h, after) => DllCall("SetWindowPos", "Ptr", h, "Ptr", after
    , "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x4013)

; ---------- WoW ----------
WowTarget(slot) => slot = 1 ? [MainX, MainY, MainW, MainH] : [AltX, AltY, AltW, AltH]

AtTarget(h, slot) {
    t := WowTarget(slot)
    return GetRect(h, &x, &y, &w, &hh) && x = t[1] && y = t[2] && w = t[3] && hh = t[4]
}

WowIsActive(fg := 0) {
    if !fg
        fg := FgWin()
    return wins.Length = 2 && (fg = wins[1] || fg = wins[2])
}

WowAdopt() {
    ; Up to 2 visible WoW windows; larger one = main (keeps current layout after reload)
    global wins
    list := []
    for h in WinGetList("ahk_exe " WowExe)
        if list.Length < 2
            list.Push(h)
    if list.Length = 2 && Area(list[2]) > Area(list[1])
        list := [list[2], list[1]]
    wins := list
    return wins.Length = 2
}

WowLaunch() {
    global wins, launching
    if launching
        return
    launching := true
    launched := false
    try {
        WowAdopt()
        while wins.Length < 2 {
            try Run(WowPath, , , &pid)
            catch {
                MsgBox("Cannot start WoW. Check WowPath.")
                return
            }
            h := WinWait("ahk_pid " pid, , 90)
            if !h {
                MsgBox("WoW window not detected within 90 s.")
                return
            }
            wins.Push(h)
            launched := true
        }
        if launched
            Sleep(StartDelay)            ; only wait when something was started
    } finally {
        launching := false
    }
    WowApply()
    if launched
        Sleep(VerifyDelay)
    txt := WowCheck(&ok)
    Tip((ok ? "Layout applied`n" : "Layout reverted / incomplete`n") txt, 4000)
}

WowStrip(h) {
    ; Remove caption + sizing border if present. Returns true if changed.
    if !(WinLong(h, -16) & 0xC40000) || IsHung(h) || !Responsive(h)
        return false                       ; no title bar, or WoW busy: never wait on it
    try {
        WinSetStyle("-0xC40000", "ahk_id " h)
        return true
    }
    return false
}

ZAfter(slot, h) {
    ; z-order for SetWindowPos given current foreground ("keep" = leave z-order alone)
    fg := FgWin()
    main := wins.Length ? wins[1] : 0
    wowActive := WowIsActive(fg)
    if slot = 2 {
        if AltOnTop() && (wowActive || OnTopOverAllApps)
            return -1                    ; HWND_TOPMOST
        if fg = h
            return IsTopmost(h) ? -2 : 0 ; alt itself active: in front, not topmost
        if IsWin(main) && main != h
            return main                  ; directly below main, clears topmost
        return "keep"
    }
    return wowActive ? -2 : "keep"       ; HWND_NOTOPMOST while WoW active
}

WowPlace(h, slot, frame := false, after := "auto", sync := false) {
    ; One async call: position + size + z-order, no activation
    ; NOZORDER 0x4, NOACTIVATE 0x10, FRAMECHANGED 0x20, NOCOPYBITS 0x100, ASYNCWINDOWPOS 0x4000
    t := WowTarget(slot)
    flags := (sync ? 0x10 : 0x4010) | (frame ? 0x20 : 0)
    if GetRect(h, &x, &y, &w, &hh) && (w != t[3] || hh != t[4])
        flags |= 0x100                   ; size changes: skip copying old pixels
    if after = "auto"
        after := ZAfter(slot, h)
    if after = "keep"
        after := 0, flags |= 0x4
    DllCall("SetWindowPos", "Ptr", h, "Ptr", after
        , "Int", t[1], "Int", t[2], "Int", t[3], "Int", t[4], "UInt", flags)
}

WowApply() {
    for slot, h in wins
        if Usable(h)
            WowPlace(h, slot, WowStrip(h))
}

WowSwap() {
    global wins
    Critical
    if launching
        return
    if wins.Length < 2 || !IsWin(wins[1]) || !IsWin(wins[2])
        return Tip("WoW windows not tracked. Press Alt+F9.")
    if IsHung(wins[1]) || IsHung(wins[2])
        return Tip("WoW not responding. Swap skipped.")
    for h in wins
        if IsMin(h)
            DllCall("ShowWindowAsync", "Ptr", h, "Int", 4)   ; restore without activating
    tmp := wins[1], wins[1] := wins[2], wins[2] := tmp
    ; New main grows first (covers screen), then new alt shrinks into the corner
    WowPlace(wins[1], 1, false, -2)
    WowPlace(wins[2], 2, false, AltOnTop() ? -1 : wins[1])
    try WinActivate("ahk_id " wins[1])
    SetTimer(WowVerifyOnce, -500)
}

WowZOrder(fg) {
    if launching || !fg || wins.Length < 2 || !IsWin(wins[1]) || !IsWin(wins[2])
        return
    main := wins[1], alt := wins[2]
    wowActive := (fg = main || fg = alt)
    if !wowActive && IsTopmost(fg)
        return                           ; Start menu, Alt+Tab, other topmost apps: no change
    if AltOnTop() && (wowActive || OnTopOverAllApps) {
        if wowActive
            SWP(main, -2)
        SWP(alt, -1)
    } else if fg = alt {
        SWP(alt, -2), SWP(alt, 0)        ; alt itself active: clear topmost, bring to front
    } else if fg = main {
        SWP(alt, main)
    } else {
        SWP(alt, fg)                     ; behind the active app, clears topmost
    }
}

OnForeground(hHook, event, hwnd, idObject, idChild, thread, time) {
    Critical
    WowZOrder(hwnd)
}

ZRelease(h) {
    ; Clear topmost: stays visible over WoW if WoW is active, else goes behind the active app
    if !IsWin(h) || !IsTopmost(h)
        return
    fg := FgWin()
    if fg && fg != h && !IsTopmost(fg) && !WowIsActive(fg)
        SWP(h, fg)
    else
        SWP(h, -2)
}

AltTopToggle() {
    global altTop
    Critical
    altTop := !altTop
    WowZOrder(FgWin())
    if !AltOnTop() && wins.Length = 2
        ZRelease(wins[2])                ; also when a topmost app is in front
    Tip("Alt always on top: " (altTop ? "ON" : "OFF")
        . (AltCoversMain() ? "  (no effect while alt covers main)" : ""))
}

WowCheck(&ok) {
    ok := wins.Length = 2
    txt := wins.Length ? "" : "No WoW windows tracked. Press Alt+F9.`n"
    for slot, h in wins {
        if !IsWin(h) {
            txt .= slot ": missing`n", ok := false
            continue
        }
        if IsMin(h) {
            txt .= slot ": minimized`n"
            continue
        }
        GetRect(h, &x, &y, &w, &hh)
        t := WowTarget(slot)
        held := (x = t[1] && y = t[2] && w = t[3] && hh = t[4])
        if !held
            ok := false
        txt .= slot ": " x "," y " " w "x" hh "  target " t[1] "," t[2] " " t[3] "x" t[4]
             . (held ? "  OK" : "  REVERTED") "`n"
    }
    return RTrim(txt, "`n")
}

WowToggleEnforce() {
    global enforce
    enforce := !enforce
    SetTimer(WowEnforcer, enforce ? 1000 : 0)
    Tip("Auto re-apply: " (enforce ? "ON" : "OFF"))
}

WowEnforcer() {
    Critical
    if launching || altThrottle || wins.Length < 2
        return
    for slot, h in wins
        if Usable(h) && (!AtTarget(h, slot) || (WinLong(h, -16) & 0xC40000))
            WowPlace(h, slot, WowStrip(h))      ; drifted, or title bar came back
}

Housekeep() {
    global wins
    static ahkKnown := 0
    Critical
    ; 1) Tracked WoW window closed -> stop tracking, clear leftover topmost
    if !launching && wins.Length {
        for h in wins
            if !IsWin(h) {
                for h2 in wins
                    ZRelease(h2)
                wins := []
                Tip("WoW window closed. Press Alt+F9.")
                break
            }
    }
    ; 2) Another AutoHotkey script started or reloaded -> take keyboard hook priority back
    prevDHW := DetectHiddenWindows(true)
    list := WinGetList("ahk_class AutoHotkey")
    DetectHiddenWindows(prevDHW)       ; first call runs in auto-execute: must not change the default
    myPid := DllCall("GetCurrentProcessId")
    seen := Map(), newScript := false
    for h in list {
        pid := 0
        DllCall("GetWindowThreadProcessId", "Ptr", h, "UInt*", &pid)
        if pid = myPid
            continue
        seen[h] := true
        if IsObject(ahkKnown) && !ahkKnown.Has(h)
            newScript := true
    }
    ahkKnown := seen
    if newScript
        SetTimer(RetakeHook, -1500)
}

RetakeHook() {
    InstallKeybdHook(true, true)
    Tip("Keyboard hook priority restored", 1200)
}

; ---------- Alt scale / move ----------
ScaleFn(d) => (*) => AltScale(d)
MoveFn(dx, dy) => (*) => AltMove(dx, dy)

AltScale(d) {
    ; Width +-d px, height from main aspect ratio, bottom-right corner fixed, kept on its screen
    global AltX, AltY, AltW, AltH
    Critical
    if launching
        return
    m := AltBounds()
    wasCover := AltCoversMain()
    right := AltX + AltW, bottom := AltY + AltH
    maxW := Min(m[3] - m[1], (m[4] - m[2]) * MainW // MainH)
    w := Max(AltMinW, Min(maxW, AltW + d))
    h := Round(w * MainH / MainW)
    if w = AltW && h = AltH
        return Tip("Alt size: x=" w " y=" h "  (limit)", 1200)
    AltX := Max(m[1], Min(m[3] - w, right - w))
    AltY := Max(m[2], Min(m[4] - h, bottom - h))
    AltW := w, AltH := h
    AltRequestApply(ScaleApplyMs)
    if !wasCover && AltCoversMain() && wins.Length = 2 && Usable(wins[2])
        try WinActivate("ahk_id " wins[2])   ; just grew over main: show it (same as Alt+F7)
    Tip("Alt size: x=" w " y=" h, 1200)
}

AltMove(dx, dy) {
    ; Move alt, kept inside its current screen
    global AltX, AltY
    Critical
    if launching
        return
    m := AltBounds()
    x := Max(m[1], Min(m[3] - AltW, AltX + dx))
    y := Max(m[2], Min(m[4] - AltH, AltY + dy))
    if x = AltX && y = AltY
        return
    AltX := x, AltY := y
    AltRequestApply(MoveApplyMs)
    Tip("Alt position: x=" x " y=" y, 1200)
}

AltModeToggle(mode) {
    ; Alt+F7: alt = main size/position. Same key again: back to the layout before.
    global AltX, AltY, AltW, AltH, altMode, altSaved
    Critical
    if launching
        return
    if altMode = mode
        return AltRestore()
    if altMode = "normal"
        altSaved := [AltX, AltY, AltW, AltH]   ; keep the original layout across full <-> other
    AltX := MainX, AltY := MainY, AltW := MainW, AltH := MainH
    altMode := mode
    AltRequestApply(ScaleApplyMs)
    if wins.Length = 2 && Usable(wins[2])
        try WinActivate("ahk_id " wins[2])   ; same size: the active window is the visible one
    Tip("Alt = main size  x=" AltX " y=" AltY "  size x=" AltW " y=" AltH
        . "`nSwap switches the front window", 2000)
}

AltOtherCycle() {
    ; Ctrl+Alt+F7: each press = next other screen (left to right), after the last one: back
    global AltX, AltY, AltW, AltH, altMode, altSaved, altOtherIdx
    Critical
    if launching
        return
    others := OtherMonitors()
    if !others.Length
        return Tip("No other screen found.")
    next := altMode = "other" ? altOtherIdx + 1 : 1
    if next > others.Length
        return AltRestore()
    m := others[next]
    sw := m[3] - m[1], sh := m[4] - m[2]
    w := OtherFill ? sw : Min(OtherW, sw)
    h := OtherFill ? sh : Min(OtherH, sh)
    if altMode = "normal"
        altSaved := [AltX, AltY, AltW, AltH]
    AltX := m[1], AltY := m[2], AltW := w, AltH := h
    altMode := "other", altOtherIdx := next
    AltRequestApply(ScaleApplyMs)
    Tip("Alt -> other screen " next "/" others.Length "  x=" AltX " y=" AltY "  size x=" w " y=" h
        . (next = others.Length ? "`nNext press: back" : ""), 2000)
}

AltRestore() {
    global AltX, AltY, AltW, AltH, altMode, altSaved, altOtherIdx
    if IsObject(altSaved)
        AltX := altSaved[1], AltY := altSaved[2], AltW := altSaved[3], AltH := altSaved[4]
    altMode := "normal", altOtherIdx := 0
    AltRequestApply(ScaleApplyMs)
    Tip("Alt back: x=" AltX " y=" AltY "  size x=" AltW " y=" AltH, 1500)
}

AltBounds() {
    ; Screen containing the alt's center; falls back to the main screen
    cx := AltX + AltW // 2, cy := AltY + AltH // 2
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if cx >= l && cx < r && cy >= t && cy < b
            return [l, t, r, b]
    }
    return [MainX, MainY, MainX + MainW, MainY + MainH]
}

OtherMonitors() {
    ; All screens except the one with the main window, sorted left to right (then top to bottom)
    cx := MainX + MainW // 2, cy := MainY + MainH // 2
    list := []
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if cx >= l && cx < r && cy >= t && cy < b
            continue
        m := [l, t, r, b]
        ins := list.Length + 1
        while ins > 1 && (list[ins - 1][1] > l || (list[ins - 1][1] = l && list[ins - 1][2] > t))
            ins--
        list.InsertAt(ins, m)
    }
    return list
}

; Throttle: first press applies instantly, held key applies at most once per interval,
; last value always applied. Prevents a backlog of resizes inside WoW.
AltRequestApply(ms) {
    global altDirty, altThrottle, altThrottleMs
    altThrottleMs := ms
    if altThrottle {
        altDirty := true
        return
    }
    AltApplyNow()
    altThrottle := true
    SetTimer(AltThrottleTick, -ms)
}

AltThrottleTick() {
    global altDirty, altThrottle
    if altDirty {
        altDirty := false
        AltApplyNow()
        SetTimer(AltThrottleTick, -altThrottleMs)
    } else
        altThrottle := false
}

AltApplyNow() {
    if wins.Length = 2 && Usable(wins[2]) {
        WowPlace(wins[2], 2)
        SetTimer(WowVerifyOnce, -400)
    }
}

WowVerifyOnce() {
    ; One retry after swap / alt change: if an async move did not land, place it once more
    ; and wait for it (skipped while keys are held or if WoW is not responding)
    if altThrottle || launching || wins.Length < 2
        return
    for slot, h in wins
        if Usable(h) && !AtTarget(h, slot) && Responsive(h)
            WowPlace(h, slot, false, "auto", true)
}

; ---------- Hover focus ----------
HoverGet() {
    on := 0, t := 0, r := 0
    DllCall("SystemParametersInfo", "UInt", 0x1000, "UInt", 0, "Int*", &on, "UInt", 0)   ; ACTIVEWINDOWTRACKING
    DllCall("SystemParametersInfo", "UInt", 0x2002, "UInt", 0, "UInt*", &t, "UInt", 0)   ; ACTIVEWNDTRKTIMEOUT
    DllCall("SystemParametersInfo", "UInt", 0x100C, "UInt", 0, "Int*", &r, "UInt", 0)    ; ACTIVEWNDTRKZORDER
    return {on: on, timeout: t, raise: r}
}

HoverSet(on, timeout, raise) {
    ; fWinIni 1 = save, no WM_SETTINGCHANGE broadcast to every window
    DllCall("SystemParametersInfo", "UInt", 0x1001, "UInt", 0, "Ptr", on, "UInt", 1)
    DllCall("SystemParametersInfo", "UInt", 0x2003, "UInt", 0, "Ptr", timeout, "UInt", 1)
    DllCall("SystemParametersInfo", "UInt", 0x100D, "UInt", 0, "Ptr", raise, "UInt", 1)
}

HoverToggle() {
    global hoverTouched
    hoverTouched := true
    if HoverGet().on {
        DllCall("SystemParametersInfo", "UInt", 0x1001, "UInt", 0, "Ptr", 0, "UInt", 1)
        Tip("Hover-activate: OFF", 1200)
    } else {
        HoverSet(1, HOVER_DELAY_MS, RAISE_WINDOW)
        Tip("Hover-activate: ON", 1200)
    }
}

; ---------- Tooltips ----------
TT(id, text, pos) {
    ; Redraw only when text changed (no flicker, less work)
    static last := Map()
    if last.Has(id) && last[id] == text
        return
    last[id] := text
    if text = ""
        ToolTip(, , , id)
    else
        ToolTip(text, pos[1], pos[2], id)
}

Tip(msg, ms := 1500) {
    TT(1, msg, TipPos)
    SetTimer(TipClear, -ms)
}

TipClear() => TT(1, "", TipPos)

HelpToggle() {
    static on := false
    on := !on
    if !on
        return TT(4, "", HelpPos)
    TT(4, "HOTKEYS (Alt+F8 to close)   [Ctrl / Win = your swapped keys]`n"
        . "`n"
        . "WINDOWS`n"
        . "Alt+F9  -  launch missing instances + layout`n"
        . "Ctrl+Alt+Numpad6  -  swap main / alt`n"
        . "Ctrl+Numpad6  -  alt always on top on/off`n"
        . "Win+Numpad6  -  hover-activate on/off`n"
        . "Alt+F7  -  alt same size as main (again: back)`n"
        . "Ctrl+Alt+F7  -  alt to next screen (cycles, then back)`n"
        . "`n"
        . "MOVE ALT (WoW active)`n"
        . "Alt+Arrows  -  1 px`n"
        . "Alt+Shift+Arrows  -  10 px`n"
        . "`n"
        . "RESIZE ALT (WoW active)`n"
        . "Alt+Numpad+ / Alt+Numpad-  -  +1 / -1 px`n"
        . "Alt+Shift+Numpad+ / Alt+Shift+Numpad-  -  +10 / -10 px`n"
        . "`n"
        . "INFO`n"
        . "Alt+F8  -  this help on/off`n"
        . "Alt+F10  -  alt position / size on/off`n"
        . "Ctrl+Alt+F10  -  debug on/off`n"
        . "Alt+F11  -  position / size check`n"
        . "Alt+F12  -  auto re-apply on/off", HelpPos)
}

PosToggle() {
    static on := false
    on := !on
    SetTimer(PosShow, on ? 100 : 0)
    if on
        PosShow()
    else
        TT(3, "", PosPos)
}

PosShow() {
    txt := "Alt position: -`nAlt size: -"
    if wins.Length = 2 && IsWin(wins[2]) {
        h := wins[2]
        if IsMin(h)
            txt := "Alt position: minimized`nAlt size: minimized"
        else if GetRect(h, &x, &y, &w, &hh)
            txt := "Alt position: x=" x " y=" y "`nAlt size: x=" w " y=" hh
    }
    TT(3, txt, PosPos)
}

DebugToggle() {
    static on := false
    on := !on
    SetTimer(DebugShow, on ? 100 : 0)
    if on
        DebugShow()
    else
        TT(2, "", DebugPos)
}

DebugShow() {
    k(n) => n ": P=" GetKeyState(n, "P") " L=" GetKeyState(n)
    altNow := (wins.Length = 2 && IsWin(wins[2])) ? (IsTopmost(wins[2]) ? "yes" : "no") : "-"
    hv := HoverGet()
    TT(2, "DEBUG (Ctrl+Alt+F10 to close)`n"
        . k("LWin") "`n" k("LCtrl") "`n" k("LAlt") "`n"
        . k("NumpadRight") "`n" k("Numpad6") "`n"
        . "Last hotkey: " A_ThisHotkey "`n"
        . "Tracked WoW windows: " wins.Length "`n"
        . "WoW active: " (WowIsActive() ? "yes" : "no") "`n"
        . "Alt on top now: " altNow "   Alt-top setting: " (altTop ? "ON" : "OFF") "   Alt mode: " altMode (altMode = "other" ? " " altOtherIdx : "") (AltCoversMain() ? " (covers main)" : "") "`n"
        . PosLines(2, "Alt") "`n"
        . "Hover focus: " (hv.on ? "ON" : "OFF") "   delay: " hv.timeout " ms   raise: " (hv.raise ? "yes" : "no")
        , DebugPos)
}

PosLines(slot, name) {
    t := WowTarget(slot)
    tp := "(target x=" t[1] " y=" t[2] ")"
    ts := "(target x=" t[3] " y=" t[4] ")"
    if wins.Length < slot || !IsWin(wins[slot])
        return name " position: -  " tp "`n" name " size: -  " ts
    h := wins[slot]
    if IsMin(h)
        return name " position: minimized  " tp "`n" name " size: minimized  " ts
    GetRect(h, &x, &y, &w, &hh)
    return name " position: x=" x " y=" y "  " tp "`n"
         . name " size: x=" w " y=" hh "  " ts
}

; ---------- Exit ----------
OnScriptExit(*) {
    for h in wins
        ZRelease(h)                      ; no WoW window left stuck on top
    if hoverTouched
        HoverSet(HoverOrig.on, HoverOrig.timeout, HoverOrig.raise)
    DllCall("UnhookWinEvent", "Ptr", FgHook)
    CallbackFree(FgCallback)
    ; no return value -> exit proceeds
}

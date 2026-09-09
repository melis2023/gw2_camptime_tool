#Include RapidOcr.ahk
#Include ImagePut.ahk

; 全局变量
global usetime := 0
global starttime := 0
global hotkeyName := "F8"
CoordMode "ToolTip", "Screen"
; 函数定义
SaveHotkey(*) {
    global hotkeyName, config_file, hotkeyCtrl
    newKey := hotkeyCtrl.Value
    if (newKey != "") {
        ; 取消旧热键，注册新热键（实时生效，无需重开软件）
        try Hotkey hotkeyName, "Off"
        try Hotkey newKey, DoCapture
        hotkeyName := newKey
        IniWrite(newKey, config_file, "Settings", "Hotkey")
        ToolTip "热键已保存并生效：" newKey
        Sleep 1000
        ToolTip
    }
}

DoCapture(*) {
    global starttime, usetime, ScriptDir, image_file, myGui
    ; 锁定机制：当前激活窗口是设置界面时，热键不可用
    if WinActive("ahk_id " myGui.Hwnd)
        return
    fenzhong := 0
    miao := 0
    usetime := 0

    WinGetPos &winX, &winY, &winW, &winH, "A"
    MouseGetPos &mouseX, &mouseY

    ; 计算鼠标相对于窗口的位置
    relY := mouseY - winY
    if (relY < 10)  ; 防止负数或太小
        relY := 10

    x := Floor(winX + winW * 0.4)
    y := Floor(winY)
    w := (mousey - y) * 3  ; 宽度20%（中心左右各10%）
    h := (mousey - y) * 3  ; 高度10%
    if (w < 10)
        w := 10
    if (h < 10)
        h := 10
    ImagePutFile([x, y, w, h], image_file)

    ocr := RapidOcr({ models: ScriptDir "\models" }, ScriptDir "\64bit\RapidOcrOnnx.dll")
    res := ocr.ocr_from_file(image_file, , true)
    if (res) {
        loop res.Length {
            block := res[A_Index]
            text := block.text
            if (text != "") {
                if RegExMatch(text, "剩余时间") {
                    if (match := RegExMatch(text, "(\d+)分钟", &minutes)) {
                        fenzhong := minutes[1]
                    }
                    if (match := RegExMatch(text, "(\d+)秒", &clock)) {
                        miao := clock[1]
                    }
                }
            }
        }
    }
    usetime := fenzhong * 60 + miao
    ToolTip "识别到剩余时间: " fenzhong "分" miao "秒 (" usetime "秒)"
    if (usetime > 0) {
        starttime := A_TickCount
        SetTimer MyTimer, 1000
    } else {
        tooltip "未识别到有效时间！"
        Sleep 1000
        tooltip
    }
}

MyTimer() {
    global starttime, usetime
    remaining := usetime--
    ToolTip("剩余时间:" remaining "秒", A_ScreenWidth / 2, 20)
    if (remaining <= 0) {
        WinActivate("ahk_exe Gw2-64.exe")
        SetTimer(MyTimer, 0)
        tooltip
    }
}

; 主程序
ScriptDir := A_ScriptDir
config_file := ScriptDir . "\orc\config.ini"
image_file := ScriptDir . "\orc\image.png"
WinDelay := 0
KeyDelay := 0
KeyDuration := 0
ControlDelay := 0

; 读取配置的热键
if FileExist(config_file) {
    savedKey := IniRead(config_file, "Settings", "Hotkey", "F8")
    if (savedKey != "")
        hotkeyName := savedKey
}

; 创建 GUI（-SysMenu 移除右上角关闭按钮）
myGui := Gui("+Resize -SysMenu", "条子计时器")
myGui.OnEvent("Close", (*) => ExitApp())   ; Alt+F4 直接退出
myGui.MarginX := 12
myGui.MarginY := 10
myGui.SetFont("s10", "Microsoft YaHei")

; ── 标题区 ──
myGui.SetFont("s13 bold", "Microsoft YaHei")
myGui.Add("Text", "w360 Center", "条子计时器")
myGui.SetFont("s9", "Microsoft YaHei")
myGui.Add("Text", "w360 Center c4A4A4A", "GW2 监管员 · 义愤填膺倒计时")
myGui.Add("Text", "w360", "")

; ── 热键设置组 ──
myGui.Add("GroupBox", "w360 h82 Section", "热键设置")
myGui.Add("Text", "xs+16 ys+28", "启动热键：")
hotkeyCtrl := myGui.Add("Hotkey", "w140 x+8 yp", hotkeyName)
saveBtn := myGui.Add("Button", "w75 x+8 yp", "保存热键")
saveBtn.OnEvent("Click", SaveHotkey)
myGui.Add("Text", "xs+16 y+12 w330 c666666", "点击热键框后才可修改，其他情况不会改动热键")

; ── 使用说明组 ──
myGui.Add("GroupBox", "w360 h115 xm Section", "使用说明")
myGui.Add("Text", "xs+16 ys+26 w330", "1.  鼠标移动到监管员的义愤填膺图标")
myGui.Add("Text", "xs+16 y+10 w330", "2.  按下热键获取剩余时间，自动倒计时")
myGui.Add("Text", "xs+16 y+10 w330", "3.  ESC 退出计时  |  软件需保持常驻")

; ── 底部按钮 ──
myGui.SetFont("s10", "Microsoft YaHei")
myGui.Add("Button", "w100 y+18 xm+130", "退出软件").OnEvent("Click", (*) => ExitApp())
myGui.Show()
saveBtn.Focus()   ; 焦点移到保存按钮，避免 Hotkey 控件误捕获按键

; 动态注册热键
try Hotkey hotkeyName, DoCapture

~Esc:: {
    SetTimer(MyTimer, 0)
    tooltip
}


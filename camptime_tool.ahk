#Include RapidOcr.ahk
#Include ImagePut.ahk

; 全局变量
global usetime := 0
global starttime := 0
global hotkeyName := "F8"
global lastHotkey := "F8"  ; 上一次的热键
global rangeX := 25  ; X范围百分比（默认25 ↔ 乘数2.5）
global rangeY := 25  ; Y范围百分比（默认25 ↔ 乘数2.5）
global hotkeyGui := ""  ; 二级热键设置窗口
global hotkeyCtrl := ""  ; 热键控件引用
global hotkeyDisplay := ""  ; 热键显示文本控件
CoordMode "ToolTip", "Screen"

; 函数定义
ShowHotkeySettings(*) {
    global hotkeyName, hotkeyGui, hotkeyCtrl, hotkeyDisplay, config_file
    ; 如果窗口已打开，激活它
    if (hotkeyGui != "" && WinExist("ahk_id " hotkeyGui.Hwnd)) {
        WinActivate "ahk_id " hotkeyGui.Hwnd
        return
    }
    ; 创建二级窗口（与主窗口样式一致）
    hotkeyGui := Gui("+Owner" myGui.Hwnd, "热键设置")
    hotkeyGui.MarginX := 12
    hotkeyGui.MarginY := 10
    hotkeyGui.SetFont("s8", "Microsoft YaHei")
    hotkeyDisplay := hotkeyGui.Add("Text", "w260 Center", "当前热键：" hotkeyName)
    hotkeyGui.Add("Text", "w260 Center c666666", "点击下方框后按下新热键")
    hotkeyCtrl := hotkeyGui.Add("Hotkey", "w260", hotkeyName)
    saveBtn := hotkeyGui.Add("Button", "w120 y+8", "保存热键")
    saveBtn.OnEvent("Click", SaveHotkey)
    restoreBtn := hotkeyGui.Add("Button", "w120 x+12 yp", "恢复上次")
    restoreBtn.OnEvent("Click", RestoreHotkey)
    hotkeyGui.OnEvent("Close", (*) => (hotkeyGui := ""))
    hotkeyGui.Show()
    saveBtn.Focus()
}

SaveHotkey(*) {
    global hotkeyName, lastHotkey, config_file, hotkeyGui, hotkeyCtrl, hotkeyDisplay
    if (hotkeyGui == "")
        return
    newKey := hotkeyCtrl.Value
    if (newKey != "") {
        ; 记录上一次的热键
        lastHotkey := hotkeyName
        ; 取消旧热键，注册新热键（实时生效）
        try Hotkey hotkeyName, "Off"
        try Hotkey newKey, DoCapture
        hotkeyName := newKey
        IniWrite(newKey, config_file, "Settings", "Hotkey")
        ; 关闭二级窗口
        hotkeyGui.Destroy()
        hotkeyGui := ""
        ToolTip "热键已保存并生效：" newKey
        Sleep 1000
        ToolTip
    }
}

RestoreHotkey(*) {
    global hotkeyName, lastHotkey, config_file, hotkeyGui, hotkeyCtrl, hotkeyDisplay
    if (hotkeyGui == "")
        return
    ; 取消当前热键
    try Hotkey hotkeyName, "Off"
    ; 恢复到上一次的热键
    hotkeyName := lastHotkey
    hotkeyCtrl.Value := lastHotkey
    try Hotkey hotkeyName, DoCapture
    IniWrite(hotkeyName, config_file, "Settings", "Hotkey")
    ; 更新二级窗口的显示
    hotkeyDisplay.Value := "当前热键：" hotkeyName
    ToolTip "已恢复热键：" hotkeyName
    Sleep 1000
    ToolTip
}

SaveRange(*) {
    global rangeX, rangeY, config_file, rangeXCtrl, rangeYCtrl
    newX := rangeXCtrl.Value
    newY := rangeYCtrl.Value
    if (newX ~= "^\d+$" && newY ~= "^\d+$" && newX >= 1 && newX <= 500 && newY >= 1 && newY <= 500) {
        rangeX := Integer(newX)
        rangeY := Integer(newY)
        IniWrite(rangeX, config_file, "Settings", "RangeX")
        IniWrite(rangeY, config_file, "Settings", "RangeY")
        ToolTip "范围已保存并生效：X " rangeX "% / Y " rangeY "%"
        Sleep 1000
        ToolTip
    } else {
        ToolTip "范围需为 1-500 之间的整数！"
        Sleep 1000
        ToolTip
    }
}

DoCapture(*) {
    global starttime, usetime, ScriptDir, image_file, myGui, rangeX, rangeY
    ; 锁定机制：只有游戏窗口激活时才生效
    if !WinActive("ahk_exe Gw2-64.exe")
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
    w := Floor((mousey - y) * (rangeX / 10))  ; 宽度 = 鼠标距顶距离 × X范围(%)/10
    h := Floor((mousey - y) * (rangeY / 10))  ; 高度 = 鼠标距顶距离 × Y范围(%)/10
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
                    if (match := RegExMatch(text, "(\d+)分", &minutes)) {
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
config_file := ScriptDir . "\ocr\config.ini"
image_file := ScriptDir . "\ocr\image.png"
WinDelay := 0
KeyDelay := 0
KeyDuration := 0
ControlDelay := 0

; 删除旧版 orc 文件夹（如存在）初版命名错误
oldDir := ScriptDir . "\orc"
if FileExist(oldDir) {
    try DirDelete(oldDir, 1)
}

; 读取配置的热键与范围
if FileExist(config_file) {
    savedKey := IniRead(config_file, "Settings", "Hotkey", "F8")
    if (savedKey != "")
        hotkeyName := savedKey
    lastHotkey := hotkeyName
    rangeX := IniRead(config_file, "Settings", "RangeX", 25)
    rangeY := IniRead(config_file, "Settings", "RangeY", 25)
}

; 创建 GUI（-SysMenu 移除右上角关闭按钮）
myGui := Gui("+Resize -SysMenu", "条子计时器")
myGui.OnEvent("Close", (*) => ExitApp())   ; Alt+F4 直接退出
myGui.MarginX := 12
myGui.MarginY := 10
myGui.SetFont("s10", "Microsoft YaHei")

; ── 标题区 ──
myGui.SetFont("s12 bold", "Microsoft YaHei")
myGui.Add("Text", "w360 Center", "条子计时器")
myGui.SetFont("s8", "Microsoft YaHei")
myGui.Add("Text", "w360 Center c4A4A4A", "GW2 监管员 · 义愤填膺倒计时")

; ── 使用说明组 ──
myGui.Add("GroupBox", "w360 h60 xm Section", "使用说明")
myGui.Add("Text", "xs+16 ys+20 w330", "鼠标移到义愤填膺图标 → 按热键自动倒计时 | ESC 停止计时")

; ── 截图范围设置组 ──
myGui.Add("GroupBox", "w360 h65 xm Section", "截图范围设置")
myGui.Add("Text", "xs+16 ys+22", "X 范围 (%):")
rangeXCtrl := myGui.Add("Edit", "w50 x+8 yp-3 Number", rangeX)
myGui.Add("Text", "x+12 yp+3", "Y 范围 (%):")
rangeYCtrl := myGui.Add("Edit", "w50 x+8 yp-3 Number", rangeY)
rangeSaveBtn := myGui.Add("Button", "w70 x+16 yp-1", "保存范围")
rangeSaveBtn.OnEvent("Click", SaveRange)
myGui.Add("Text", "xs+16 y+6 w330 c666666", "默认 25%，范围越大截图区域越大，该窗口需常驻，不要关闭")

; ── 底部按钮 ──
myGui.SetFont("s10", "Microsoft YaHei")
hotkeyBtn := myGui.Add("Button", "w100 y+12 xm+20", "设置热键")
hotkeyBtn.OnEvent("Click", ShowHotkeySettings)
exitBtn := myGui.Add("Button", "w100 x+20 yp", "退出软件")
exitBtn.OnEvent("Click", (*) => ExitApp())
myGui.Show()

; 动态注册热键
try Hotkey hotkeyName, DoCapture

~Esc:: {
    SetTimer(MyTimer, 0)
    tooltip
}


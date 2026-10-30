import Cocoa
import Darwin

enum Preferences {
    static func value(_ key: String, domain: String) -> Any? {
        CFPreferencesCopyAppValue(key as CFString, domain as CFString)
    }
    static func file(_ url: URL) -> [String: Any] {
        guard let data = try? Data(contentsOf: url), let p = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { return [:] }
        return p
    }
    static func domain(_ name: String) -> [String: Any] {
        file(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/\(name).plist"))
    }
}

struct SystemAction {
    let id: Int32
    let title: String
    let category: String
}

enum SystemReader {
    // IDs are stable macOS symbolic actions, not guessed from their current key combinations.
    static let actions: [SystemAction] = [
        .init(id:28,title:"将整个屏幕存储为图片",category:"截屏"),.init(id:29,title:"将整个屏幕复制到剪贴板",category:"截屏"),.init(id:30,title:"将所选区域存储为图片",category:"截屏"),.init(id:31,title:"将所选区域复制到剪贴板",category:"截屏"),.init(id:184,title:"打开截屏与录屏工具",category:"截屏"),
        .init(id:64,title:"显示聚焦搜索",category:"搜索与输入法"),.init(id:65,title:"显示访达搜索窗口",category:"搜索与输入法"),.init(id:60,title:"选择上一个输入法",category:"搜索与输入法"),.init(id:61,title:"选择输入法菜单中的下一个输入法",category:"搜索与输入法"),.init(id:50,title:"显示表情与符号",category:"搜索与输入法"),
        .init(id:32,title:"调度中心",category:"桌面与窗口"),.init(id:33,title:"应用程序窗口",category:"桌面与窗口"),.init(id:36,title:"显示桌面",category:"桌面与窗口"),.init(id:79,title:"向左移动一个空间",category:"桌面与窗口"),.init(id:81,title:"向右移动一个空间",category:"桌面与窗口"),.init(id:52,title:"显示或隐藏程序坞",category:"桌面与窗口"),.init(id:27,title:"切换同一应用的窗口",category:"桌面与窗口"),
        .init(id:7,title:"将焦点移到菜单栏",category:"键盘导航"),.init(id:8,title:"将焦点移到程序坞",category:"键盘导航"),.init(id:9,title:"将焦点移到下一个窗口",category:"键盘导航"),.init(id:10,title:"将焦点移到工具栏",category:"键盘导航"),.init(id:11,title:"将焦点移到浮动窗口",category:"键盘导航"),.init(id:12,title:"打开或关闭键盘访问",category:"键盘导航"),.init(id:13,title:"更改 Tab 的焦点移动方式",category:"键盘导航"),.init(id:57,title:"将焦点移到状态菜单",category:"键盘导航"),
        .init(id:15,title:"打开或关闭缩放",category:"辅助功能"),.init(id:17,title:"放大",category:"辅助功能"),.init(id:19,title:"缩小",category:"辅助功能"),.init(id:21,title:"反转颜色",category:"辅助功能"),.init(id:22,title:"打开或关闭图像平滑",category:"辅助功能"),.init(id:23,title:"增强对比度",category:"辅助功能"),.init(id:25,title:"降低对比度",category:"辅助功能"),.init(id:59,title:"打开或关闭旁白",category:"辅助功能")
    ] + (1...9).map { .init(id: Int32(117+$0), title:"切换到桌面 \($0)", category:"桌面与窗口") }

    typealias GetBinding = @convention(c) (Int32, UnsafeMutablePointer<UInt16>, UnsafeMutablePointer<UInt16>, UnsafeMutablePointer<UInt32>) -> Int32
    typealias IsEnabled = @convention(c) (Int32) -> Bool

    static func scan() -> ScanResult {
        var result = ScanResult()
        let saved = Preferences.value("AppleSymbolicHotKeys", domain:"com.apple.symbolichotkeys") as? [String: [String: Any]] ?? [:]
        let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
        defer { if let handle { dlclose(handle) } }
        let getter = handle.flatMap { dlsym($0,"CGSGetSymbolicHotKeyValue") }.map { unsafeBitCast($0, to:GetBinding.self) }
        let enabled = handle.flatMap { dlsym($0,"CGSIsSymbolicHotKeyEnabled") }.map { unsafeBitCast($0, to:IsEnabled.self) }
        let known = Set(actions.map { String($0.id) })
        let extra = saved.keys.filter { !known.contains($0) }.compactMap { key -> SystemAction? in
            guard let id = Int32(key) else { return nil }
            return .init(id:id,title: id == 164 ? "听写触发键" : "系统动作 #\(id)",category: id == 164 ? "Fn 与听写" : "其他系统设置")
        }.sorted { $0.id < $1.id }
        for action in actions + extra {
            var character: UInt16 = 65535, code: UInt16 = 65535, flags: UInt32 = 0
            let status = getter?(action.id, &character, &code, &flags) ?? -1
            let persisted = saved[String(action.id)]
            var chord: KeyChord?
            var active = (persisted?["enabled"] as? NSNumber)?.boolValue ?? false
            var evidence = "已保存配置"
            if status == 0, let enabled {
                active = enabled(action.id)
                evidence = "系统当前配置"
                if code != 65535 && !(code == 0 && character == 65535) {
                    chord = .cocoa(code:Int(code), flags:UInt64(flags))
                }
            } else if let value = persisted?["value"] as? [String: Any], let params = value["parameters"] as? [NSNumber] {
                if value["type"] as? String == "standard", params.count >= 3, params[1].intValue != 65535 {
                    chord = .cocoa(code:params[1].intValue, flags:params[2].uint64Value)
                } else if value["type"] as? String == "modifier", let mask = params.first {
                    // This is a modifier trigger, not a normal virtual keycode.
                    let tokens = KeyChord.cocoa(code:65535, flags:mask.uint64Value).modifiers
                    if !tokens.isEmpty { chord = KeyChord(key:"",modifiers:tokens,trigger:"修饰键触发") }
                }
            } else if persisted == nil { continue }
            let note = "\(evidence) · 系统编号 \(action.id)。按键按 ANSI 键位显示。fn 标记按系统原始配置保留，部分机型不需要额外按下 fn。仅显示配置，不能证明某个应用拦截了按键。"
            result.shortcuts.append(Shortcut(id:"system.\(action.id)",title:action.title,source:"macOS",bundleID:"system",category:action.category,chord:chord,enabled:active,scope:"global",origin:.system,detail:note,location:"系统设置 → 键盘 → 键盘快捷键"))
        }
        let fn = (Preferences.value("AppleFnUsageType",domain:"com.apple.HIToolbox") as? NSNumber)?.intValue
        result.fnAction = [0:"不执行任何操作",1:"更改输入法",2:"显示表情与符号",3:"开始听写"][fn ?? -1] ?? "未读到明确配置"
        let dictation = (Preferences.value("Dictation Enabled",domain:"com.apple.assistant.support") as? NSNumber)?.boolValue
        result.dictation = dictation.map { $0 ? "已开启" : "已关闭" } ?? "未读到明确配置"
        let standardF = (CFPreferencesCopyValue("com.apple.keyboard.fnState" as CFString,kCFPreferencesAnyApplication,kCFPreferencesCurrentUser,kCFPreferencesAnyHost) as? NSNumber)?.boolValue
        result.functionKeys = standardF.map { $0 ? "标准 F1、F2… 功能键" : "亮度、音量等系统控制" } ?? "未读到明确配置"
        if dictation == false, let i = result.shortcuts.firstIndex(where: { $0.id == "system.164" }) {
            result.shortcuts[i].enabled = false
            result.shortcuts[i].detail += " 当前系统听写已关闭，因此此触发键不会启动听写。"
        }
        result.coverage.append(Coverage(id:"system",title:"macOS 系统快捷键",count:result.shortcuts.count,status:getter == nil ? "部分读取" : "已读取",detail:"读取已识别的系统动作与保存的自定义项；未知动作保留编号。新版本系统可能增加未识别的动作。"))
        return result
    }
}

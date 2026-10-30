import Cocoa

enum AppReader {
    static func canReadPreferenceDomain(_ domain: String) -> Bool {
        // Reading Music/TV/Safari preference files can itself trigger TCC prompts.
        // Do not touch protected Apple app data; menus remain an optional alternative.
        !domain.hasPrefix("com.apple.") && domain != "com.local.keyatlas"
    }
    static func installedApps() -> [String: String] {
        var apps: [String: String] = [:]
        let roots = ["/Applications","/System/Applications","/Library/Input Methods",FileManager.default.homeDirectoryForCurrentUser.path + "/Applications"]
        for root in roots {
            guard let files = FileManager.default.enumerator(at:URL(fileURLWithPath:root),includingPropertiesForKeys:nil,options:[.skipsHiddenFiles]) else { continue }
            for case let url as URL in files {
                if url.pathExtension == "app" {
                    if let bundle = Bundle(url:url), let id = bundle.bundleIdentifier {
                        apps[id] = bundle.object(forInfoDictionaryKey:"CFBundleDisplayName") as? String ?? url.deletingPathExtension().lastPathComponent
                    }
                    files.skipDescendants()
                } else if files.level > 2 { files.skipDescendants() }
            }
        }
        return apps
    }

    static func parsePreference(_ key: String, value: Any, domain: String, name: String) -> Shortcut? {
        var data: [String: Any]?
        var origin = ""
        if key.hasPrefix("KeyboardShortcuts_") {
            if let raw = value as? String, let bytes = raw.data(using:.utf8) { data = (try? JSONSerialization.jsonObject(with:bytes)) as? [String:Any] }
            else { data = value as? [String:Any] }
            origin = "KeyboardShortcuts 配置"
        } else if key.localizedCaseInsensitiveContains("shortcut") || key.localizedCaseInsensitiveContains("hotkey") || domain == "com.knollsoft.Rectangle" {
            data = value as? [String:Any]
            origin = "已保存的快捷键配置"
        }
        guard let d = data else { return nil }
        var chord: KeyChord?
        if let code = d["carbonKeyCode"] as? NSNumber, let flags = d["carbonModifiers"] as? NSNumber, code.intValue >= 0 {
            chord = .carbon(code:code.intValue,flags:flags.uint64Value)
        } else if let code = (d["keyCode"] ?? d["key"]) as? NSNumber, let flags = (d["modifierFlags"] ?? d["modifiers"]) as? NSNumber, code.intValue >= 0 {
            chord = .cocoa(code:code.intValue,flags:flags.uint64Value)
        }
        guard chord != nil else { return nil }
        let title = key.replacingOccurrences(of:"KeyboardShortcuts_",with:"")
        let named: [String:String] = ["toggleLauncher":"打开快捷窗口","toggleAttachedLauncher":"打开附属快捷窗口","openSettings":"打开设置","leftHalf":"左半屏","rightHalf":"右半屏","maximize":"最大化窗口","center":"居中窗口","nextDisplay":"移到下一显示器"]
        return Shortcut(id:"pref.\(domain).\(key)",title:named[title] ?? title,source:name,bundleID:domain,category:"应用快捷键",chord:chord,enabled:(d["enabled"] as? NSNumber)?.boolValue ?? true,scope:domain == "com.knollsoft.Rectangle" ? "global" : "unknown",origin:.preference,detail:"\(origin)。应用可能另有开关或运行条件；未能从配置判断作用范围时，不参与重复组合检查。",location:"\(domain) → \(key)")
    }

    static func authorizedPreferences(_ url: URL,domain: String,access: AccessSnapshot,read: (URL) -> [String:Any] = Preferences.file) -> [String:Any] {
        guard access.allows(domain,.preferences),canReadPreferenceDomain(domain) else {return [:]}
        let result = read(url)
        return access.allows(domain,.preferences) ? result : [:]
    }

    static func scan(access: AccessSnapshot) -> ScanResult {
        var result = ScanResult()
        let apps = installedApps()
        let prefs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences")
        var customCount = 0
        let global = Preferences.value("NSUserKeyEquivalents",domain:kCFPreferencesAnyApplication as String) as? [String:String] ?? Preferences.domain(".GlobalPreferences")["NSUserKeyEquivalents"] as? [String:String] ?? [:]
        func appendMenus(_ dictionary: [String:String], domain: String, name: String) {
            for (title, value) in dictionary.sorted(by: { $0.key < $1.key }) {
                guard let chord = KeyChord.menuEquivalent(value) else { continue }
                customCount += 1
                result.shortcuts.append(Shortcut(id:"custom.\(domain).\(title)",title:title,source:name,bundleID:domain,category:"自定义菜单快捷键",chord:chord,enabled:true,scope:"app",origin:.preference,detail:"读取自 macOS 的 App 快捷键设置。只有应用存在同名菜单命令时才会生效。所有应用的菜单配置不等同于全局热键。",location:"系统设置 → 键盘 → 键盘快捷键 → App 快捷键"))
            }
        }
        appendMenus(global,domain:"all-app-menus",name:"所有应用的菜单")
        for domain in apps.keys.sorted() where access.allows(domain,.preferences) {
            guard !domain.contains("/") else {continue}
            let url = prefs.appendingPathComponent(domain + ".plist")
            guard access.allows(domain,.preferences), canReadPreferenceDomain(domain), apps[domain] != nil,
                  let info = try? url.resourceValues(forKeys:[.fileSizeKey,.isRegularFileKey,.isSymbolicLinkKey]),
                  info.isRegularFile == true, info.isSymbolicLink != true, let size = info.fileSize, size < 4_000_000 else { continue }
            // Only inspect known preference fields. Never read application content or credentials.
            guard access.allows(domain,.preferences) else {continue}
            let d = authorizedPreferences(url,domain:domain,access:access)
            guard access.allows(domain,.preferences) else {continue}
            let name = apps[domain] ?? domain
            if let menus = d["NSUserKeyEquivalents"] as? [String:String] { appendMenus(menus,domain:domain,name:name) }
            guard apps[domain] != nil else { continue }
            for (key,value) in d {
                if let item = parsePreference(key,value:value,domain:domain,name:name) { result.shortcuts.append(item) }
            }
        }
        let services = Preferences.value("NSServicesStatus",domain:"pbs") as? [String:[String:Any]] ?? [:]
        for (id, value) in services {
            guard let equivalents = value["key_equivalent"] as? [String:String], let raw = equivalents["default"], let chord = KeyChord.menuEquivalent(raw) else { continue }
            result.shortcuts.append(Shortcut(id:"service.\(id)",title:id.components(separatedBy:" - ").last ?? id,source:"系统服务",bundleID:"services",category:"服务",chord:chord,enabled:!(value["presentation_modes"] as? [String:Bool] ?? [:]).values.contains(false),scope:"app",origin:.preference,detail:"系统服务的已保存快捷键；是否可用取决于当前选区和应用。",location:"系统设置 → 键盘 → 键盘快捷键 → 服务"))
        }
        result.coverage.append(.init(id:"custom",title:"App 自定义快捷键与服务",count:customCount + result.shortcuts.filter { $0.bundleID == "services" }.count,status:"部分读取",detail:"读取系统保存的共用菜单设置、系统服务及已授权的第三方应用配置。跳过 Apple 应用的受保护偏好文件，可用菜单扫描补充；零条不表示没有默认快捷键。"))
        result.coverage.append(.init(id:"prefs",title:"可识别的应用配置",count:result.shortcuts.filter { $0.category == "应用快捷键" }.count,status:"部分支持",detail:"支持 KeyboardShortcuts、部分 ShortcutRecorder / MASShortcut 配置。仅读取你逐个授权的应用，展示实际保存的条目，不猜测默认值。"))
        for (id, name) in [("com.bytedance.inputmethod.doubaoime","豆包输入法"),("com.raycast.macos","Raycast"),("com.bot.pc.doubao","豆包") ] where apps[id] != nil && access.grants[id] != nil {
            result.coverage.append(.init(id:id,title:name,count:result.shortcuts.filter { $0.bundleID == id }.count,status:"需读取设置页",detail:"配置格式未完整支持。豆包输入法与 Raycast 可在“应用授权”中单独读取已打开的设置页；菜单无法覆盖长按 Fn 等隐藏热键。"))
        }
        result.shortcuts = result.shortcuts.filter {access.permits($0)}
        return result
    }
}

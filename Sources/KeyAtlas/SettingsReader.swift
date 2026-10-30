import Cocoa
import ApplicationServices

struct SettingsText {
    let role: String
    let text: String
}

enum SettingsReader {
    static let doubao = "com.bytedance.inputmethod.doubaoime"
    static let raycast = "com.raycast.macos"
    static func supports(_ id: String) -> Bool {[doubao,raycast].contains(id)}
    static func instructions(_ id: String) -> String {
        id == doubao ? "打开豆包输入法设置 → 语音输入，保持该页打开后点击读取。支持长按和免按模式；跨输入法开关仍需你在原应用确认。" : "在 Raycast 按 ⌘ , 打开 Settings。General 页可读取启动快捷键；Extensions / Shortcuts 页尝试读取界面暴露的已设置组合。折叠、未加载或未公开的项目不会被计入。"
    }
    static func chord(_ raw: String, trigger: String = "按下") -> KeyChord? {
        var text = raw.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 45 else {return nil}
        let replacements = [("Right Option","右⌥"),("Left Option","左⌥"),("Right Command","右⌘"),("Left Command","左⌘"),("Option","⌥"),("Command","⌘"),("Control","⌃"),("Shift","⇧"),("Globe","fn"),("Fn","fn"),("🌐","fn"),("Space","空格"),("Return","↩"),("Enter","↩"),("Escape","⎋"),("Tab","⇥"),("Delete","⌫")]
        for (a,b) in replacements {text = text.replacingOccurrences(of:a,with:b)}
        text = text.replacingOccurrences(of:" ",with:"").replacingOccurrences(of:"+",with:"")
        var mods: [String] = []
        for token in ["右⌃","左⌃","右⌥","左⌥","右⇧","左⇧","右⌘","左⌘","fn","⌃","⌥","⇧","⌘"] {
            if text.contains(token) {mods.append(token.count > 1 && token != "fn" ? String(token.prefix(1)) + " " + String(token.suffix(1)) : token);text = text.replacingOccurrences(of:token,with:"")}
        }
        let special = ["空格","↩","⎋","⇥","⌫","↑","↓","←","→","Home","End","PageUp","PageDown"]
        let function = text.range(of:"^F([1-9]|1[0-9]|2[0-4])$",options:.regularExpression) != nil
        guard text.isEmpty ? !mods.isEmpty : (special.contains(text) || function || (text.count == 1 && !mods.isEmpty)) else {return nil}
        return KeyChord(key:text,modifiers:mods,trigger:trigger)
    }
    static func parse(_ nodes: [SettingsText], bundleID: String) -> [Shortcut] {
        var items: [Shortcut] = []
        func append(_ title: String,_ raw: String,_ trigger: String = "按下",global: Bool = false) {
            guard let keys = chord(raw,trigger:trigger) else {return}
            items.append(Shortcut(id:"settings.\(bundleID).\(title)",title:title,source:bundleID == doubao ? "豆包输入法" : "Raycast",bundleID:bundleID,category:"设置页快捷键",chord:keys,enabled:nil,scope:global ? "global" : "unknown",origin:.settings,detail:"读取于 \(Date().formatted(date:.omitted,time:.shortened))，来自已打开的设置页。只说明该组合已设置；不会推断未公开的开关、权限或运行状态。刷新配置后需重新读取。",location:bundleID == doubao ? "豆包输入法 → 语音输入" : "Raycast → Settings",condition:bundleID == doubao ? "跨输入法唤起及辅助功能权限需在原应用确认。" : "仅覆盖本次设置页暴露的项目。"))
        }
        func capture(_ pattern: String,_ text: String) -> String? {
            guard let regex = try? NSRegularExpression(pattern:pattern), let match = regex.firstMatch(in:text,range:NSRange(text.startIndex...,in:text)),let range = Range(match.range(at:1),in:text) else {return nil};return String(text[range])
        }
        if bundleID == doubao {
            for node in nodes where node.role == kAXStaticTextRole {
                if let raw = capture("长按模式[\\s\\S]*?松手结束\\s*([^\\n]+)$",node.text) {append("按住说话",raw,"长按")}
                if let raw = capture("免按模式[\\s\\S]*?再按任意键可结束\\s*(.+?)(?:麦克风选择|$)",node.text) {append("免按说话",raw)}
            }
        } else if bundleID == raycast {
            for node in nodes {
                if node.role == kAXStaticTextRole, let raw = capture("Raycast Hotkey\\s+([^\\n]+)$",node.text) {append("打开 Raycast",raw,global:true)}
                if node.role == kAXRowRole {
                    let lines = node.text.components(separatedBy:.newlines).map {$0.trimmingCharacters(in:.whitespaces)}.filter {!$0.isEmpty}
                    guard !lines.contains("Record Hotkey"),let keys = lines.first(where:{chord($0) != nil}),let title = lines.first(where:{$0 != keys && !["Command","Extension","AI Extension","Group","--"].contains($0)}),!title.contains("Hotkey") else {continue}
                    append(title,keys)
                }
            }
        }
        var ids = Set<String>();return items.filter {ids.insert($0.id).inserted}
    }
    static func scan(bundleID: String, access: AccessSnapshot) -> ScanResult {
        var result = ScanResult()
        func status(_ state: String,_ detail: String) {
            result.coverage = [.init(id:"settings.\(bundleID)",title:bundleID == doubao ? "豆包输入法设置页" : "Raycast 设置页",count:result.shortcuts.count,status:state,detail:detail)]
        }
        guard supports(bundleID),access.allows(bundleID,.settings) else {status("未授权","请先允许此应用的设置页读取。");return result}
        guard AXIsProcessTrusted() else {status("需辅助功能权限","在系统设置中允许键览使用辅助功能后，再点击读取。");return result}
        let targetID = bundleID == doubao ? "com.bytedance.inputmethod.doubaoime.settings" : bundleID
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier:targetID).first else {status("请打开设置",instructions(bundleID));return result}
        let deadline = Date().addingTimeInterval(5)
        var count = 0
        func attribute(_ node: AXUIElement,_ key: String) -> Any? {
            guard access.allows(bundleID,.settings),Date() < deadline else {return nil}
            AXUIElementSetMessagingTimeout(node,0.12)
            var value: CFTypeRef?
            return AXUIElementCopyAttributeValue(node,key as CFString,&value) == .success ? value : nil
        }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        let windows = attribute(appElement,kAXWindowsAttribute) as? [AXUIElement] ?? []
        var nodes: [SettingsText] = []
        func walk(_ node: AXUIElement,_ depth: Int) {
            guard depth < 16,count < 900,Date() < deadline,access.allows(bundleID,.settings) else {return}
            count += 1
            let role = attribute(node,kAXRoleAttribute) as? String ?? ""
            // Never inspect editable fields (including search, account, and other text input).
            if [kAXTextFieldRole,kAXTextAreaRole].contains(role) {return}
            if [kAXStaticTextRole,kAXRowRole].contains(role) {
                let title = attribute(node,kAXTitleAttribute) as? String ?? ""
                let value = attribute(node,kAXValueAttribute) as? String ?? ""
                nodes.append(SettingsText(role:role,text:title == value || title.isEmpty ? value : value.isEmpty ? title : title + "\n" + value))
            }
            for child in attribute(node,kAXChildrenAttribute) as? [AXUIElement] ?? [] {walk(child,depth+1)}
        }
        for window in windows {
            let title = attribute(window,kAXTitleAttribute) as? String ?? ""
            // Doubao's dedicated settings helper has an untitled settings window.
            guard bundleID == doubao || ["Settings","Raycast Settings","Preferences","设置","偏好设置"].contains(title) else {continue}
            walk(window,0)
        }
        guard access.allows(bundleID,.settings) else {return ScanResult()}
        result.shortcuts = parse(nodes,bundleID:bundleID)
        status(result.shortcuts.isEmpty ? "未识别到组合" : "部分读取",result.shortcuts.isEmpty ? "当前页没有可识别的已设置组合；不代表应用没有快捷键。\(instructions(bundleID))" : "仅包含当前设置页可访问的快捷键，未显示的项目和未公开的开关无法确认。\(instructions(bundleID))")
        return result
    }
}

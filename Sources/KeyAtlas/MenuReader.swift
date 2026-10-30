import Cocoa
import ApplicationServices

enum MenuReader {
    static func scan(access: AccessSnapshot) -> ScanResult {
        var result = ScanResult()
        guard AXIsProcessTrusted() else {
            result.coverage.append(.init(id:"menus",title:"运行中应用的菜单",count:0,status:"未授权",detail:"可选：在辅助功能中允许键览读取菜单。基础的系统和应用配置读取不需要此权限。")); return result
        }
        let start = Date()
        var partial = false
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && app.bundleIdentifier != Bundle.main.bundleIdentifier {
            if Date().timeIntervalSince(start) > 15 { partial = true; break }
            guard let bundleID = app.bundleIdentifier, access.allows(bundleID,.menus) else {continue}
            let element = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(element,0.15)
            let deadline = Date().addingTimeInterval(1.3)
            var nodes = 0
            func attribute(_ node: AXUIElement, _ key: String) -> Any? {
                guard access.allows(bundleID,.menus), Date() < deadline else { partial = true; return nil }
                AXUIElementSetMessagingTimeout(node,0.15)
                var value: CFTypeRef?
                return AXUIElementCopyAttributeValue(node,key as CFString,&value) == .success ? value : nil
            }
            func walk(_ node: AXUIElement, path: [String], depth: Int) {
                guard access.allows(bundleID,.menus), depth < 8, nodes < 500, Date() < deadline else { partial = true; return }
                nodes += 1
                let title = attribute(node,kAXTitleAttribute) as? String ?? ""
                let next = title.isEmpty ? path : path + [title]
                let rawKey = attribute(node,kAXMenuItemCmdCharAttribute) as? String ?? ""
                if !title.isEmpty && !rawKey.isEmpty {
                    let flags = (attribute(node,kAXMenuItemCmdModifiersAttribute) as? NSNumber)?.intValue ?? 0
                    var mods: [String] = []
                    if flags & 4 != 0 { mods.append("⌃") }
                    if flags & 2 != 0 { mods.append("⌥") }
                    if flags & 1 != 0 { mods.append("⇧") }
                    if flags & 8 == 0 { mods.append("⌘") }
                    let id = app.bundleIdentifier ?? "pid.\(app.processIdentifier)"
                    result.shortcuts.append(Shortcut(id:"menu.\(id).\(next.joined(separator:"/"))",title:title,source:app.localizedName ?? id,bundleID:id,category:path.first ?? "应用菜单",chord:KeyChord(key:KeyNames.character(rawKey),modifiers:mods),enabled:(attribute(node,kAXEnabledAttribute) as? Bool) ?? true,scope:"app",origin:.menu,detail:"读取于 \(Date().formatted(date:.omitted,time:.shortened))。菜单状态随应用和选区变化；菜单外的热键不会出现在这里。",location:next.joined(separator:" → ")))
                }
                if let children = attribute(node,kAXChildrenAttribute) as? [AXUIElement] {
                    for child in children { walk(child,path:next,depth:depth+1) }
                }
            }
            if let bar = attribute(element,kAXMenuBarAttribute), CFGetTypeID(bar as CFTypeRef) == AXUIElementGetTypeID() {
                walk(bar as! AXUIElement,path:[],depth:0)
            } else { partial = true }
        }
        var ids = Set<String>()
        result.shortcuts = result.shortcuts.filter { access.permits($0) && ids.insert($0.id).inserted }
        result.coverage.append(.init(id:"menus",title:"运行中应用的菜单",count:result.shortcuts.count,status:partial ? "部分读取" : "已读取",detail:"仅扫描你已允许“应用菜单”的运行中应用。只读取菜单，不读取文稿、聊天或输入内容。为避免无响应，单个应用和整轮扫描都有时间限制。刷新配置会清除过期菜单，需重新扫描。"))
        return result
    }
}

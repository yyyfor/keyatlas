import SwiftUI
import AppKit
import ApplicationServices
import UniformTypeIdentifiers

@MainActor final class ShortcutStore: ObservableObject {
    @Published var language: AppLanguage { didSet { preferences.set(language.rawValue,forKey:"interfaceLanguage") } }
    private let preferences: UserDefaults
    func t(_ value: String) -> String { language.text(value) }
    @Published var shortcuts: [Shortcut] = []
    @Published var coverage: [Coverage] = []
    @Published var query = ""
    @Published var source = "all"
    @Published var filter = "全部"
    @Published var modifier = ""
    @Published var selectedID: String?
    @Published var favorites = Set<String>()
    @Published var busy = false
    @Published var lastScan: Date?
    @Published var error: String?
    @Published var toast = ""
    @Published var fnAction = "尚未读取"
    @Published var dictation = "尚未读取"
    @Published var functionKeys = "尚未读取"
    @Published var showAdd = false
    @Published var grants: [AppGrant] = []
    @Published var availableApps: [String:String] = [:]
    let access: AppAccess
    var manual: [Shortcut] = []
    private var manualStorageUnreadable = false
    private var appScanRunning = false
    private var scanID: UUID?
    let storage: URL

    init(storage: URL? = nil, preferences: UserDefaults = .standard) {
        self.preferences = preferences
        language = AppLanguage.initial(saved:preferences.string(forKey:"interfaceLanguage"))
        self.storage = storage ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/KeyAtlas")
        access = AppAccess(storage:self.storage)
        grants = access.all
        availableApps = AppReader.installedApps()
        if let message = access.loadError {self.error = message}
        favorites = Set(preferences.stringArray(forKey:"favorites") ?? [])
        let url = self.storage.appendingPathComponent("manual-shortcuts.json")
        if FileManager.default.fileExists(atPath:url.path) {
            do { manual = try JSONDecoder().decode([Shortcut].self,from:Data(contentsOf:url)) }
            catch { self.manualStorageUnreadable = true; self.error = "手动记录读取失败，原文件已保留：\(error.localizedDescription)" }
        }
    }
    var visible: [Shortcut] { ShortcutLogic.filtered(shortcuts,query:query,source:source,filter:filter,modifier:modifier,favorites:favorites) }
    var duplicates: Set<String> { ShortcutLogic.duplicates(shortcuts) }
    var selected: Shortcut? { shortcuts.first { $0.id == selectedID } }
    var sources: [(id:String,name:String,count:Int)] {
        let groups = Dictionary(grouping:shortcuts,by: \.bundleID)
        return groups.map { (id:$0.key,name:$0.value.first!.source,count:$0.value.count) }.sorted { a,b in
            if a.id == "system" { return true }; if b.id == "system" { return false }; return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
    func navigate(_ id: String) { source = id; query = ""; modifier = ""; selectedID = nil }
    func refresh(timeout: Duration = .seconds(8), appScanner: (@Sendable () -> ScanResult)? = nil) {
        guard !busy else { return }; busy = true
        let system = SystemReader.scan()
        shortcuts = system.shortcuts + manual
        coverage = system.coverage
        fnAction = system.fnAction; dictation = system.dictation; functionKeys = system.functionKeys
        lastScan = Date()
        guard !appScanRunning else {
            busy = false
            coverage.append(.init(id:"prefs",title:"应用配置",count:0,status:"仍在等待",detail:"上次应用扫描仍未返回；系统快捷键可正常使用。请稍后刷新，或重启键览。"))
            return
        }
        let requestID = UUID(); scanID = requestID; appScanRunning = true
        let permission = access.snapshot()
        Task {
            let apps = await Task.detached(priority:.userInitiated) { appScanner?() ?? AppReader.scan(access:permission) }.value
            appScanRunning = false
            guard scanID == requestID,permission.isCurrent else {return}
            shortcuts = system.shortcuts + apps.shortcuts.filter {permission.permits($0)} + manual
            coverage = system.coverage + apps.coverage + [.init(id:"menus",title:"运行中应用的菜单",count:0,status:AXIsProcessTrusted() ? "待扫描" : "可选授权",detail:"仅扫描已单独授权菜单读取的应用；请在“应用授权”中管理。")]
            fnAction = system.fnAction; dictation = system.dictation; functionKeys = system.functionKeys
            lastScan = Date(); busy = false
            if !shortcuts.contains(where: { $0.id == selectedID }) { selectedID = nil }
        }
        Task {
            try? await Task.sleep(for:timeout)
            guard scanID == requestID, busy else {return}
            scanID = nil; busy = false
            coverage.append(.init(id:"prefs",title:"应用配置",count:0,status:"读取超时",detail:"应用配置未及时返回，已停止等待。系统快捷键仍可查看，不需要为此授予媒体或完全磁盘访问权限。"))
        }
    }
    func grant(for id: String) -> AppGrant? {grants.first {$0.bundleID == id}}
    func setAccess(id: String, name: String, scopes: Set<ReadScope>) {
        var saved = false
        do {
            try access.set(scopes.isEmpty ? nil : AppGrant(bundleID:id,name:name,scopes:scopes,grantedAt:Date()),for:id)
            saved = true
        } catch {self.error = "授权变更未保存：\(error.localizedDescription)。撤回会立即停止本次运行的读取；请修复存储问题后重试，确保重启后也保持撤回。"}
        grants = access.all
        scanID = nil;busy = false
        shortcuts.removeAll {!access.snapshot().permits($0)}
        coverage.removeAll {$0.id == id || $0.id == "settings.\(id)" || ["prefs","custom","menus"].contains($0.id)}
        if !shortcuts.contains(where:{$0.id == selectedID}) {selectedID = nil}
        guard saved else {toast = "授权记录写入失败，请查看提示。";return}
        toast = scopes.isEmpty ? "已撤回授权并清除自动读取结果；手动记录保留。" : "已保存授权。配置会在刷新时读取，菜单和设置页由你点击读取。"
    }
    func requireAccessibility() -> Bool {
        guard AXIsProcessTrusted() else {
            NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            toast = "请自行在辅助功能中允许“键览”，再回来读取。";return false
        }
        return true
    }
    func scanMenus() {
        guard !busy else {return}
        guard grants.contains(where:{$0.scopes.contains(.menus)}) else {toast = "先在应用授权中允许至少一个应用的菜单读取。";source = "access";return}
        guard requireAccessibility() else {return}
        busy = true
        let permission = access.snapshot();let requestID = UUID();scanID = requestID
        Task {
            let result = await Task.detached(priority:.userInitiated) {MenuReader.scan(access:permission)}.value
            guard scanID == requestID,permission.isCurrent else {return}
            shortcuts.removeAll {$0.origin == .menu};shortcuts += result.shortcuts.filter {permission.permits($0)}
            coverage.removeAll {$0.id == "menus"};coverage += result.coverage
            lastScan = Date();busy = false
        }
    }
    func readSettings(_ id: String) {
        guard !busy,access.snapshot().allows(id,.settings),SettingsReader.supports(id) else {return}
        guard requireAccessibility() else {return}
        busy = true
        let permission = access.snapshot();let requestID = UUID();scanID = requestID
        Task {
            let result = await Task.detached(priority:.userInitiated) {SettingsReader.scan(bundleID:id,access:permission)}.value
            guard scanID == requestID,permission.isCurrent else {return}
            // Replace the previous page snapshot, so removed bindings cannot linger.
            shortcuts.removeAll {$0.origin == .settings && $0.bundleID == id}
            shortcuts += result.shortcuts.filter {permission.permits($0)}
            coverage.removeAll {$0.id == "settings.\(id)"};coverage += result.coverage
            lastScan = Date();busy = false
            toast = result.shortcuts.isEmpty ? "没有识别到组合，请查看此应用下方的读取说明。" : "已读取 \(result.shortcuts.count) 个组合，可在左侧应用来源中查看。"
        }
    }
    func openSettings(_ id: String) {
        if id == SettingsReader.doubao {
            let url = URL(fileURLWithPath:"/Library/Input Methods/DoubaoIme.app/Contents/Applications/DoubaoImeSettings.app")
            if FileManager.default.fileExists(atPath:url.path) {NSWorkspace.shared.open(url)}
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier:id) {
            NSWorkspace.shared.open(url);toast = "在 Raycast 中按 ⌘ , 打开设置，再回到键览点击读取。"
        }
    }
    func toggleFavorite(_ item: Shortcut) {
        if favorites.contains(item.id) { favorites.remove(item.id) } else { favorites.insert(item.id) }
        preferences.set(Array(favorites),forKey:"favorites")
    }
    func saveManual(_ item: Shortcut) {
        var updated = manual; updated.append(item)
        guard persist(updated) else { return }
        manual = updated; shortcuts.append(item); showAdd = false; source = "manual"; selectedID = item.id
    }
    func removeManual(_ item: Shortcut) {
        let updated = manual.filter { $0.id != item.id }
        guard persist(updated) else { return }
        manual = updated; shortcuts.removeAll { $0.id == item.id }; selectedID = nil
    }
    private func persist(_ records: [Shortcut]) -> Bool {
        guard !manualStorageUnreadable else {
            error = "手动记录文件无法读取。为避免覆盖原数据，已停止写入。请先备份并修复 manual-shortcuts.json 后重启键览。"
            return false
        }
        do {
            try FileManager.default.createDirectory(at:storage,withIntermediateDirectories:true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
            try encoder.encode(records).write(to:storage.appendingPathComponent("manual-shortcuts.json"),options:.atomic)
            return true
        } catch { self.error = "记录未保存：\(error.localizedDescription)"; return false }
    }
    func export() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = language == .english ? "KeyAtlas-shortcuts.json" : "键览-快捷键.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
            try encoder.encode(visible).write(to:url,options:.atomic); toast = "已导出当前筛选结果"
        } catch { self.error = "导出失败：\(error.localizedDescription)" }
    }
    func copy(_ item: Shortcut) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("\(language.title(item))  \(item.chord?.tokens.map(t).joined(separator:" ") ?? t("未设置")) · \(language.source(item))",forType:.string)
        toast = "已复制快捷键"
    }
}

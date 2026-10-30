import Foundation
import AppKit

@main struct StoreTests {
    @MainActor static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("keyatlas-tests-\(UUID().uuidString)")
        defer {try? FileManager.default.removeItem(at:directory)}
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool,_ name: String) {
            guard condition() else {fputs("FAIL: \(name)\n",stderr);exit(1)}
            checks += 1
        }
        let record = Shortcut(id:"manual.test",title:"Test",source:"Test",bundleID:"test",category:"手动记录",chord:KeyChord(key:"右 ⌥",modifiers:[],trigger:"长按"),enabled:true,scope:"global",origin:.manual,detail:"Test",location:"Test")
        let store = ShortcutStore(storage:directory)
        store.saveManual(record)
        check(store.manual == [record],"Saved item appears immediately")
        let reopened = ShortcutStore(storage:directory)
        check(reopened.manual == [record],"Manual records survive relaunch")
        reopened.shortcuts = reopened.manual
        reopened.removeManual(record)
        check(reopened.shortcuts.isEmpty && reopened.manual.isEmpty,"Removal updates view and memory")
        check(ShortcutStore(storage:directory).manual.isEmpty,"Removal survives relaunch")
        let file = directory.appendingPathComponent("manual-shortcuts.json")
        let broken = Data("{broken".utf8)
        try broken.write(to:file)
        let corrupted = ShortcutStore(storage:directory)
        check(corrupted.error != nil,"Malformed saved file is reported")
        corrupted.saveManual(record)
        let after = try Data(contentsOf:file)
        check(after == broken && corrupted.manual.isEmpty,"Malformed file is never overwritten by a subsequent save")
        let blocker = directory.appendingPathComponent("not-a-directory")
        try Data().write(to:blocker)
        let denied = ShortcutStore(storage:blocker)
        denied.saveManual(record)
        check(denied.error != nil && denied.shortcuts.isEmpty,"Failed write is not falsely shown as saved")
        let slow = ShortcutStore(storage:directory.appendingPathComponent("slow"))
        slow.refresh(timeout:.milliseconds(20),appScanner:{Thread.sleep(forTimeInterval:0.3);return ScanResult()})
        check(slow.lastScan != nil,"System snapshot is published before optional app scan finishes")
        try await Task.sleep(for:.milliseconds(100))
        check(!slow.busy && slow.coverage.contains {$0.status == "读取超时"},"A slow application read cannot leave the UI busy forever")
        try await Task.sleep(for:.milliseconds(300))
        check(slow.coverage.contains {$0.status == "读取超时"},"Late scan result cannot overwrite timeout state")
        let consentStore = ShortcutStore(storage:directory.appendingPathComponent("consent"))
        consentStore.setAccess(id:"test",name:"Test",scopes:[.preferences,.settings])
        var automatic = record;automatic.id = "pref.test";automatic.origin = .preference
        consentStore.shortcuts = [automatic,record]
        consentStore.manual = [record]
        consentStore.setAccess(id:"test",name:"Test",scopes:[])
        check(consentStore.shortcuts == [record],"Revocation clears automatic results and preserves manual notes")
        check(consentStore.grants.isEmpty,"UI consent state updates after revocation")
        consentStore.setAccess(id:"test",name:"Test",scopes:[.preferences])
        let delayedResult = ScanResult(shortcuts:[automatic])
        consentStore.refresh(appScanner:{Thread.sleep(forTimeInterval:0.15);return delayedResult})
        consentStore.setAccess(id:"test",name:"Test",scopes:[])
        try await Task.sleep(for:.milliseconds(250))
        check(!consentStore.shortcuts.contains {$0.id == "pref.test"},"Revoked asynchronous result cannot repopulate the list")
        check(!consentStore.busy,"Revocation never leaves the UI busy")
        let rejected = ShortcutStore(storage:blocker)
        rejected.setAccess(id:"test",name:"Test",scopes:[.preferences])
        check(rejected.grants.isEmpty && rejected.error != nil,"Failed persistence never grants access")
        let suite = "keyatlas-language-tests-\(UUID().uuidString)"
        let preferences = UserDefaults(suiteName:suite)!
        defer {preferences.removePersistentDomain(forName:suite)}
        check(AppLanguage.initial(saved:nil,preferred:["zh-Hant-TW"]) == .chinese,"Chinese system language selects Chinese on first launch")
        check(AppLanguage.initial(saved:"invalid",preferred:["fr-FR"]) == .english,"Unsupported preference falls back to supported English")
        check(AppLanguage.initial(saved:"en",preferred:["zh-Hans"]) == .english,"Explicit language takes precedence over system language")
        let localized = ShortcutStore(storage:directory.appendingPathComponent("language"),preferences:preferences)
        localized.language = .english
        localized.setAccess(id:"test",name:"Test",scopes:[.preferences])
        var system = record;system.id = "system.28";system.origin = .system;system.title = "将整个屏幕存储为图片";system.category = "截屏"
        var userRecord = record;userRecord.title = "显示桌面"
        localized.saveManual(userRecord)
        localized.shortcuts = [system,userRecord]
        localized.favorites = [system.id]
        localized.filter = "已启用"
        let stableEncoder = JSONEncoder();stableEncoder.outputFormatting = [.sortedKeys]
        let encoded = try stableEncoder.encode(localized.shortcuts)
        let consentBefore = localized.grants
        check(localized.language.title(userRecord) == userRecord.title,"User-authored titles are never translated")
        var menuRecord = userRecord;menuRecord.origin = .menu
        check(localized.language.title(menuRecord) == menuRecord.title,"App menu labels retain their original language")
        check(SystemReader.actions.allSatisfy {AppLanguage.english.text($0.title) != $0.title},"All known system actions have English labels")
        localized.source = "all";localized.query = "screenshot"
        check(localized.visible.map(\.id) == [system.id],"English action search finds the canonical system shortcut")
        localized.query = "截屏"
        check(localized.visible.map(\.id) == [system.id],"Chinese action search remains available in English UI")
        localized.query = ""
        localized.language = .chinese
        let encodedAfter = try stableEncoder.encode(localized.shortcuts)
        check(encodedAfter == encoded,"Language changes never rewrite shortcut data")
        check(localized.filter == "已启用" && localized.favorites == [system.id] && localized.grants.map(\.bundleID) == consentBefore.map(\.bundleID) && localized.grants.first?.scopes == consentBefore.first?.scopes,"Language switch preserves filters, favorites and consent")
        localized.language = .english
        let restored = ShortcutStore(storage:localized.storage,preferences:preferences)
        check(restored.language == .english && restored.manual == [userRecord],"Language and manual records survive relaunch independently")
        check(AppLanguage.english.text("已读取 3 个组合，可在左侧应用来源中查看。") == "Read 3 combinations. Select the app in the sidebar to view them.","Dynamic result counts translate")
        check(AppLanguage.english.text("记录未保存：disk full") == "Record not saved: disk full","Error translation preserves the underlying diagnostic")
        check(AppLanguage.english.text(SettingsReader.instructions(SettingsReader.doubao)) != SettingsReader.instructions(SettingsReader.doubao),"Doubao instructions are translated")
        let space = Shortcut(id:"space",title:"Test",source:"Test",bundleID:"test",category:"Test",chord:KeyChord(key:"空格",modifiers:["⌥"]),enabled:true,scope:"global",origin:.manual,detail:"",location:"")
        check(ShortcutLogic.filtered([space],query:"option space",source:"all",filter:"全部",modifier:"",favorites:[]).count == 1,"English Space searches match stored Chinese key labels")
        check(AppLanguage.english.text("收藏 显示桌面") == "Favorite 显示桌面","User text interpolated into a label is not translated")
        print("PASS: \(checks) persistence and localization checks")
    }
}

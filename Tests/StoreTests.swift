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
        print("PASS: \(checks) persistence checks")
    }
}

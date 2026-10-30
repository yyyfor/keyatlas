import SwiftUI
import AppKit

@main struct KeyAtlasApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store = ShortcutStore()
    var body: some Scene {
        Window("键览 · KeyAtlas",id:"main") {
            RootView(store:store).task {if store.lastScan == nil {store.refresh()}}
        }.defaultSize(width:1180,height:760).windowStyle(.hiddenTitleBar)
            .commands {
                CommandGroup(replacing:.newItem) {Button(store.t("添加手动记录")) {store.showAdd = true}.keyboardShortcut("n",modifiers:.command)}
                CommandGroup(after:.newItem) {Button(store.t("刷新配置")) {store.refresh()}.keyboardShortcut("r",modifiers:.command);Button(store.t("导出当前列表…")) {store.export()}.keyboardShortcut("e",modifiers:[.command,.shift])}
            }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if CommandLine.arguments.contains("--diagnose") {
            let result = SystemReader.scan()
            let apps = AppReader.scan(access:ShortcutStore().access.snapshot())
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
            if let output = try? encoder.encode(result.shortcuts + apps.shortcuts), let pathIndex = CommandLine.arguments.firstIndex(of:"--output"), CommandLine.arguments.count > pathIndex+1 {
                try? output.write(to:URL(fileURLWithPath:CommandLine.arguments[pathIndex+1]),options:.atomic)
            }
            print("System: \(result.shortcuts.count), application preferences: \(apps.shortcuts.count), Fn: \(result.fnAction), dictation: \(result.dictation)")
            NSApp.terminate(nil)
        }
        if let i = CommandLine.arguments.firstIndex(of:"--render-preview"), CommandLine.arguments.count > i+1 {
            Task { @MainActor in
                let previewDefaults = UserDefaults(suiteName:"com.local.keyatlas.preview")!
                let store = ShortcutStore(storage:URL(fileURLWithPath:"/private/tmp/keyatlas-preview-storage"),preferences:previewDefaults)
                if let languageIndex = CommandLine.arguments.firstIndex(of:"--language"), CommandLine.arguments.count > languageIndex+1, let language = AppLanguage(rawValue:CommandLine.arguments[languageIndex+1]) {store.language = language}
                let system = SystemReader.scan(); let apps = AppReader.scan(access:store.access.snapshot())
                store.shortcuts = system.shortcuts + apps.shortcuts; store.coverage = system.coverage + apps.coverage
                store.fnAction = system.fnAction;store.dictation = system.dictation;store.functionKeys = system.functionKeys;store.lastScan = Date()
                if let pageIndex = CommandLine.arguments.firstIndex(of:"--page"), CommandLine.arguments.count > pageIndex+1 {store.source = CommandLine.arguments[pageIndex+1]}
                if CommandLine.arguments.contains("--details") {store.selectedID = "system.28"}
                let width: CGFloat = CommandLine.arguments.contains("--compact") ? 900 : 1180
                let view = NSHostingView(rootView:RootView(store:store));view.frame = NSRect(x:0,y:0,width:width,height:740)
                let window = NSWindow(contentRect:view.frame,styleMask:[.borderless],backing:.buffered,defer:false)
                window.contentView = view;window.layoutIfNeeded()
                if let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) {
                    view.cacheDisplay(in:view.bounds,to:bitmap)
                    try? bitmap.representation(using:.png,properties:[:])?.write(to:URL(fileURLWithPath:CommandLine.arguments[i+1]))
                }
                NSApp.terminate(nil)
            }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {true}
}

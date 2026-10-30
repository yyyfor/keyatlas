import SwiftUI
import AppKit

private struct AppLanguageKey: EnvironmentKey { static let defaultValue = AppLanguage.chinese }
extension EnvironmentValues {
    var appLanguage: AppLanguage { get {self[AppLanguageKey.self]} set {self[AppLanguageKey.self] = newValue} }
}

enum Theme {
    static let accent = Color(red:0.38,green:0.33,blue:0.78)
    static let ink = Color(red:0.14,green:0.14,blue:0.18)
    static let muted = Color(red:0.46,green:0.46,blue:0.52)
    static let canvas = Color(red:0.985,green:0.985,blue:0.992)
    static let sidebar = Color(red:0.95,green:0.95,blue:0.969)
    static let line = Color.black.opacity(0.07)
}

struct Keycap: View {
    @Environment(\.appLanguage) private var language
    let text: String
    var active = false
    var large = false
    var body: some View {
        Text(language.text(text)).font(.system(size:large ? 22 : 13,weight:.medium,design:.rounded))
            .foregroundStyle(active ? Theme.accent : Theme.ink)
            .padding(.horizontal,large ? 13 : 8).frame(minWidth:large ? 48 : 29,minHeight:large ? 48 : 29)
            .background(active ? Theme.accent.opacity(0.09) : Color.white,in:RoundedRectangle(cornerRadius:large ? 10 : 6))
            .overlay(RoundedRectangle(cornerRadius:large ? 10 : 6).stroke(active ? Theme.accent.opacity(0.3) : Theme.line,lineWidth:1))
            .shadow(color:.black.opacity(0.045),radius:0,y:2)
    }
}

struct ChordView: View {
    @Environment(\.appLanguage) private var language
    let chord: KeyChord?
    var large = false
    var body: some View {
        if let chord {
            HStack(spacing:4) { ForEach(Array(chord.tokens.enumerated()),id:\.offset) { _,key in Keycap(text:key,large:large) } }
        } else { Text(language.text("未设置组合")).font(.system(size:12)).foregroundStyle(Theme.muted) }
    }
}

struct AppGlyph: View {
    let id: String
    var size: CGFloat = 22
    var body: some View {
        Group {
            if id == "system" { Image(systemName:"command").font(.system(size:size*0.65,weight:.medium)).frame(width:size,height:size).background(Theme.accent.opacity(0.1),in:RoundedRectangle(cornerRadius:5)).foregroundStyle(Theme.accent) }
            else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier:id) { Image(nsImage:NSWorkspace.shared.icon(forFile:url.path)).resizable().scaledToFit().frame(width:size,height:size) }
            else { Image(systemName:"app.dashed").font(.system(size:size*0.8)).foregroundStyle(Theme.muted).frame(width:size,height:size) }
        }.accessibilityHidden(true)
    }
}

struct RootView: View {
    @ObservedObject var store: ShortcutStore
    @FocusState private var searchFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing:0) {
                sidebar.frame(width:210)
                Rectangle().fill(Theme.line).frame(width:1)
                if store.source == "fn" { FnView(store:store) }
                else if store.source == "access" { AppAccessView(store:store) }
                else if store.source == "coverage" { CoverageView(store:store) }
                else {
                    VStack(spacing:0) {
                        header
                        searchAndFilters
                        shortcutList
                        footer
                    }.frame(maxWidth:.infinity,maxHeight:.infinity)
                    if let item = store.selected, geometry.size.width >= 1100 {
                        Rectangle().fill(Theme.line).frame(width:1)
                        InspectorView(store:store,item:item).frame(width:265)
                    }
                }
            }.background(Theme.canvas).foregroundStyle(Theme.ink)
                .overlay(alignment:.bottom) {
                    if !store.toast.isEmpty {
                        Text(store.t(store.toast)).font(.system(size:12,weight:.medium)).padding(.horizontal,18).padding(.vertical,10)
                            .background(Theme.ink,in:Capsule()).foregroundStyle(.white).padding(.bottom,38)
                            .onChange(of:store.toast) { _, _ in dismissToast() }.onAppear { dismissToast() }
                    }
                }
                .sheet(isPresented:$store.showAdd) { ManualSheet(store:store) }
                .alert(store.t("需要留意"),isPresented:Binding(get:{store.error != nil},set:{if !$0 {store.error = nil}})) { Button(store.t("知道了")) {store.error = nil} } message: { Text(store.t(store.error ?? "")) }
                .background(Button("") { searchFocused = true }.keyboardShortcut("f",modifiers:.command).hidden())
                .animation(reduceMotion ? nil : .easeInOut(duration:0.16),value:store.source)
        }.frame(minWidth:900,minHeight:620).preferredColorScheme(.light)
            .environment(\.appLanguage,store.language)
            .environment(\.locale,Locale(identifier:store.language.rawValue))
    }
    func dismissToast() { let text = store.toast; Task { try? await Task.sleep(for:.seconds(3)); if store.toast == text { store.toast = "" } } }

    var sidebar: some View {
        VStack(alignment:.leading,spacing:0) {
            HStack(spacing:11) {
                Image(systemName:"command").font(.system(size:24,weight:.medium)).foregroundStyle(.white).frame(width:41,height:41).background(Theme.accent,in:RoundedRectangle(cornerRadius:12))
                VStack(alignment:.leading,spacing:3) { Text(store.t("键览")).font(.system(size:21,weight:.semibold)); Text(store.language == .english ? "SHORTCUTS" : "KEYATLAS").font(.system(size:9,weight:.semibold)).tracking(2.5).foregroundStyle(Theme.muted) }
            }.padding(.horizontal,22).padding(.top,26).padding(.bottom,30)
            ScrollView {
                VStack(alignment:.leading,spacing:4) {
                    sectionCaption("资料库")
                    navRow("全部快捷键",id:"all",icon:"square.grid.2x2",count:store.shortcuts.count)
                    navRow("我的收藏",id:"favorites",icon:"star",count:store.shortcuts.filter {store.favorites.contains($0.id)}.count)
                    navRow("重复组合",id:"duplicates",icon:"square.on.square",count:store.duplicates.count)
                    navRow("手动记录",id:"manual",icon:"pencil.line",count:store.manual.count)
                    sectionCaption("来源").padding(.top,24)
                    ForEach(store.sources,id:\.id) { s in
                        Button { store.navigate(s.id) } label: {
                            HStack(spacing:9) { AppGlyph(id:s.id,size:20); Text(["services","all-app-menus"].contains(s.id) ? store.t(s.name) : s.name).lineLimit(1); Spacer(minLength:2); Text(store.t("\(s.count)")).font(.system(size:11,design:.monospaced)).foregroundStyle(Theme.muted) }
                                .font(.system(size:12)).padding(.horizontal,10).frame(height:35).background(store.source == s.id ? Color.white : .clear,in:RoundedRectangle(cornerRadius:7))
                        }.buttonStyle(.plain).accessibilityLabel(store.t("来源：\(s.name)，\(s.count) 条"))
                    }
                }.padding(.horizontal,12)
            }
            VStack(spacing:4) {
                HStack(spacing:8) {
                    Image(systemName:"globe").foregroundStyle(Theme.muted)
                    Picker("Language / 语言",selection:$store.language) {
                        ForEach(AppLanguage.allCases) { language in Text(language.name).tag(language) }
                    }.labelsHidden().accessibilityLabel("Language / 语言")
                }.font(.system(size:11)).padding(.horizontal,10).padding(.bottom,10)
                navRow("应用授权",id:"access",icon:"lock.shield",count:store.grants.count)
                navRow("Fn 与修饰键",id:"fn",icon:"keyboard",count:nil)
                navRow("读取范围",id:"coverage",icon:"info.circle",count:nil)
                HStack(spacing:6) { Circle().fill(Color(red:0.3,green:0.62,blue:0.48)).frame(width:5,height:5); Text(store.t("仅在本机读取")).font(.system(size:10)); Spacer(); Text("1.2").font(.system(size:10,design:.monospaced)) }.foregroundStyle(Theme.muted).padding(.horizontal,11).padding(.top,15).padding(.bottom,9)
            }.padding(12)
        }.background(Theme.sidebar)
    }
    func sectionCaption(_ text: String) -> some View { Text(store.t(text)).font(.system(size:10,weight:.medium)).foregroundStyle(Theme.muted).padding(.horizontal,10).padding(.bottom,7) }
    func navRow(_ title: String,id: String,icon: String,count: Int?) -> some View {
        Button { store.navigate(id) } label: {
            HStack(spacing:10) { Image(systemName:icon).font(.system(size:13)).frame(width:18); Text(store.t(title)).lineLimit(1).minimumScaleFactor(0.8); Spacer(minLength:0); if let count { Text(store.t("\(count)")).font(.system(size:11,design:.monospaced)).opacity(0.7) } }
                .font(.system(size:12,weight:store.source == id ? .semibold : .regular)).foregroundStyle(store.source == id ? Theme.accent : Theme.ink)
                .padding(.horizontal,11).frame(height:36).background(store.source == id ? Theme.accent.opacity(0.09) : .clear,in:RoundedRectangle(cornerRadius:7))
        }.buttonStyle(.plain)
    }
    var pageTitle: String {
        switch store.source {
        case "all": return store.t("快捷键总览")
        case "favorites": return store.t("我的收藏")
        case "duplicates": return store.t("重复组合")
        case "manual": return store.t("手动记录")
        default:
            let name = store.sources.first {$0.id == store.source}?.name ?? store.t("快捷键")
            return ["services","all-app-menus"].contains(store.source) ? store.t(name) : name
        }
    }
    var header: some View {
        HStack(alignment:.center) {
            VStack(alignment:.leading,spacing:7) {
                Text(pageTitle).font(.system(size:27,weight:.semibold)).tracking(-0.7)
                Text(store.t(store.source == "duplicates" ? "相同组合可能共用；不代表已经发生冲突。" : "把常用的组合，放在一眼能找到的地方。"))
                    .font(.system(size:12)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength:16)
            Button {store.showAdd = true} label:{Image(systemName:"plus").frame(width:28,height:28)}.buttonStyle(.plain).help(store.t("添加手动记录，不会修改系统按键"))
            Button {store.refresh()} label:{Label(store.t(store.busy ? "读取中" : "刷新配置"),systemImage:"arrow.clockwise").font(.system(size:12,weight:.medium)).padding(.horizontal,12).padding(.vertical,9).background(Theme.accent,in:RoundedRectangle(cornerRadius:8)).foregroundStyle(.white)}.buttonStyle(.plain).disabled(store.busy).keyboardShortcut("r",modifiers:.command)
        }.padding(.horizontal,30).padding(.top,27).padding(.bottom,25)
    }
    var searchAndFilters: some View {
        VStack(spacing:14) {
            HStack(spacing:10) {
                Image(systemName:"magnifyingglass").foregroundStyle(Theme.muted)
                TextField(store.t("搜索功能、应用或按键组合…"),text:$store.query).textFieldStyle(.plain).font(.system(size:13)).focused($searchFocused).accessibilityLabel(store.t("搜索快捷键"))
                if !store.query.isEmpty { Button {store.query = ""} label:{Image(systemName:"xmark.circle.fill").foregroundStyle(Theme.muted)}.buttonStyle(.plain) }
                else {Text(store.t("⌘ F")).font(.system(size:10,design:.monospaced)).foregroundStyle(Theme.muted)}
            }.padding(.horizontal,14).frame(height:43).background(.white,in:RoundedRectangle(cornerRadius:9)).overlay(RoundedRectangle(cornerRadius:9).stroke(Theme.line))
            HStack(spacing:6) {
                Text(store.t("包含")).font(.system(size:11)).foregroundStyle(Theme.muted).padding(.trailing,3)
                ForEach(["⌘","⌥","⌃","⇧","fn"],id:\.self) { modifier in
                    Button {store.modifier = store.modifier == modifier ? "" : modifier} label:{Keycap(text:modifier,active:store.modifier == modifier)}.buttonStyle(.plain).help(store.t("筛选包含 \(modifier) 的组合"))
                }
                Spacer()
                Picker(store.t("状态"),selection:$store.filter) { ForEach(["全部","已启用","待确认","已停用"],id:\.self) {Text(store.t($0)).tag($0)} }.labelsHidden().pickerStyle(.segmented).frame(width:store.language == .english ? 310 : 245)
            }
        }.padding(.horizontal,30).padding(.bottom,19)
    }
    var shortcutList: some View {
        let visible = store.visible
        let groups = Dictionary(grouping:visible,by: { "\($0.source) / \($0.category)" })
        let ordered = visible.map { "\($0.source) / \($0.category)" }.reduce(into:[String]()) {if !$0.contains($1) {$0.append($1)}}
        return Group {
            if visible.isEmpty {
                VStack(spacing:13) {
                    Image(systemName:store.source == "favorites" ? "star" : "keyboard").font(.system(size:34,weight:.light)).foregroundStyle(Theme.accent.opacity(0.55))
                    Text(store.t(store.busy ? "正在读取本机配置…" : "这里还没有快捷键")).font(.system(size:16,weight:.medium))
                    Text(store.t(store.source == "favorites" ? "点击快捷键旁的星标，就能在这里快速找到它。" : "试试其他搜索条件，或在应用授权中添加读取来源。"))
                        .font(.system(size:12)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                    if !store.query.isEmpty || !store.modifier.isEmpty || store.filter != "全部" {Button(store.t("清除筛选")) {store.query = "";store.modifier = "";store.filter = "全部"}.buttonStyle(.link).tint(Theme.accent)}
                }.frame(maxWidth:.infinity,maxHeight:.infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment:.leading,spacing:0,pinnedViews:[.sectionHeaders]) {
                        ForEach(ordered,id:\.self) { key in
                            Section {
                                ForEach(groups[key] ?? []) { item in ShortcutRow(store:store,item:item) }
                            } header: {
                                HStack { Text(groups[key]?.first.map {store.language.source($0) + " / " + store.language.category($0)} ?? key).font(.system(size:11,weight:.medium)); Spacer(); Text(store.t("\(groups[key]?.count ?? 0)")).font(.system(size:10,design:.monospaced)) }.foregroundStyle(Theme.muted).padding(.horizontal,14).padding(.top,15).padding(.bottom,10).background(Theme.canvas)
                            }
                        }
                    }.padding(.horizontal,16).padding(.bottom,22)
                }
            }
        }
    }
    var footer: some View {
        HStack(spacing:6) {
            if store.busy {ProgressView().controlSize(.mini)} else {Image(systemName:"checkmark.circle").foregroundStyle(Theme.accent)}
            Text(store.t("\(store.visible.count) 条结果")); Text(store.t("·")); Text(store.t(store.lastScan.map {"更新于 " + $0.formatted(date:.omitted,time:.shortened)} ?? "准备读取"))
            Spacer(); Button(store.t("导出 JSON")) {store.export()}.buttonStyle(.plain).foregroundStyle(Theme.accent)
        }.font(.system(size:10)).foregroundStyle(Theme.muted).padding(.horizontal,30).frame(height:37).overlay(alignment:.top) {Rectangle().fill(Theme.line).frame(height:1)}
    }
}

struct ShortcutRow: View {
    @ObservedObject var store: ShortcutStore
    let item: Shortcut
    @State private var hover = false
    @State private var showDetails = false
    var body: some View {
        HStack(spacing:11) {
            Button {store.toggleFavorite(item)} label:{Image(systemName:store.favorites.contains(item.id) ? "star.fill" : "star").font(.system(size:12)).foregroundStyle(store.favorites.contains(item.id) ? Theme.accent : Theme.muted.opacity(hover ? 0.8 : 0.3)).frame(width:18,height:32)}.buttonStyle(.plain).help(store.t("收藏 \(store.language.title(item))")).accessibilityLabel(store.t("收藏 \(store.language.title(item))"))
            VStack(alignment:.leading,spacing:5) {
                Text(store.language.title(item)).font(.system(size:13,weight:.medium)).lineLimit(1)
                HStack(spacing:6) {
                    Text(store.t(item.origin.rawValue))
                    if item.chord?.trigger != "按下", let trigger = item.chord?.trigger {Text(store.t("·"));Text(store.t(trigger))}
                    if item.enabled == nil {Text(store.t("· 启用待确认"))} else if item.enabled == false {Text(store.t("· 已停用"))}
                    if !item.condition.isEmpty {Text(store.t("· 有条件"))}
                }.font(.system(size:10)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength:8)
            if store.duplicates.contains(item.id) {Image(systemName:"square.on.square").font(.system(size:11)).foregroundStyle(.orange).help(store.t("检测到相同组合；不代表确定冲突"))}
            ChordView(chord:item.chord).opacity(item.enabled == false ? 0.45 : 1)
            Button {showDetails = true} label:{Image(systemName:"info.circle").font(.system(size:12)).foregroundStyle(Theme.muted).frame(width:22,height:28)}.buttonStyle(.plain).help(store.t("查看详情")).accessibilityLabel(store.t("\(store.language.title(item)) 的详情"))
        }.padding(.horizontal,13).frame(height:66)
            .background(store.selectedID == item.id ? Theme.accent.opacity(0.065) : hover ? Color.black.opacity(0.025) : .clear,in:RoundedRectangle(cornerRadius:9))
            .contentShape(Rectangle()).onTapGesture {store.selectedID = item.id}.onHover {hover = $0}
            .contextMenu {Button(store.t("复制快捷键")) {store.copy(item)};Button(store.t("查看详情")) {showDetails = true};Button(store.t(store.favorites.contains(item.id) ? "取消收藏" : "收藏")) {store.toggleFavorite(item)}}
            .popover(isPresented:$showDetails) {InspectorView(store:store,item:item).frame(width:290,height:470)}
    }
}

struct InspectorView: View {
    @ObservedObject var store: ShortcutStore
    let item: Shortcut
    @State private var confirmRemoval = false
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:20) {
                HStack {Text(store.t("快捷键详情")).font(.system(size:11,weight:.medium)).foregroundStyle(Theme.muted);Spacer();AppGlyph(id:item.bundleID,size:24)}
                ViewThatFits {ChordView(chord:item.chord,large:true);ChordView(chord:item.chord)}.padding(.top,17)
                Text(store.language.title(item)).font(.system(size:19,weight:.semibold)).fixedSize(horizontal:false,vertical:true)
                VStack(spacing:13) {
                    detail("来源",store.language.source(item),translateValue:false);detail("读取方式",item.origin.rawValue);detail("状态",item.enabled == nil ? "已设置，启用待确认" : item.enabled == true ? "已启用" : "已停用")
                    detail("作用范围",item.scope == "global" ? "全局" : item.scope == "app" ? "应用内" : "尚未确认")
                    detail("触发方式",item.chord?.trigger ?? "未设置")
                }
                Divider()
                Text(store.t(item.detail)).font(.system(size:11)).foregroundStyle(Theme.muted).lineSpacing(5).fixedSize(horizontal:false,vertical:true)
                if !item.condition.isEmpty {Text(store.t(item.condition)).font(.system(size:11)).foregroundStyle(Theme.muted)}
                Text(item.origin == .menu ? item.location : store.t(item.location)).font(.system(size:10,design:.monospaced)).foregroundStyle(Theme.muted).textSelection(.enabled).lineSpacing(4)
                Button {store.copy(item)} label:{Label(store.t("复制快捷键"),systemImage:"doc.on.doc").frame(maxWidth:.infinity)}.controlSize(.large)
                if item.bundleID == "system" {Button(store.t("在系统设置中查看 ↗")) {openKeyboardSettings()}.buttonStyle(.link).tint(Theme.accent)}
                if item.origin == .manual {Button(store.t("删除这条记录"),role:.destructive) {confirmRemoval = true}.confirmationDialog(store.t("只删除键览中的记录，不会修改实际快捷键。"),isPresented:$confirmRemoval) {Button(store.t("删除记录"),role:.destructive) {store.removeManual(item)}}}
            }.padding(24)
        }.background(.white.opacity(0.65))
    }
    func detail(_ label: String,_ value: String,translateValue: Bool = true) -> some View {HStack(alignment:.top) {Text(store.t(label)).foregroundStyle(Theme.muted);Spacer();Text(translateValue ? store.t(value) : value).multilineTextAlignment(.trailing)}.font(.system(size:11))}
}

func openKeyboardSettings() {NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!)}

struct CoverageView: View {
    @ObservedObject var store: ShortcutStore
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:24) {
                Text(store.t("读取范围")).font(.system(size:28,weight:.semibold))
                Text(store.t("知道看到了什么，也知道还缺什么。")).font(.system(size:13)).foregroundStyle(Theme.muted)
                HStack(spacing:14) {
                    Image(systemName:"lock.shield").font(.system(size:27,weight:.light)).foregroundStyle(Theme.accent)
                    Text(store.t("数据留在这台 Mac。第三方应用默认不读取，由你逐个授权。自动读取结果只保留在内存，手动记录和授权选择保存在本机。")).font(.system(size:12)).lineSpacing(5)
                }.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(Theme.accent.opacity(0.05),in:RoundedRectangle(cornerRadius:12))
                ForEach(store.coverage) { item in
                    VStack(alignment:.leading,spacing:9) {
                        HStack {Text(store.t(item.title)).font(.system(size:14,weight:.medium));Spacer();Text(store.t("\(item.count) 条")).foregroundStyle(Theme.muted);Text(store.t(item.status)).foregroundStyle(Theme.accent)}.font(.system(size:11))
                        Text(store.t(item.detail)).font(.system(size:12)).foregroundStyle(Theme.muted).lineSpacing(5).fixedSize(horizontal:false,vertical:true)
                    }.padding(.vertical,7)
                    Divider()
                }
                HStack(spacing:14) {
                    Button(store.t("管理应用授权")) {store.navigate("access")}.buttonStyle(.bordered)
                    Button(store.t(store.busy ? "读取中…" : "扫描应用菜单")) {store.scanMenus()}.buttonStyle(.borderedProminent).tint(Theme.accent).disabled(store.busy)
                    Button(store.t("添加手动记录")) {store.showAdd = true}.buttonStyle(.bordered)
                }
                Text(store.t("菜单扫描是可选功能，需要你在系统设置中授予辅助功能权限。重复组合只是线索，不能确认按键被谁拦截。手动记录也不会自动跟随原应用更新。")).font(.system(size:11)).foregroundStyle(Theme.muted).lineSpacing(5)
            }.padding(36).frame(maxWidth:800,alignment:.leading).frame(maxWidth:.infinity,alignment:.leading)
        }
    }
}

struct FnView: View {
    @ObservedObject var store: ShortcutStore
    @State private var testing = false
    @State private var received = ""
    @State private var monitor: Any?
    var body: some View {
        ScrollView {
            VStack(alignment:.leading,spacing:25) {
                Text(store.t("Fn 与修饰键")).font(.system(size:28,weight:.semibold))
                Text(store.t("先看系统怎么设置，再确认按键有没有被收到。")).font(.system(size:13)).foregroundStyle(Theme.muted)
                HStack(spacing:20) {Keycap(text:"fn",large:true);VStack(alignment:.leading,spacing:6) {Text(store.t("单按 Fn / 🌐")).font(.system(size:12)).foregroundStyle(Theme.muted);Text(store.t(store.fnAction)).font(.system(size:20,weight:.medium))};Spacer()}.padding(26).background(.white,in:RoundedRectangle(cornerRadius:13)).overlay(RoundedRectangle(cornerRadius:13).stroke(Theme.line))
                setting("系统听写",store.dictation)
                setting("键盘顶行默认行为",store.functionKeys)
                Button(store.t("打开键盘设置 ↗")) {openKeyboardSettings()}.buttonStyle(.link).tint(Theme.accent)
                Divider().padding(.vertical,6)
                Text(store.t("按键检测")).font(.system(size:18,weight:.semibold))
                Text(store.t("开始后，保持键览在前台并按下 Fn 或其他组合。只显示最近一次按键，不保存记录，也不在后台监听。")).font(.system(size:12)).foregroundStyle(Theme.muted).lineSpacing(5)
                VStack(spacing:18) {
                    Text(received.isEmpty ? store.t(testing ? "等待按键…" : "准备好了就开始") : received).font(.system(size:26,weight:.medium,design:.rounded)).foregroundStyle(testing ? Theme.accent : Theme.muted).frame(height:54)
                    Button(store.t(testing ? "结束检测" : "开始检测")) {testing ? stop() : start()}.buttonStyle(.borderedProminent).tint(Theme.accent).keyboardShortcut(.escape,modifiers:[])
                }.frame(maxWidth:.infinity).padding(27).background(Theme.accent.opacity(0.045),in:RoundedRectangle(cornerRadius:12))
                Text(store.t("收到 Fn 只说明按键到达了键览，无法证明其他应用也能收到；收不到也不能单凭此项确定是谁拦截。长按、双击等触发方式需要在原应用中检查。")).font(.system(size:11)).foregroundStyle(Theme.muted).lineSpacing(5)
            }.padding(36).frame(maxWidth:800,alignment:.leading).frame(maxWidth:.infinity,alignment:.leading)
        }.onDisappear {stop()}
    }
    func setting(_ name: String,_ value: String) -> some View {HStack {Text(store.t(name)).foregroundStyle(Theme.muted);Spacer();Text(store.t(value))}.font(.system(size:13))}
    func start() {
        testing = true; received = ""
        monitor = NSEvent.addLocalMonitorForEvents(matching:[.keyDown,.flagsChanged]) { event in
            guard NSApp.isActive else {return event}
            if event.type == .keyDown && event.keyCode == 53 {stop();return nil}
            if event.type == .flagsChanged {
                let tokens = KeyChord.cocoa(code:65535,flags:UInt64(event.modifierFlags.rawValue)).modifiers
                if !tokens.isEmpty {received = tokens.joined(separator:"  ")}
                return event
            }
            received = KeyChord.cocoa(code:Int(event.keyCode),flags:UInt64(event.modifierFlags.rawValue)).tokens.map(store.t).joined(separator:" ")
            return nil
        }
    }
    func stop() {if let monitor {NSEvent.removeMonitor(monitor)};monitor = nil;testing = false}
}

struct ManualSheet: View {
    @ObservedObject var store: ShortcutStore
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var source = ""
    @State private var key = ""
    @State private var modifiers = Set<String>()
    @State private var trigger = "按下"
    @State private var scope = "global"
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            Text(store.t("添加手动记录")).font(.system(size:23,weight:.semibold))
            Text(store.t("记录你在其他应用里确认过的快捷键，不会创建或修改实际绑定。")).font(.system(size:12)).foregroundStyle(Theme.muted).fixedSize(horizontal:false,vertical:true)
            VStack(alignment:.leading,spacing:12) {
                TextField(store.t("功能名称，例如：唤起语音输入"),text:$title)
                TextField(store.t("所属应用，例如：豆包输入法"),text:$source)
                HStack(spacing:7) {ForEach(["fn","⌃","⌥","⇧","⌘"],id:\.self) { m in Button {if modifiers.contains(m) {modifiers.remove(m)} else {modifiers.insert(m)}} label:{Keycap(text:m,active:modifiers.contains(m))}.buttonStyle(.plain)}}
                TextField(store.t("按键，例如 K、fn、右 Option（可只选上方修饰键）"),text:$key)
                Picker(store.t("触发方式"),selection:$trigger) {ForEach(["按下","长按","双击"],id:\.self) {Text(store.t($0)).tag($0)}}
                Picker(store.t("作用范围"),selection:$scope) {Text(store.t("全局")).tag("global");Text(store.t("仅应用内")).tag("app");Text(store.t("不确定")).tag("unknown")}
            }.textFieldStyle(.roundedBorder).controlSize(.large)
            HStack {Button(store.t("取消")) {dismiss()}.keyboardShortcut(.cancelAction);Spacer();Button(store.t("保存记录")) {save()}.buttonStyle(.borderedProminent).tint(Theme.accent).disabled(title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || source.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || (key.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && modifiers.isEmpty))}
        }.padding(30).frame(width:490).foregroundStyle(Theme.ink)
    }
    func save() {
        let raw = key.trimmingCharacters(in:.whitespacesAndNewlines)
        let aliases = ["fn":"fn","space":"空格","空格":"空格","右 option":"右 ⌥","右option":"右 ⌥","right option":"右 ⌥","右⌥":"右 ⌥","option":"⌥","command":"⌘","control":"⌃","shift":"⇧"]
        let name = source.trimmingCharacters(in:.whitespacesAndNewlines)
        let item = Shortcut(id:"manual.\(UUID().uuidString)",title:title.trimmingCharacters(in:.whitespacesAndNewlines),source:name,bundleID:store.sources.first {$0.name == name}?.id ?? "manual.\(name)",category:"手动记录",chord:KeyChord(key:aliases[raw.lowercased()] ?? raw.uppercased(),modifiers:["fn","⌃","⌥","⇧","⌘"].filter {modifiers.contains($0)},trigger:trigger),enabled:true,scope:scope,origin:.manual,detail:"由你手动确认并记录。请在原应用修改快捷键后同步更新此记录。",location:"键览 → 手动记录")
        store.saveManual(item)
    }
}

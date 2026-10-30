import SwiftUI
import ApplicationServices

struct AppChoice: Identifiable {let id: String;let name: String}

struct AppAccessView: View {
    @ObservedObject var store: ShortcutStore
    @State private var query = ""
    @State private var onlyGranted = false
    @State private var editing: AppChoice?
    var apps: [AppChoice] {
        var all = store.availableApps
        for grant in store.grants {all[grant.bundleID] = grant.name}
        return all.filter {$0.key != "com.local.keyatlas"}.map {AppChoice(id:$0.key,name:$0.value)}.filter {
            (!onlyGranted || store.grant(for:$0.id) != nil) && (query.isEmpty || "\($0.name) \($0.id)".localizedCaseInsensitiveContains(query))
        }.sorted {a,b in
            let aRank = SettingsReader.supports(a.id) ? 0 : store.grant(for:a.id) != nil ? 1 : 2
            let bRank = SettingsReader.supports(b.id) ? 0 : store.grant(for:b.id) != nil ? 1 : 2
            return aRank != bRank ? aRank < bRank : a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
    }
    var body: some View {
        VStack(alignment:.leading,spacing:0) {
            HStack(alignment:.top) {
                VStack(alignment:.leading,spacing:8) {
                    Text("应用授权").font(.system(size:28,weight:.semibold))
                    Text("读哪些应用，由你决定。").font(.system(size:13)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Text("\(store.grants.count) 个已授权").font(.system(size:11,weight:.medium)).foregroundStyle(Theme.accent).padding(.horizontal,13).padding(.vertical,8).background(Theme.accent.opacity(0.07),in:Capsule())
            }.padding(.bottom,24)
            HStack(alignment:.top,spacing:13) {
                Image(systemName:"hand.raised").font(.system(size:20,weight:.light)).foregroundStyle(Theme.accent)
                VStack(alignment:.leading,spacing:7) {
                    Text("默认关闭 · 随时撤回 · 数据留在本机").font(.system(size:12,weight:.medium))
                    Text("这是键览内的逐应用授权。读取菜单和设置页还需要 macOS 辅助功能权限；该系统权限本身不按目标应用细分。撤回后，键览停止后续读取并清除该应用的自动结果。").font(.system(size:11)).foregroundStyle(Theme.muted).lineSpacing(4).fixedSize(horizontal:false,vertical:true)
                }
            }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(Theme.accent.opacity(0.045),in:RoundedRectangle(cornerRadius:11)).padding(.bottom,22)
            HStack(spacing:10) {
                Image(systemName:"magnifyingglass").foregroundStyle(Theme.muted)
                TextField("搜索已安装的应用…",text:$query).textFieldStyle(.plain).accessibilityLabel("搜索授权应用")
                Toggle("只看已授权",isOn:$onlyGranted).toggleStyle(.checkbox).font(.system(size:11))
            }.font(.system(size:12)).padding(13).background(.white,in:RoundedRectangle(cornerRadius:8)).overlay(RoundedRectangle(cornerRadius:8).stroke(Theme.line)).padding(.bottom,12)
            ScrollView {
                LazyVStack(spacing:0) {
                    if apps.isEmpty {Text("没有符合条件的应用").foregroundStyle(Theme.muted).padding(36)}
                    ForEach(apps) {app in
                        VStack(alignment:.leading,spacing:13) {
                            HStack(spacing:12) {
                                AppGlyph(id:app.id,size:34)
                                VStack(alignment:.leading,spacing:5) {
                                    Text(app.name).font(.system(size:14,weight:.medium))
                                    Text(subtitle(app)).font(.system(size:11)).foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                if store.grant(for:app.id) != nil {
                                    Button("撤回") {store.setAccess(id:app.id,name:app.name,scopes:[])}.buttonStyle(.plain).foregroundStyle(Theme.muted).help("撤回 \(app.name) 的授权")
                                }
                                Button(store.grant(for:app.id) == nil ? "授权…" : "管理…") {editing = app}.controlSize(.regular).accessibilityLabel("\(app.name) \(store.grant(for:app.id) == nil ? "授权" : "管理")")
                            }
                            if let grant = store.grant(for:app.id) {
                                HStack(spacing:6) {
                                    ForEach(ReadScope.allCases.filter {grant.scopes.contains($0)}) {scope in
                                        Text(scope.title).font(.system(size:10)).foregroundStyle(Theme.accent).padding(.horizontal,8).padding(.vertical,4).background(Theme.accent.opacity(0.06),in:Capsule())
                                    }
                                    Spacer()
                                    Text("\(store.shortcuts.filter {$0.bundleID == app.id && $0.origin != .manual}.count) 条已读取").font(.system(size:10)).foregroundStyle(Theme.muted)
                                }
                                if grant.scopes.contains(.settings),SettingsReader.supports(app.id) {
                                    Text(SettingsReader.instructions(app.id)).font(.system(size:11)).foregroundStyle(Theme.muted).lineSpacing(4).fixedSize(horizontal:false,vertical:true)
                                    HStack(spacing:12) {
                                        Button(app.id == SettingsReader.doubao ? "打开豆包输入法设置 ↗" : "打开 Raycast ↗") {store.openSettings(app.id)}.buttonStyle(.link).tint(Theme.accent)
                                        Button("读取当前设置页") {store.readSettings(app.id)}.disabled(store.busy).accessibilityLabel("读取 \(app.name) 当前设置页")
                                    }.font(.system(size:11))
                                    if let report = store.coverage.first(where:{$0.id == "settings.\(app.id)"}) {
                                        Text("\(report.status) · \(report.count) 条。\(report.detail)").font(.system(size:11)).foregroundStyle(Theme.muted).lineSpacing(3).fixedSize(horizontal:false,vertical:true)
                                    }
                                }
                            }
                        }.padding(.vertical,18).padding(.horizontal,4)
                        Divider()
                    }
                }
            }
            HStack(spacing:12) {
                Image(systemName:"lock.shield").foregroundStyle(Theme.accent)
                Text("系统快捷键、共用菜单与系统服务单独读取。应用列表来自已安装应用的名称。").font(.system(size:10)).foregroundStyle(Theme.muted)
                Spacer()
                Menu("读取已授权应用") {
                    Button("刷新快捷键配置") {store.refresh()}
                    Button("扫描应用菜单") {store.scanMenus()}
                }.menuStyle(.borderlessButton).fixedSize().disabled(store.busy)
            }.padding(.top,15)
        }.padding(32).sheet(item:$editing) {app in ConsentSheet(store:store,app:app)}
    }
    func subtitle(_ app: AppChoice) -> String {
        if store.grant(for:app.id) != nil {return "已授权 · 可按读取方式单独调整"}
        if SettingsReader.supports(app.id) {return "未授权 · 支持读取已打开的快捷键设置页"}
        return AppReader.canReadPreferenceDomain(app.id) ? "未授权 · 可尝试配置与菜单读取" : "未授权 · 可选菜单读取"
    }
}

struct ConsentSheet: View {
    @ObservedObject var store: ShortcutStore
    let app: AppChoice
    @Environment(\.dismiss) private var dismiss
    @State private var scopes = Set<ReadScope>()
    var body: some View {
        VStack(alignment:.leading,spacing:22) {
            HStack(spacing:13) {
                AppGlyph(id:app.id,size:43)
                VStack(alignment:.leading,spacing:6) {
                    Text("允许读取 \(app.name)？").font(.system(size:22,weight:.semibold))
                    Text("只对这个应用生效，可随时撤回。").font(.system(size:12)).foregroundStyle(Theme.muted)
                }
            }
            VStack(alignment:.leading,spacing:20) {
                if AppReader.canReadPreferenceDomain(app.id) {
                    option(.preferences,"读取本机偏好设置文件，仅提取可识别的快捷键字段。部分应用使用私有格式，可能读不到。")
                }
                option(.menus,"读取该应用运行时的菜单项与组合。需要辅助功能权限；无法覆盖菜单之外的热键。")
                if SettingsReader.supports(app.id) {
                    option(.settings,"仅在你点击读取时，临时处理已打开设置页的可访问文字，只保留快捷键。不进入聊天窗口，不读取可编辑输入框。需要辅助功能权限。")
                }
            }
            Text("辅助功能是 macOS 授予键览的整体权限；逐个应用的限制由键览执行。自动读取结果不写入磁盘，导出由你主动触发。撤回不删除你手动添加的记录或已导出的文件。").font(.system(size:11)).foregroundStyle(Theme.muted).lineSpacing(4).fixedSize(horizontal:false,vertical:true)
            HStack {
                Button("取消") {dismiss()}.keyboardShortcut(.cancelAction)
                Spacer()
                Button(scopes.isEmpty ? "撤回授权" : "允许所选读取") {
                    store.setAccess(id:app.id,name:app.name,scopes:scopes)
                    if store.error == nil && !scopes.isEmpty {store.refresh()}
                    dismiss()
                }.buttonStyle(.borderedProminent).tint(Theme.accent).keyboardShortcut(.defaultAction)
            }
        }.padding(30).frame(width:530).foregroundStyle(Theme.ink)
            .onAppear {scopes = store.grant(for:app.id)?.scopes ?? (SettingsReader.supports(app.id) ? [.settings] : AppReader.canReadPreferenceDomain(app.id) ? [.preferences] : [.menus])}
    }
    func option(_ scope: ReadScope,_ description: String) -> some View {
        Toggle(isOn:Binding(get:{scopes.contains(scope)},set:{if $0 {scopes.insert(scope)} else {scopes.remove(scope)}})) {
            VStack(alignment:.leading,spacing:7) {
                Text(scope.title).font(.system(size:13,weight:.medium))
                Text(description).font(.system(size:11)).foregroundStyle(Theme.muted).lineSpacing(4).fixedSize(horizontal:false,vertical:true)
            }
        }.toggleStyle(.checkbox)
    }
}

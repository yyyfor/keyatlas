import Foundation

/// Presentation only: persisted model values, shortcut identities and consent stay language-neutral.
enum AppLanguage: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans", english = "en"
    var id: String { rawValue }
    var name: String { self == .chinese ? "简体中文" : "English" }
    static func initial(saved: String?, preferred: [String] = Locale.preferredLanguages) -> AppLanguage {
        if let saved, let language = AppLanguage(rawValue:saved) { return language }
        return preferred.first?.hasPrefix("zh") == true ? .chinese : .english
    }
    func text(_ value: String) -> String {
        guard self == .english, value.unicodeScalars.contains(where: { (0x3400...0x9FFF).contains($0.value) }) else { return value }
        if let translated = Translations.exact[value] { return translated }
        if value.contains("\n") { return value.components(separatedBy:"\n").map(text).joined(separator:"\n") }
        for template in Translations.templates {
            let range = NSRange(value.startIndex...,in:value)
            guard let match = template.pattern.firstMatch(in:value,range:range) else { continue }
            var output = template.english
            // Replace from the template, never recursively interpret substituted user text.
            for index in (0..<(match.numberOfRanges - 1)).reversed() {
                guard let captured = Range(match.range(at:index+1),in:value) else { continue }
                let raw = String(value[captured])
                let evidence = ["系统当前配置","已保存配置","KeyboardShortcuts 配置","已保存的快捷键配置"]
                output = output.replacingOccurrences(of:"{\(index)}",with:evidence.contains(raw) ? (Translations.exact[raw] ?? raw) : raw)
            }
            return output
        }
        return value
    }
    func title(_ item: Shortcut) -> String {
        // Application menus and user-authored labels retain the original application's language.
        if item.origin == .system || item.id.hasPrefix("pref.") ||
            (item.origin == .settings && (item.bundleID == SettingsReader.doubao || item.title == "打开 Raycast")) {
            return text(item.title)
        }
        return item.title
    }
    func source(_ item: Shortcut) -> String {
        ["services","all-app-menus"].contains(item.bundleID) ? text(item.source) : item.source
    }
    func category(_ item: Shortcut) -> String { item.origin == .menu ? item.category : text(item.category) }
}

private enum Translations {
    struct Template { let pattern: NSRegularExpression; let english: String }
    static let pairs: [(String,String)] = catalog.split(separator:"\n").compactMap { line in
        let parts = line.split(separator:"\t",maxSplits:1,omittingEmptySubsequences:false)
        return parts.count == 2 ? (String(parts[0]),String(parts[1])) : nil
    }
    static let exact = Dictionary(pairs.filter {!$0.0.contains("{0}")},uniquingKeysWith: {first,_ in first})
    static let templates: [Template] = pairs.filter {$0.0.contains("{0}")}.map { chinese,english in
        var pattern = NSRegularExpression.escapedPattern(for:chinese)
        for index in 0...9 { pattern = pattern.replacingOccurrences(of:NSRegularExpression.escapedPattern(for:"{\(index)}"),with:"([\\s\\S]*?)") }
        return Template(pattern:try! NSRegularExpression(pattern:"\\A" + pattern + "\\z"),english:english)
    }
    // Chinese canonical strings remain compatible with existing saved records and filters.
    static let catalog = """
当前页没有可识别的已设置组合；不代表应用没有快捷键。	No assigned combinations were recognized on this page. The app may still have shortcuts.
仅包含当前设置页可访问的快捷键，未显示的项目和未公开的开关无法确认。	Only accessible shortcuts on this page are included. Hidden entries and unexposed switches remain unknown.
键览	KeyAtlas
未设置组合	Not set
需要留意	Something needs attention
知道了	OK
资料库	LIBRARY
全部快捷键	All shortcuts
我的收藏	Favorites
重复组合	Shared combinations
手动记录	Manual records
来源	Source
来源：{0}，{1} 条	Source: {0}, {1} shortcuts
应用授权	App access
Fn 与修饰键	Fn & modifiers
读取范围	Read coverage
仅在本机读取	On this Mac only
快捷键总览	Shortcut overview
快捷键	Shortcuts
相同组合可能共用；不代表已经发生冲突。	Shared combinations are clues, not confirmed conflicts.
把常用的组合，放在一眼能找到的地方。	Your shortcuts, within easy reach.
添加手动记录，不会修改系统按键	Add a record without changing any key bindings
读取中	Reading
刷新配置	Refresh
搜索功能、应用或按键组合…	Search actions, apps or key combinations…
搜索快捷键	Search shortcuts
包含	Includes
筛选包含 {0} 的组合	Filter combinations containing {0}
状态	Status
全部	All
已启用	Enabled
待确认	Unconfirmed
已停用	Disabled
正在读取本机配置…	Reading this Mac’s settings…
这里还没有快捷键	No shortcuts here yet
点击快捷键旁的星标，就能在这里快速找到它。	Star a shortcut to find it here.
试试其他搜索条件，或在应用授权中添加读取来源。	Try another search, or allow an app in App access.
清除筛选	Clear filters
{0} 条结果	{0} results
更新于 {0}	Updated {0}
准备读取	Ready to read
导出 JSON	Export JSON
收藏 {0}	Favorite {0}
系统读取	System settings
应用配置	App preferences
应用菜单	App menus
设置页读取	Settings page
按下	Press
长按	Hold
双击	Double press
修饰键触发	Modifier trigger
· 启用待确认	· Unconfirmed
· 已停用	· Disabled
· 有条件	· Conditional
检测到相同组合；不代表确定冲突	Shared combination; a conflict has not been confirmed
查看详情	View details
{0} 的详情	Details for {0}
复制快捷键	Copy shortcut
取消收藏	Remove favorite
收藏	Favorite
快捷键详情	SHORTCUT DETAILS
读取方式	Read method
已设置，启用待确认	Set; activation unconfirmed
作用范围	Scope
全局	Global
应用内	In app
尚未确认	Unknown
触发方式	Trigger
未设置	Not set
在系统设置中查看 ↗	View in System Settings ↗
删除这条记录	Delete this record
只删除键览中的记录，不会修改实际快捷键。	Delete this KeyAtlas record? The actual shortcut will stay unchanged.
删除记录	Delete record
知道看到了什么，也知道还缺什么。	See what was read and what may still be missing.
数据留在这台 Mac。第三方应用默认不读取，由你逐个授权。自动读取结果只保留在内存，手动记录和授权选择保存在本机。	Your data stays on this Mac. Each third-party app requires your permission. Automatic results stay in memory; manual records and permission choices are saved locally.
{0} 条	{0} items
管理应用授权	Manage app access
读取中…	Reading…
扫描应用菜单	Scan app menus
添加手动记录	Add manual record
菜单扫描是可选功能，需要你在系统设置中授予辅助功能权限。重复组合只是线索，不能确认按键被谁拦截。手动记录也不会自动跟随原应用更新。	Menu scanning is optional and requires Accessibility permission in System Settings. Shared combinations cannot identify which app intercepts a key. Manual records do not update automatically.
先看系统怎么设置，再确认按键有没有被收到。	Check system settings, then test whether a key reaches KeyAtlas.
单按 Fn / 🌐	Press Fn / 🌐
系统听写	System dictation
键盘顶行默认行为	Top-row key behavior
打开键盘设置 ↗	Open Keyboard Settings ↗
按键检测	Key test
开始后，保持键览在前台并按下 Fn 或其他组合。只显示最近一次按键，不保存记录，也不在后台监听。	Start the test, keep KeyAtlas in front, and press Fn or another combination. Only the latest key is displayed. Nothing is saved or monitored in the background.
等待按键…	Waiting for a key…
准备好了就开始	Ready when you are
结束检测	Stop test
开始检测	Start test
收到 Fn 只说明按键到达了键览，无法证明其他应用也能收到；收不到也不能单凭此项确定是谁拦截。长按、双击等触发方式需要在原应用中检查。	Receiving Fn only confirms that it reached KeyAtlas. It does not prove that another app received it, or identify an interceptor if it did not arrive. Check hold and double-press triggers in the original app.
记录你在其他应用里确认过的快捷键，不会创建或修改实际绑定。	Record a shortcut you have confirmed in another app. This does not create or change its binding.
功能名称，例如：唤起语音输入	Action, e.g. Start voice input
所属应用，例如：豆包输入法	App, e.g. Doubao IME
按键，例如 K、fn、右 Option（可只选上方修饰键）	Key, e.g. K, fn, right Option (or select modifiers above)
仅应用内	In app only
不确定	Unknown
取消	Cancel
保存记录	Save record
由你手动确认并记录。请在原应用修改快捷键后同步更新此记录。	Confirmed and recorded by you. Update this record when you change the shortcut in the original app.
键览 → 手动记录	KeyAtlas → Manual records
读哪些应用，由你决定。	Choose which apps KeyAtlas can read.
{0} 个已授权	{0} allowed
默认关闭 · 随时撤回 · 数据留在本机	Off by default · Revoke anytime · Stored locally
这是键览内的逐应用授权。读取菜单和设置页还需要 macOS 辅助功能权限；该系统权限本身不按目标应用细分。撤回后，键览停止后续读取并清除该应用的自动结果。	These permissions are enforced by KeyAtlas for each app. Menus and settings pages also require macOS Accessibility access, which applies to KeyAtlas as a whole. Revoking access stops future reads and clears that app’s automatic results.
搜索已安装的应用…	Search installed apps…
搜索授权应用	Search apps for access
只看已授权	Allowed only
没有符合条件的应用	No matching apps
撤回	Revoke
撤回 {0} 的授权	Revoke access to {0}
授权…	Allow…
管理…	Manage…
{0} 授权	Allow {0}
{0} 管理	Manage {0}
{0} 条已读取	{0} read
打开豆包输入法设置 ↗	Open Doubao IME Settings ↗
打开 Raycast ↗	Open Raycast ↗
读取当前设置页	Read current page
读取 {0} 当前设置页	Read {0}’s current settings page
系统快捷键、共用菜单与系统服务单独读取。应用列表来自已安装应用的名称。	System shortcuts, shared menus and services are read separately. App names come from installed apps.
读取已授权应用	Read allowed apps
刷新快捷键配置	Refresh shortcut settings
已授权 · 可按读取方式单独调整	Allowed · Manage each read method
未授权 · 支持读取已打开的快捷键设置页	Not allowed · Settings page reader available
未授权 · 可尝试配置与菜单读取	Not allowed · Preferences and menus available
未授权 · 可选菜单读取	Not allowed · Menu reader available
允许读取 {0}？	Allow access to {0}?
只对这个应用生效，可随时撤回。	Applies only to this app. Revoke access anytime.
读取本机偏好设置文件，仅提取可识别的快捷键字段。部分应用使用私有格式，可能读不到。	Read local preferences and extract recognized shortcut fields. Apps with private formats may not be supported.
读取该应用运行时的菜单项与组合。需要辅助功能权限；无法覆盖菜单之外的热键。	Read menu items and shortcuts while this app is running. Requires Accessibility access and does not cover shortcuts outside menus.
仅在你点击读取时，临时处理已打开设置页的可访问文字，只保留快捷键。不进入聊天窗口，不读取可编辑输入框。需要辅助功能权限。	Only when you click Read, process accessible text from an open settings page and retain shortcuts. Chat windows and editable fields are excluded. Requires Accessibility access.
辅助功能是 macOS 授予键览的整体权限；逐个应用的限制由键览执行。自动读取结果不写入磁盘，导出由你主动触发。撤回不删除你手动添加的记录或已导出的文件。	macOS grants Accessibility access to KeyAtlas as a whole; KeyAtlas enforces per-app limits. Automatic results stay in memory unless you export them. Revoking access keeps manual records and previously exported files.
撤回授权	Revoke access
允许所选读取	Allow selected methods
快捷键配置	Shortcut preferences
已打开的快捷键设置页	Open shortcut settings page
导出当前列表…	Export current list…
尚未读取	Not read yet
未知	Unknown
不执行任何操作	Do nothing
更改输入法	Change input source
显示表情与符号	Show emoji & symbols
开始听写	Start dictation
未读到明确配置	No explicit setting found
已开启	On
已关闭	Off
标准 F1、F2… 功能键	Standard F1, F2… function keys
亮度、音量等系统控制	Brightness, volume and system controls
空格	Space
右 ⌘	R ⌘
右 ⌥	R ⌥
右 ⌃	R ⌃
右 ⇧	R ⇧
右⌘	R ⌘
右⌥	R ⌥
右⌃	R ⌃
右⇧	R ⇧
左⌘	L ⌘
左⌥	L ⌥
左⌃	L ⌃
左⇧	L ⇧
小键盘 {0}	Numpad {0}
键码 {0}	Keycode {0}
将整个屏幕存储为图片	Save screenshot of entire screen
将整个屏幕复制到剪贴板	Copy entire screen to clipboard
将所选区域存储为图片	Save screenshot of selected area
将所选区域复制到剪贴板	Copy selected area to clipboard
打开截屏与录屏工具	Open screenshot & recording tools
截屏	Screenshots
显示聚焦搜索	Show Spotlight search
显示访达搜索窗口	Show Finder search
选择上一个输入法	Select previous input source
选择输入法菜单中的下一个输入法	Select next input source
搜索与输入法	Search & input sources
调度中心	Mission Control
应用程序窗口	Application windows
显示桌面	Show desktop
向左移动一个空间	Move left a space
向右移动一个空间	Move right a space
显示或隐藏程序坞	Show or hide Dock
切换同一应用的窗口	Switch windows in the same app
桌面与窗口	Desktop & windows
将焦点移到菜单栏	Move focus to menu bar
将焦点移到程序坞	Move focus to Dock
将焦点移到下一个窗口	Move focus to next window
将焦点移到工具栏	Move focus to toolbar
将焦点移到浮动窗口	Move focus to floating window
打开或关闭键盘访问	Toggle keyboard access
更改 Tab 的焦点移动方式	Change how Tab moves focus
将焦点移到状态菜单	Move focus to status menus
键盘导航	Keyboard navigation
打开或关闭缩放	Toggle zoom
放大	Zoom in
缩小	Zoom out
反转颜色	Invert colors
打开或关闭图像平滑	Toggle image smoothing
增强对比度	Increase contrast
降低对比度	Decrease contrast
打开或关闭旁白	Toggle VoiceOver
辅助功能	Accessibility
切换到桌面 {0}	Switch to desktop {0}
听写触发键	Dictation trigger
系统动作 #{0}	System action #{0}
Fn 与听写	Fn & dictation
其他系统设置	Other system settings
已保存配置	Saved preferences
系统当前配置	Current system settings
{0} · 系统编号 {1}。按键按 ANSI 键位显示。fn 标记按系统原始配置保留，部分机型不需要额外按下 fn。仅显示配置，不能证明某个应用拦截了按键。	{0} · System ID {1}. Keys use ANSI labels. The system’s fn flag is preserved; some keyboards do not require an extra fn press. Settings alone cannot identify an app intercepting a key.
{0} · 系统编号 {1}。按键按 ANSI 键位显示。fn 标记按系统原始配置保留，部分机型不需要额外按下 fn。仅显示配置，不能证明某个应用拦截了按键。 当前系统听写已关闭，因此此触发键不会启动听写。	{0} · System ID {1}. Keys use ANSI labels and preserve the system’s fn flag. Some keyboards do not require an extra fn press. Settings cannot identify an interceptor. Dictation is currently off, so this trigger will not start it.
系统设置 → 键盘 → 键盘快捷键	System Settings → Keyboard → Keyboard Shortcuts
macOS 系统快捷键	macOS system shortcuts
部分读取	Partial coverage
已读取	Read
读取已识别的系统动作与保存的自定义项；未知动作保留编号。新版本系统可能增加未识别的动作。	Reads recognized system actions and saved custom settings. Unknown actions retain their IDs. New macOS versions may introduce unrecognized actions.
KeyboardShortcuts 配置	KeyboardShortcuts preferences
已保存的快捷键配置	Saved shortcut preferences
打开快捷窗口	Open launcher
打开附属快捷窗口	Open attached launcher
打开设置	Open settings
左半屏	Left half
右半屏	Right half
最大化窗口	Maximize window
居中窗口	Center window
移到下一显示器	Move to next display
应用快捷键	App shortcuts
{0}。应用可能另有开关或运行条件；未能从配置判断作用范围时，不参与重复组合检查。	{0}. The app may have additional switches or conditions. Entries with an unknown scope are excluded from shared-combination checks.
自定义菜单快捷键	Custom menu shortcuts
读取自 macOS 的 App 快捷键设置。只有应用存在同名菜单命令时才会生效。所有应用的菜单配置不等同于全局热键。	Read from macOS App Shortcuts. The app must have a menu command with the same name. A menu shortcut for all apps is not a global hotkey.
系统设置 → 键盘 → 键盘快捷键 → App 快捷键	System Settings → Keyboard → Keyboard Shortcuts → App Shortcuts
所有应用的菜单	All app menus
系统服务	System services
服务	Services
系统服务的已保存快捷键；是否可用取决于当前选区和应用。	Saved shortcut for a system service. Availability depends on the current selection and app.
系统设置 → 键盘 → 键盘快捷键 → 服务	System Settings → Keyboard → Keyboard Shortcuts → Services
App 自定义快捷键与服务	Custom app shortcuts & services
读取系统保存的共用菜单设置、系统服务及已授权的第三方应用配置。跳过 Apple 应用的受保护偏好文件，可用菜单扫描补充；零条不表示没有默认快捷键。	Reads saved shared-menu settings, system services and allowed third-party preferences. Protected Apple preferences are skipped; menu scanning can add coverage. Zero results does not mean there are no default shortcuts.
可识别的应用配置	Recognized app preferences
部分支持	Partial support
支持 KeyboardShortcuts、部分 ShortcutRecorder / MASShortcut 配置。仅读取你逐个授权的应用，展示实际保存的条目，不猜测默认值。	Supports KeyboardShortcuts and some ShortcutRecorder / MASShortcut preferences. Reads only allowed apps and shows saved entries without guessing defaults.
豆包输入法	Doubao IME
豆包	Doubao
需读取设置页	Settings page required
配置格式未完整支持。豆包输入法与 Raycast 可在“应用授权”中单独读取已打开的设置页；菜单无法覆盖长按 Fn 等隐藏热键。	This preferences format is not fully supported. Read open Doubao IME or Raycast settings pages from App access. Menus cannot cover hidden triggers such as holding Fn.
运行中应用的菜单	Running app menus
未授权	Not allowed
可选：在辅助功能中允许键览读取菜单。基础的系统和应用配置读取不需要此权限。	Optional: allow KeyAtlas in Accessibility to read menus. Basic system and app preference reads do not need this permission.
读取于 {0}。菜单状态随应用和选区变化；菜单外的热键不会出现在这里。	Read at {0}. Menu state changes with the app and selection. Shortcuts outside menus are not included.
仅扫描你已允许“应用菜单”的运行中应用。只读取菜单，不读取文稿、聊天或输入内容。为避免无响应，单个应用和整轮扫描都有时间限制。刷新配置会清除过期菜单，需重新扫描。	Scans running apps with menu access allowed. Reads only menus, excluding documents, chats and input. Each app and the full scan have time limits. Refreshing clears menu snapshots; scan again to update them.
应用授权记录无法读取，已按全部未授权处理。	Saved app permissions could not be read. All third-party access is disabled.
打开豆包输入法设置 → 语音输入，保持该页打开后点击读取。支持长按和免按模式；跨输入法开关仍需你在原应用确认。	Open Doubao IME Settings → Voice input, leave it open, then click Read. Hold and hands-free modes are supported. Confirm cross-input-source switches in Doubao itself.
在 Raycast 按 ⌘ , 打开 Settings。General 页可读取启动快捷键；Extensions / Shortcuts 页尝试读取界面暴露的已设置组合。折叠、未加载或未公开的项目不会被计入。	Press ⌘ , in Raycast to open Settings. Read the launcher shortcut on General, or exposed assigned combinations on Extensions / Shortcuts. Collapsed, unloaded or unexposed entries are excluded.
设置页快捷键	Settings page shortcuts
读取于 {0}，来自已打开的设置页。只说明该组合已设置；不会推断未公开的开关、权限或运行状态。刷新配置后需重新读取。	Read at {0} from an open settings page. Confirms only that a combination is set; hidden switches, permissions and runtime state remain unknown. Read again after refreshing.
豆包输入法 → 语音输入	Doubao IME → Voice input
跨输入法唤起及辅助功能权限需在原应用确认。	Confirm cross-input-source activation and Accessibility permission in the original app.
仅覆盖本次设置页暴露的项目。	Covers only the entries exposed on this settings page.
按住说话	Hold to talk
免按说话	Hands-free dictation
打开 Raycast	Open Raycast
豆包输入法设置页	Doubao IME settings page
Raycast 设置页	Raycast settings page
请先允许此应用的设置页读取。	First allow settings-page access for this app.
需辅助功能权限	Accessibility required
在系统设置中允许键览使用辅助功能后，再点击读取。	Allow KeyAtlas in System Settings → Accessibility, then click Read again.
请打开设置	Open settings first
未识别到组合	No combinations found
仍在等待	Still waiting
上次应用扫描仍未返回；系统快捷键可正常使用。请稍后刷新，或重启键览。	The previous app scan is still running. System shortcuts remain available. Refresh later or restart KeyAtlas.
待扫描	Ready to scan
可选授权	Optional permission
仅扫描已单独授权菜单读取的应用；请在“应用授权”中管理。	Only apps with menu access are scanned. Manage them in App access.
读取超时	Read timed out
应用配置未及时返回，已停止等待。系统快捷键仍可查看，不需要为此授予媒体或完全磁盘访问权限。	App preferences did not respond in time. System shortcuts remain available. Media or Full Disk Access is not needed.
手动记录读取失败，原文件已保留：{0}	Could not read manual records. The original file was preserved: {0}
授权变更未保存：{0}。撤回会立即停止本次运行的读取；请修复存储问题后重试，确保重启后也保持撤回。	Permission changes could not be saved: {0}. Revocation stops reads for this session immediately. Fix the storage issue and retry so it also persists after relaunch.
授权记录写入失败，请查看提示。	Could not save permissions. Please review the error.
已撤回授权并清除自动读取结果；手动记录保留。	Access revoked and automatic results cleared. Manual records were kept.
已保存授权。配置会在刷新时读取，菜单和设置页由你点击读取。	Permissions saved. Preferences are read on refresh; click to read menus or settings pages.
请自行在辅助功能中允许“键览”，再回来读取。	Allow KeyAtlas (键览) in Accessibility, then return to read.
先在应用授权中允许至少一个应用的菜单读取。	Allow menu access for at least one app in App access first.
没有识别到组合，请查看此应用下方的读取说明。	No combinations recognized. Check the read instructions below this app.
已读取 {0} 个组合，可在左侧应用来源中查看。	Read {0} combinations. Select the app in the sidebar to view them.
在 Raycast 中按 ⌘ , 打开设置，再回到键览点击读取。	Press ⌘ , in Raycast to open Settings, then return to KeyAtlas and click Read.
手动记录文件无法读取。为避免覆盖原数据，已停止写入。请先备份并修复 manual-shortcuts.json 后重启键览。	The manual records file could not be read. Writes are stopped to protect the original data. Back up and repair manual-shortcuts.json, then restart KeyAtlas.
记录未保存：{0}	Record not saved: {0}
已导出当前筛选结果	Exported current filtered results
导出失败：{0}	Export failed: {0}
已复制快捷键	Shortcut copied
"""
}

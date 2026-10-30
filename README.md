# 键览 · KeyAtlas

[简体中文](#简体中文) · [English](README.en.md) · [Download / 下载](https://github.com/yyyfor/keyatlas/releases/latest)

**English** — KeyAtlas is a native macOS app that brings system shortcuts and shortcuts from individually authorized apps into a searchable overview. Browse by source, filter by modifier, save favorites, inspect shared combinations, and test Fn in the foreground. Choose **English** or **简体中文** from the language selector at the bottom of the sidebar; changes apply immediately and are remembered. [Read the English guide →](README.en.md)

## 简体中文

一个原生 macOS 快捷键查看器。中英文界面，支持搜索、来源和修饰键筛选、收藏、重复组合提示、详情、JSON 导出、手动记录，以及前台 Fn 按键检测。

## 下载与打开

[下载最新版本](https://github.com/yyyfor/keyatlas/releases/latest) · [查看源码](https://github.com/yyyfor/keyatlas)

1. 在 Release 的 **Assets** 中下载 `KeyAtlas-1.2.0-macOS-arm64.zip`。不要选择只包含源码的 Source code 压缩包。
2. 双击 ZIP 解压，将 **键览.app** 拖到“应用程序”文件夹，再双击打开。
3. 此版本适用于 **Apple Silicon（M 系列芯片）与 macOS 14 及以上**，在 macOS 15.6.1 上验证；暂不提供 Intel 安装包。
4. 当前为本地临时签名，**尚未经过 Apple 公证**。如果 macOS 因无法验证开发者而阻止打开，在确认下载来源可信后，可按 [Apple 官方说明](https://support.apple.com/zh-cn/102445)，到“系统设置 → 隐私与安全性”选择“仍要打开”。无需关闭系统整体安全保护。

本地构建完成后，也可以直接打开 `build/键览.app`。

在左侧栏底部的语言选择器中选择 **简体中文** 或 **English**，无需重启，选择会自动保存。首次启动跟随系统的首选语言（中文使用简体中文，其他语言使用英文）。系统文件对话框及其他应用提供的菜单名称遵循其自身语言；手动记录不会被翻译。导出的字段和值保持原有格式，切换语言不改变快捷键身份、收藏或授权。

首次启动只自动读取系统快捷键、共用菜单和系统服务。第三方应用默认全部未授权；在“应用授权”中逐个选择读取方式。`⌘F` 搜索，`⌘R` 刷新，`⌘N` 添加手动记录，`⌘⇧E` 导出筛选后的列表。搜索支持 `cmd+shift+3`、`⌘⇧3`、应用名与中英文系统功能名。

## 豆包、Raycast 与逐应用授权

1. 左侧打开“应用授权”，在豆包输入法或 Raycast 旁点击“授权…”。
2. 勾选需要的方式：快捷键配置、应用菜单、已打开的快捷键设置页。只有支持设置页解析的应用才显示第三项；每种方式独立控制。
3. 读取菜单或设置页前，在 **系统设置 → 隐私与安全性 → 辅助功能** 中自行添加并允许“键览”。基础配置读取不需要此权限。不必授予完全磁盘访问、媒体或屏幕录制权限。
4. 豆包输入法：打开设置 → 语音输入，回到键览点击“读取当前设置页”。支持识别长按、免按模式已设置的组合；“点击设置”等未配置字段不会当作快捷键。
5. Raycast：在 Raycast 按 `⌘,` 打开 Settings。General 页读取启动快捷键；Extensions / Shortcuts 页只尝试读取公开的已设置组合。折叠、未加载及未公开的项目无法保证覆盖。切换页面后重新读取会替换该应用的上一份设置页快照。

**权限边界**：macOS 的辅助功能授权是授予键览整体，不能由操作系统限制为“只允许豆包”或“只允许 Raycast”。逐应用、逐读取方式的限制由键览执行。没有“一键默认允许全部”；旧版本自动读取过的应用也不会继承授权。撤回后停止后续读取、立即清除对应的自动结果，并丢弃正在返回的旧结果。已开始的系统调用可能短暂完成，但不会进入列表。手动记录和用户已导出的文件保留。

设置页读取只在点击按钮时执行：限定豆包的设置伴随程序，以及 Raycast 标题明确为 Settings/Preferences 的窗口；不进入聊天窗口，跳过可编辑输入框。界面文字在内存中临时处理，仅保留解析出的快捷键。不使用屏幕录制，也不解密 Raycast 数据库或索取其全量导出。

目前已核对本机豆包输入法 1.0.3 与 Raycast 1.104.32 的可访问字段，并以这些字段验证解析器。键览自身的完整辅助功能授权采集路径仍需授权后实机验证；未授权时不会自动开启。其他版本界面变动可能需要适配。**“豆包输入法”和“豆包桌面聊天客户端”是不同应用**，后者尚无专用设置页适配器。

## 数据来源与边界

- **系统**：动态读取 SkyLight 中的只读 symbolic-hotkey 接口，用已知编号命名动作；接口不可用时回退到已保存偏好设置。没有伪装成实际配置的默认值。未知的已保存动作保留编号。私有接口可能随 macOS 版本变化。
- **应用**：读取共用 `NSUserKeyEquivalents`、已授权的第三方应用配置、系统服务和可识别的 KeyboardShortcuts / ShortcutRecorder 格式。跳过 Apple 应用受保护的偏好文件，不索取媒体权限。只显示保存的条目，不把“没有写入配置”解释成“没有快捷键”。系统结果先显示，应用扫描最多等待 8 秒；超时会提示。
- **菜单**：按用户操作读取已授权且正在运行的应用菜单，带单应用与总时间限制。结果是某一时刻的菜单状态，刷新配置后清除。隐藏的全局、长按和双击热键不一定在菜单中。
- **设置页**：豆包输入法与 Raycast 的专用、有限适配，不声明全量读取。该来源标为“已设置，启用待确认”，不把组合存在当成实际已启用，也不参与冲突判断。默认显示全部，可用“待确认”单独筛选。JSON 中缺省 `enabled` 表示启用状态未知，布尔值表示已读取的状态。
- **暂未完整支持**：各应用的私有/加密存储、豆包桌面客户端及未暴露的隐藏热键。可手动记录，键览不会自动修改或验证记录。
- **重复组合**：仅比较启用项、相同触发方式以及可能重叠的作用范围；不同应用内的组合不相互报警。未知范围不参与。相同组合不等于确定冲突，不能借此证明 Fn 被某进程拦截。
- **键位**：虚拟键码使用 ANSI 标签，保留系统返回的 fn 标志；部分机型的导航键和功能键不需要额外按 fn。详情会提示此限制。
- **隐私**：没有网络请求，不上传配置，不记录输入内容。Fn 检测仅在键览前台启用时显示最近一次按键。菜单读取只访问菜单树。

逐应用授权保存在 `~/Library/Application Support/KeyAtlas/app-consent.json`，损坏时按全部未授权处理。自动读取结果只保留在内存；收藏保存在键览自身偏好设置；手动记录保存在 `~/Library/Application Support/KeyAtlas/manual-shortcuts.json`。无法解析的记录文件会保留并报错，写入采用原子替换。

## 构建与验证

无需第三方依赖，使用支持 Swift 5.9 或更新版本的 Xcode / Command Line Tools。构建、测试和生成带 SHA-256 校验文件的安装包：

```sh
bash scripts/build.sh
bash scripts/test.sh
bash scripts/package.sh
```

开发诊断（只读，遵守已保存的逐应用授权，无需辅助功能）：

```sh
build/键览.app/Contents/MacOS/KeyAtlas --diagnose --output /tmp/keyatlas.json
build/键览.app/Contents/MacOS/KeyAtlas --render-preview /tmp/keyatlas.png --page access --language en
```

`Tests/main.swift` 覆盖 Carbon/Cocoa 掩码、Fn 与左右修饰键、菜单编码、损坏配置、重复组合的范围与触发方式、搜索及导出往返。诊断快照包含本机应用与快捷键，不应随源代码发布。额外测试覆盖授权默认拒绝、按应用/读取方式限制、持久化、撤回竞争、损坏授权、设置页解析及未知启用状态。

## 参考

- [Apple：键盘设置](https://support.apple.com/zh-cn/guide/mac-help/-kbdm162/mac)
- [Raycast：设置](https://manual.raycast.com/settings)
- [Raycast：导入与导出](https://manual.raycast.com/import-export)
- [Apple：Accessibility API](https://developer.apple.com/documentation/applicationservices/1462060-axuielementcopyattributevalues)
- [LinearMouse：SymbolicHotKey 的接口与未绑定键处理](https://github.com/linearmouse/linearmouse/blob/main/Modules/KeyKit/Sources/KeyKit/SymbolicHotKey.swift)
- [系统动作编号参考](https://github.com/andyjakubowski/dotfiles/blob/main/AppleSymbolicHotKeys%20Mappings)

不链接私有框架作为强依赖，不调用修改或注册系统热键的接口。

打包脚本仅收录 `.app` 本身，不包含本机快捷键快照、应用授权、手动记录或构建缓存。

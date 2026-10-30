# 键览 · KeyAtlas

Native macOS utility. A quiet, warm-white workspace with a lilac accent; typography and alignment do the organizing. The shortcut itself is the visual anchor.

Content: source sidebar → searchable shortcut list → selected shortcut details. Separate pages for Fn inspection and coverage explain what the data can and cannot prove.

Interaction: short selection transitions, responsive search, and deliberate keycap feedback. Respect Reduce Motion. No global keyboard listener, no network requests, no mutation of other applications' settings.

Palette: #FAFAFC background, #F1F1F6 sidebar, #6255C8 accent, #23232D text, #777784 secondary. System typography; monospaced keycaps. Minimum window 900 × 620.

## 1.1 应用授权

沿用浅色原生列表，添加独立“应用授权”入口。默认显示零授权；豆包输入法和 Raycast 排在列表前方，每行给出读取能力和授权状态。授权弹窗分别说明配置、菜单和设置页读取的范围。权限不使用自动开启的全选开关；撤回即时生效。无法确定启用状态的设置页条目标为“待确认”。


## 1.2 Language / 语言

A compact globe picker remains visible at the bottom of the sidebar. Language names use their own scripts (English / 简体中文) so users can always find a familiar choice. Switching is immediate and persistent. English controls have room for longer labels; content supplied by users and external apps retains its original wording. Localization changes presentation only, never shortcut identity or permission state.

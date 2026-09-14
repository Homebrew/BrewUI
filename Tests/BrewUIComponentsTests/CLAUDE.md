# Tests/BrewUIComponentsTests/
> L2 | 父级: ../CLAUDE.md

成员清单
AnimatedSplitTests.swift: Foundation + Testing；AnimatedSplitTests 的既有实现。
BrewActionButtonAppearanceTests.swift: Foundation + Testing；BrewActionButtonAppearanceTests 的既有实现。
BrewColorTokenContrastTests.swift: Foundation + Testing；AA is asserted in the **high-contrast** appearances only. The standard palette is the Homebrew。
BrewLayoutWindowMinimumTests.swift: Foundation + Testing；The window minimum and the split's two floors have to agree, or the smallest window starves a pane.。
FocusSearchFieldActionTests.swift: Foundation + Testing；FocusSearchFieldActionTests 的既有实现。
LocalizationPreferencesTests.swift: BrewUIComponents + Foundation + Testing；展示组件测试中的本地化策略契约，与 UI 测试共同覆盖持久化及同进程切换。
NoteCalloutToneTests.swift: SwiftUI + Testing；NoteCalloutToneTests 的既有实现。
RefreshAllActionTests.swift: Foundation + Testing；RefreshAllActionTests 的既有实现。
RelativeTimeTextTests.swift: Foundation + Testing；共享展示组件的时间语义回归测试，避免语言切换复用缓存字符串。
SearchFieldClickAwayTests.swift: AppKit + Testing；SearchFieldClickAwayTests 的既有实现。
SearchFocusArbiterTests.swift: Foundation + Testing；SearchFocusArbiterTests 的既有实现。
Support/: 子模块边界；保持既有职责，本次未修改。
WCAGContrastTests.swift: Foundation + Testing；Verifies the contrast arithmetic against values published in WCAG 2.1.。
WarningGlyphTests.swift: AppKit + Testing；`brewWarningGlyphStyle()` depends on an SF Symbols detail Apple owns: in the two-layer。

NativeMenuLocalizationTests.swift: AppKit + Swift Testing；验证标准菜单绑定、双向语言切换、快捷键和 target/action 保留、Services 隔离及幂等标题更新。

[PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md

StandardAppCommandsTests.swift: AppKit 窗口能力快照；验证关闭、最小化、缩放与取消隐藏的可用状态，不操作真实窗口。

StandardEditingCommandsTests.swift: 原生 selector/快捷键、本地化、校验与实际路由 seam；验证目标缺失时禁用，执行时尊重当前校验。
LocalizationCatalogTests.swift: Foundation；直接检查产品 catalog 三语言覆盖、审核状态与格式参数，防止 fixture 通过而真实资源缺译。

# Sources/BrewUIComponents/Views/
> L2 | 父级: ../CLAUDE.md

成员清单
AnimatedSplit.swift: AppKit + SwiftUI；SwiftUI 与独立 NSHostingView 的桥接边界，显式传递语言环境而不重建承载视图。
AsyncContentView.swift: BrewAccessibilityID + BrewCore + SwiftUI；Renders a ``LoadState`` by switching on its case and standardises the boilerplate that would。
BrewActionButton.swift: SwiftUI；共享操作按钮；只在渲染时解析文案，确认任务不随语言变化重建。
CommandBlockView.swift: AppKit + SwiftUI；命令展示边界；标题本地化，命令原样保留且展开状态独立于语言。
LastUpdatedLabel.swift: Foundation + SwiftUI；相对时间展示边界；保留截断语义，在每次渲染时按当前语言解析完整短语。
NoteCallout.swift: SwiftUI；Which register a ``NoteCallout`` speaks in. Both are informational; the difference is what the。
PackageDetailSubviews.swift: SwiftUI；详情表面共享结构；标题资源在当前语言的展示边界解析。
PaneContentWidth.swift: SwiftUI；View 的既有实现。
RedactionChrome.swift: SwiftUI；View 的既有实现。
View+AXID.swift: BrewAccessibilityID + SwiftUI；View 的既有实现。

[PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md

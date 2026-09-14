# Sources/BrewUIComponents/Localization/
> L2 | 父级: ../CLAUDE.md

成员清单
AppLocalization.swift: Foundation + SwiftUI；展示边界的语言快照；不依赖偏好存储，也不改变命令或领域数据。
AppMessage.swift: BrewCore + Foundation；展示消息边界；存储语义而非已翻译字符串，错误出现后仍可切换语言。
LanguageCommands.swift: BrewAccessibilityID + SwiftUI；用户意图进入语言状态的入口；不重建窗口或触发后台任务。
LanguagePreferences.swift: Foundation + Observation；UI 语言状态唯一所有者；由 App 注入，业务仓库与命令生命周期不依赖它。

NativeMenuLocalization.swift: AppKit；通过公开引用及既有快捷键识别顶级菜单；只同步顶级标题，正文由 Commands 声明，第三方 Services 不改动。

[PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
StandardAppCommands.swift: SwiftUI CommandGroup；在命令声明处解析应用菜单文案，保留 AppKit 动作及窗口能力校验；SwiftUI 管理窗口组的新建与关闭。

StandardEditingCommands.swift: SwiftUI + AppKit responder chain；编辑文案在声明处解析，焦点变化刷新校验、执行时重新路由，不保存 responder。

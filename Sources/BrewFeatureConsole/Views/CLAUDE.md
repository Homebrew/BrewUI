# Sources/BrewFeatureConsole/Views/
> L2 | 父级: ../CLAUDE.md

成员清单
ANSIConsoleText.swift: AppKit + BrewCore + BrewUIComponents；Renders output lines into the attributed text the console's text view displays.。
ConsoleBody.swift: BrewUIComponents + SwiftUI；Output area of the expanded console.。
ConsoleCommands.swift: BrewUIComponents + SwiftUI；特性菜单入口；切换语言不改变控制台展开偏好。
ConsoleOutputExport.swift: AppKit + BrewRepositoryInterfaces；View-layer AppKit bridge for saving/copying a command job's output. Lives at the view layer so the。
ConsolePanel.swift: BrewAccessibilityID + BrewRepositoryInterfaces + BrewUIComponents；Bottom-of-window console. Collapsed → status strip only. Expanded → toolbar + output body.。
ConsolePanelRoot.swift: BrewAppEnvironment + BrewRepositoryInterfaces + BrewUIComponents；App-window-owned root for the console feature: reads the shared command-jobs repository from the。
ConsoleStatusBar.swift: BrewAccessibilityID + BrewUIComponents + SwiftUI；控制台展示边界；保留命令原文及展开状态。
ConsoleStatusDot.swift: BrewUIComponents + SwiftUI；8pt status indicator for the console strip. Color follows design-system §4.3/§4.4:。
ConsoleTextView.swift: AppKit + BrewAccessibilityID + BrewCore；The console output as one selectable text document, so selection, ⌘A and ⌘C behave the way they do。
ConsoleToolbar.swift: BrewAccessibilityID + BrewCore + BrewRepositoryInterfaces；Expanded-console toolbar: selected-job pill on the left, Save/Copy/Clear + collapse chevron on the right.。
FocusedValues+Console.swift: BrewUIComponents + SwiftUI；FocusedValues 的既有实现。

[PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md

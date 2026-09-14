# CLAUDE.md
> Claude-specific extensions to `AGENTS.md`. Read `AGENTS.md` first — this file only adds Claude-specific behaviour on top of it.

---

## Memory Tools

When working in Cowork mode or Claude Code, use the todo list tool to track multi-step tasks within a session.
Use local `.ai/progress.md` only for personal continuity when needed (it is gitignored in this repo).

## Scope of This File

- `AGENTS.md` is the canonical, cross-agent policy source.
- `CLAUDE.md` should contain only Claude-specific behavior extensions.

## When Providing Code

Always include:
- Necessary imports (`Foundation`, `SwiftUI`, etc.)
- Complete, compilable examples — not pseudocode or stubs unless explicitly asked
- Error handling, not just the happy path
- `@MainActor` annotations wherever UI state is updated
- A brief comment explaining any non-obvious Swift behaviour
- After writing or editing code, briefly summarise what changed and why

```swift
import Foundation
import SwiftUI

@Observable
@MainActor
final class ExampleViewModel {
    var formulae: [Formula] = []

    func loadFormulae() async throws {
        formulae = try await repository.fetchInstalled()
    }
}
```


## 本次架构导航

Swift 6（以 Package.swift 为准）+ SwiftUI + Foundation String Catalog + Observation

<directory>
Homebrew/ - 应用组合根与资源；向稳定窗口注入实时语言环境。
Sources/ - 分层 SwiftPM 模块；本地化状态和消息解析位于 BrewUIComponents/Localization。
Tests/ - Swift Testing 契约；语言资源测试使用独立 Bundle 与偏好域。
BrewUITests/ - 假 brew 驱动的真实窗口验收；验证切换不重启或清空搜索。
</directory>
<config>
Package.swift - 模块依赖与编译隔离规则的真实基准。
Homebrew.xcodeproj/project.pbxproj - App 编译与英文、简体中文与繁体中文资源构建。
ARCHITECTURE.md - 全局依赖方向及运行时本地化边界。
</config>

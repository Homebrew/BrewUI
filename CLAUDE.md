# CLAUDE.md
> Claude-specific extensions to `AGENTS.md`. Read `AGENTS.md` first — this file only adds Claude-specific behaviour on top of it.

---

## Memory Tools

When working in Cowork mode or Claude Code, use the todo list tool to track multi-step tasks within a session. This complements (does not replace) `.ai/progress.md`, which is the persistent cross-session record.

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

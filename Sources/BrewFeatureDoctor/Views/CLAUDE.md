# Sources/BrewFeatureDoctor/Views/
> L2 | 父级: ../CLAUDE.md

成员清单
DoctorColumns.swift: BrewAppEnvironment + BrewCore + BrewRepositoryInterfaces；Dependency-composition boundary for the Doctor surface: reads app-level dependencies from the。
DoctorCopy.swift: Swift；Doctor copy that must match `brew doctor` word for word.。
DoctorIssueDetailView.swift: BrewCore + BrewUIComponents + SwiftUI；诊断展示边界；保持输出、命令和链接原样。
DoctorIssueRowView.swift: BrewUIComponents + SwiftUI；Doctor 列表展示，原始诊断标题与本地化操作提示分离。
DoctorSeverityStyle.swift: BrewCore + BrewUIComponents + SwiftUI；Doctor 共享展示策略；语言不改变严重程度身份。
DoctorView.swift: BrewAccessibilityID + BrewCore + BrewUIComponents；Doctor 展示层，切换语言不重新执行检查。

[PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md

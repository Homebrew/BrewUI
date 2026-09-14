# BrewUITests/Tests/
> L2 | 父级: ../CLAUDE.md

成员清单
ConfigUITests.swift: XCTest；The Configuration tab renders what `BrewConfigParser` made of the fake's `brew config` output.。
ConsoleUITests.swift: XCTest；Asserting on individual lines is what proves the output streamed rather than arriving at exit.。
DoctorUITests.swift: XCTest；The Doctor tab, where a non-zero exit means "found warnings" rather than "the command failed".。
ErrorStateUITests.swift: XCTest；Why this suite mocks process boundaries rather than repositories: every error here is real app code。
InstallUITests.swift: XCTest；The widest path in the app: catalogue over the HTTP seam, install over the shell seam, and the two。
InstalledUITests.swift: XCTest；The fake writes `--json=v2` to a real pipe, the real service drains it, the real repository decodes。
LaunchSmokeUITests.swift: XCTest；Harness smoke test. When it fails alongside half the suite, read it first: everything assumes it.。
ListFocusUITests.swift: XCTest；The list holds the keyboard after a tab switch, asserted through arrow-key navigation because that。
LocalizationUITests.swift: BrewAccessibilityID + XCTest；验收窗口标题实时切换、搜索与进程保留及运行任务连续性；使用假 brew，不修改宿主安装。
NavigationUITests.swift: XCTest；Every sidebar destination renders. A root that never appears is a crash or a composition mistake.。
SearchDismissUITests.swift: XCTest；Escape out of the search field. Unlike ``SearchFocusUITests`` these do click it: dismissal is what。
SearchFocusUITests.swift: XCTest；⌘F on each searchable tab. Nothing here may click the search field.。
SelfUpgradeUITests.swift: AppKit + BrewAccessibilityID + XCTest；The self-upgrade handshake end to end, with nothing simulated: the app really terminates, the real。
UninstallUITests.swift: XCTest；The row goes because `brew uninstall` exits 0, the centre publishes running→idle and the repository。

[PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md

# BrewUITests/Harness/
> L2 | 父级: ../CLAUDE.md

成员清单
BrewApp.swift: AppKit + BrewUITestContract + XCTest；UI runner 的组合入口；偏好域通过环境传给自升级后的进程。
BrewUITestCase.swift: BrewUITestContract + XCTest；UI runner 生命周期边界，不删除真实应用偏好。
BrewUITestDiagnostics.swift: XCTest；What the app looked like when an element wasn't found: "does not exist" cannot tell an app that。
BrewUITestScenario.swift: Foundation；The world a launch runs against: the fake `brew` serves `<scenario>/brew`, the stubbed `URLSession`。
FakeBrew.swift: BrewUITestContract + Foundation；UI 测试 CLI 边界，延迟仅来自测试数据，不调用真实 brew。

[PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md

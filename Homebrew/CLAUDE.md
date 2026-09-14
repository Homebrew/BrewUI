# Homebrew/
> L2 | 父级: ../CLAUDE.md

成员清单
Assets.xcassets/: 子模块边界；保持既有职责，本次未修改。
BrewApp.swift: BrewAppEnvironment + BrewCLI + BrewCore；应用组合根；语言变化仅更新环境，不重建业务服务或窗口身份。
Debug/: 子模块边界；保持既有职责，本次未修改。
Features/: 子模块边界；见 CLAUDE.md 的成员与依赖说明。
Localizable.xcstrings: 英文源文、简体中文与台湾用语繁体中文原生翻译资源，含占位符及复数。
SelfUpgrade/: 子模块边界；见 CLAUDE.md 的成员与依赖说明。
UITesting/: CLI/HTTP 测试隔离；支持 XCTest 参数及 Debug 专用后台 fixture 启动。
Utilities/: 子模块边界；保持既有职责，本次未修改。
Views/: 子模块边界；见 CLAUDE.md 的成员与依赖说明。

[PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md

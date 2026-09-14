# Homebrew/UITesting/
> L2 | 父级: ../CLAUDE.md

成员清单
BrewUITestingLaunchConfiguration.swift: Foundation；识别 XCTest 参数或 Debug 专用 fixture bundle，选择隔离测试载荷；普通及发行版启动不读取 bundle 测试标记。
BrewUITestingFixtureInstaller.swift: Foundation；将载荷写入本次启动临时目录，只对载荷中的假 brew 赋予执行权限。
BrewUITestingStubURLProtocol.swift: URLProtocol；将请求映射到当前 fixture 的 HTTP 数据，不访问真实网络。

[PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md

//
//  LoginShellResolverTests.swift
//  BrewCLITests
//

@testable import BrewCLI
import Foundation
import Testing

struct LoginShellResolverTests {
    @Test func `resolve returns lookup value when Directory Services yields a shell`() {
        let resolver = LoginShellResolver(
            lookup: { URL(fileURLWithPath: "/bin/bash") },
            fallback: URL(fileURLWithPath: "/bin/zsh"),
        )

        #expect(resolver.resolve().path == "/bin/bash")
    }

    @Test func `resolve falls back when lookup yields nil`() {
        let resolver = LoginShellResolver(
            lookup: { nil },
            fallback: URL(fileURLWithPath: "/bin/zsh"),
        )

        #expect(resolver.resolve().path == "/bin/zsh")
    }

    @Test func `default fallback is bin zsh`() {
        #expect(LoginShellResolver.defaultFallback.path == "/bin/zsh")
    }

    @Test func `directoryServicesLookup returns the running user's login shell when present`() {
        // Live probe — on macOS CI and dev machines the running user always has a pw_shell entry.
        // The value itself varies (zsh, bash, fish, …), so we only assert non-nil and absolute path.
        let resolved = LoginShellResolver.directoryServicesLookup()
        try? #require(resolved != nil)
        #expect(resolved?.path.hasPrefix("/") == true)
    }
}

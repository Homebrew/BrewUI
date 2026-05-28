@testable import BrewUILint
import Testing

@Suite("NonisolatedExtensionRule")
struct NonisolatedExtensionRuleTests {
    @Test
    func `nonisolated extension on nonisolated type passes`() {
        let source = """
        nonisolated struct Foo {}
        nonisolated extension Foo {
            var bar: Int { 1 }
        }
        """
        #expect(LintHarness.lintNonisolatedExtensionRule(source).isEmpty)
    }

    @Test
    func `bare extension on nonisolated struct fails`() {
        let source = """
        nonisolated struct Foo {}
        extension Foo {
            var bar: Int { 1 }
        }
        """
        let violations = LintHarness.lintNonisolatedExtensionRule(source)
        #expect(violations.count == 1)
        #expect(violations[0].ruleID == NonisolatedExtensionRule.identifier)
    }

    @Test
    func `bare extension on nonisolated enum fails`() {
        let source = """
        nonisolated enum Foo {
            case a
        }
        extension Foo {
            var label: String { "a" }
        }
        """
        #expect(LintHarness.lintNonisolatedExtensionRule(source).count == 1)
    }

    @Test
    func `bare extension on nonisolated class fails`() {
        let source = """
        nonisolated final class Foo {}
        extension Foo {
            func bar() {}
        }
        """
        #expect(LintHarness.lintNonisolatedExtensionRule(source).count == 1)
    }

    @Test
    func `bare extension on nonisolated actor fails`() {
        let source = """
        nonisolated actor Foo {}
        extension Foo {
            nonisolated var bar: Int { 1 }
        }
        """
        #expect(LintHarness.lintNonisolatedExtensionRule(source).count == 1)
    }

    @Test
    func `explicit MainActor extension on nonisolated type passes`() {
        let source = """
        nonisolated struct Foo {}
        @MainActor extension Foo {
            var bar: Int { 1 }
        }
        """
        #expect(LintHarness.lintNonisolatedExtensionRule(source).isEmpty)
    }

    @Test
    func `bare extension on non-nonisolated type ignored`() {
        let source = """
        struct Foo {}
        extension Foo {
            var bar: Int { 1 }
        }
        """
        #expect(LintHarness.lintNonisolatedExtensionRule(source).isEmpty)
    }

    @Test
    func `protocol conformance extension on nonisolated type fails`() {
        let source = """
        nonisolated struct Foo {}
        extension Foo: Equatable {
            static func == (lhs: Foo, rhs: Foo) -> Bool { true }
        }
        """
        #expect(LintHarness.lintNonisolatedExtensionRule(source).count == 1)
    }

    @Test
    func `multiple bare extensions on nonisolated type all flagged`() {
        let source = """
        nonisolated struct Foo {}
        extension Foo {
            var a: Int { 1 }
        }
        extension Foo {
            var b: Int { 2 }
        }
        """
        #expect(LintHarness.lintNonisolatedExtensionRule(source).count == 2)
    }

    @Test
    func `mixed nonisolated and bare extensions only flags the bare one`() {
        let source = """
        nonisolated struct Foo {}
        nonisolated extension Foo {
            var a: Int { 1 }
        }
        extension Foo {
            var b: Int { 2 }
        }
        """
        let violations = LintHarness.lintNonisolatedExtensionRule(source)
        #expect(violations.count == 1)
    }

    @Test
    func `extension declared before its nonisolated type still flagged`() {
        // The pre-pass collects type names regardless of declaration order, so an extension
        // appearing above its type declaration in the file is still recognised.
        let source = """
        extension Foo {
            var bar: Int { 1 }
        }
        nonisolated struct Foo {}
        """
        #expect(LintHarness.lintNonisolatedExtensionRule(source).count == 1)
    }
}

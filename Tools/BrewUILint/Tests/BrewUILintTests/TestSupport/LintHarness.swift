@testable import BrewUILint
import SwiftParser
import SwiftSyntax

enum LintHarness {
    static func lintPackageIDRule(_ source: String, file: String = "Test.swift") -> [Violation] {
        let tree = Parser.parse(source: source)
        let context = RuleContext(file: file, tree: tree)
        let rule = PackageIDRule()
        let visitor = rule.makeVisitor(context: context)
        visitor.walk(tree)
        return context.violations
    }

    /// Runs `NonisolatedExtensionRule` against a single source string, doing the same nonisolated
    /// type pre-pass that `Runner` does in production so the rule has cross-file context.
    static func lintNonisolatedExtensionRule(
        _ source: String,
        file: String = "Test.swift",
    ) -> [Violation] {
        let tree = Parser.parse(source: source)
        let collector = NonisolatedTypeCollector(viewMode: .sourceAccurate)
        collector.walk(tree)
        let context = RuleContext(
            file: file,
            tree: tree,
            nonisolatedTypeNames: collector.nonisolatedTypeNames,
        )
        let rule = NonisolatedExtensionRule()
        let visitor = rule.makeVisitor(context: context)
        visitor.walk(tree)
        return context.violations
    }
}

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
}

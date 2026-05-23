import Foundation
import SwiftParser
import SwiftSyntax

enum Runner {
    static func lint(files: [String]) throws -> [Violation] {
        var allViolations: [Violation] = []

        for path in files {
            let source = try String(contentsOfFile: path, encoding: .utf8)
            let tree = Parser.parse(source: source)
            let context = RuleContext(file: path, tree: tree)

            for ruleType in RuleRegistry.allRules {
                let rule = ruleType.init()
                let visitor = rule.makeVisitor(context: context)
                visitor.walk(tree)
            }

            allViolations.append(contentsOf: context.violations)
        }

        return allViolations
    }
}

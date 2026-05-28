import Foundation
import SwiftParser
import SwiftSyntax

enum Runner {
    static func lint(files: [String]) throws -> [Violation] {
        var allViolations: [Violation] = []

        // Parse every file once and collect cross-file context (e.g. nonisolated type names) so
        // rules can relate declarations in one file to references in another. Per-file invocations
        // (build plugin) only see one file's types here, which is fine — the all-files invocation
        // used by CI catches the cross-file cases.
        var parsedFiles: [(path: String, tree: SourceFileSyntax)] = []
        parsedFiles.reserveCapacity(files.count)
        var nonisolatedTypeNames: Set<String> = []

        for path in files {
            let source = try String(contentsOfFile: path, encoding: .utf8)
            let tree = Parser.parse(source: source)
            parsedFiles.append((path: path, tree: tree))

            let collector = NonisolatedTypeCollector(viewMode: .sourceAccurate)
            collector.walk(tree)
            nonisolatedTypeNames.formUnion(collector.nonisolatedTypeNames)
        }

        for (path, tree) in parsedFiles {
            let context = RuleContext(
                file: path,
                tree: tree,
                nonisolatedTypeNames: nonisolatedTypeNames,
            )

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

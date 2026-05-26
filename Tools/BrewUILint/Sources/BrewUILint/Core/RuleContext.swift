import SwiftSyntax

final class RuleContext {
    var violations: [Violation] = []
    let file: String
    let converter: SourceLocationConverter
    /// Names of every type declared with the `nonisolated` modifier across all files being linted
    /// in this run. Populated by `Runner` before rules walk; rules use this to relate an extension
    /// declared in one file back to the type it extends in another.
    let nonisolatedTypeNames: Set<String>

    init(
        file: String,
        tree: SourceFileSyntax,
        nonisolatedTypeNames: Set<String> = [],
    ) {
        self.file = file
        self.nonisolatedTypeNames = nonisolatedTypeNames
        converter = SourceLocationConverter(fileName: file, tree: tree)
    }

    func record(
        rule: any Rule.Type,
        at position: some SyntaxProtocol,
    ) {
        let location = position.startLocation(converter: converter)
        violations.append(
            Violation(
                ruleID: rule.identifier,
                message: rule.message,
                line: location.line,
                column: location.column,
                file: file,
            ),
        )
    }
}

import SwiftSyntax

final class RuleContext {
    var violations: [Violation] = []
    let file: String
    let converter: SourceLocationConverter

    init(file: String, tree: SourceFileSyntax) {
        self.file = file
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

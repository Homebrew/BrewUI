import SwiftSyntax

protocol Rule {
    static var identifier: String { get }
    static var message: String { get }
    func makeVisitor(context: RuleContext) -> SyntaxVisitor
}

struct Violation: Equatable {
    let ruleID: String
    let message: String
    let line: Int
    let column: Int
    let file: String
}

extension Violation {
    var xcodeFormatted: String {
        "\(file):\(line):\(column): warning: \(message) (\(ruleID))"
    }
}

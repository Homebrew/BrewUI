import SwiftSyntax

/// Only UI packages may hold user-facing copy.
struct LocalizationLayerRule: Rule {
    static let identifier = "localization_layer"
    static let message =
        "User-facing copy lives only in UI packages (Sources/BrewUIComponents, Sources/BrewFeature*, Homebrew). " +
        "Throw a typed error enum from this layer and word it in BrewUIComponents/Copy."

    func makeVisitor(context: RuleContext) -> SyntaxVisitor {
        LocalizationLayerVisitor(context: context)
    }

    /// Matched against any path suffix: CI passes absolute paths, the build plugin relative ones.
    static func isUILayer(_ file: String) -> Bool {
        let components = file.split(separator: "/").map(String.init)
        guard let sourcesIndex = components.lastIndex(where: { $0 == "Sources" || $0 == "Homebrew" }) else {
            return false
        }
        if components[sourcesIndex] == "Homebrew" {
            return true
        }
        guard sourcesIndex + 1 < components.count else {
            return false
        }
        let target = components[sourcesIndex + 1]
        return target == "BrewUIComponents" || target.hasPrefix("BrewFeature")
    }

    static let localizingCalls: Set<String> = [
        "NSLocalizedString", "LocalizedStringResource", "LocalizedStringKey",
    ]
}

private final class LocalizationLayerVisitor: SyntaxVisitor {
    private let context: RuleContext
    private let isUILayer: Bool

    init(context: RuleContext) {
        self.context = context
        isUILayer = LocalizationLayerRule.isUILayer(context.file)
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard !isUILayer, let name = calleeName(node.calledExpression) else {
            return .visitChildren
        }
        let localizes = LocalizationLayerRule.localizingCalls.contains(name)
            || ((name == "String" || name == "AttributedString") && node.arguments.first?.label?.text == "localized")
            || (name == "Text" && node.arguments.first?.label == nil
                && node.arguments.first?.expression.is(StringLiteralExprSyntax.self) == true)
        if localizes {
            context.record(rule: LocalizationLayerRule.self, at: node)
            return .skipChildren
        }
        return .visitChildren
    }

    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        if !isUILayer, node.macroName.text == "bundle" {
            context.record(rule: LocalizationLayerRule.self, at: node)
        }
        return .visitChildren
    }

    private func calleeName(_ expression: ExprSyntax) -> String? {
        if let reference = expression.as(DeclReferenceExprSyntax.self) {
            return reference.baseName.text
        }
        if let member = expression.as(MemberAccessExprSyntax.self), !member.callsThroughValue {
            return member.declName.baseName.text
        }
        return nil
    }
}

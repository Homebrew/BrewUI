import SwiftSyntax

/// Every user-facing literal must resolve against its own module's catalog and carry a translator
/// comment. Package targets look strings up in `Bundle.main` unless told otherwise, so a bare
/// `Text("…")` or `Button("…")` silently never localises.
struct LocalizedCopyRule: Rule {
    static let identifier = "localized_copy"
    static let message =
        "Copy must be `Text(\"…\", bundle: #bundle, comment: \"…\")`, " +
        "`String(localized: \"…\", bundle: #bundle, comment: \"…\")`, or `Text(verbatim:)` when it is not copy " +
        "(versions, package names, commands). Carry copy as `String`, never `LocalizedStringKey`."

    func makeVisitor(context: RuleContext) -> SyntaxVisitor {
        LocalizedCopyVisitor(context: context)
    }

    /// Calls whose first unlabeled argument is a localised key with no way to pass a bundle.
    static let keyTakingControls: Set<String> = [
        "Button", "Label", "Toggle", "Section", "Link", "Menu", "Picker", "TextField", "SecureField",
        "TableColumn", "ContentUnavailableView", "CommandMenu", "LabeledContent", "Tab", "DisclosureGroup",
        "Stepper", "DatePicker", "NavigationLink", "ProgressView", "Alert", "MenuBarExtra", "TextEditor",
    ]

    static let keyTakingModifiers: Set<String> = [
        "help", "navigationTitle", "navigationSubtitle", "accessibilityLabel", "accessibilityHint",
        "accessibilityValue", "accessibilityInputLabels", "alert", "confirmationDialog", "badge", "tabItem",
        "navigationDocument", "toolbarTitleMenu", "typeSelectEquivalent",
    ]

    /// Labeled arguments that take a localised key on otherwise-fine modifiers (`.searchable(prompt:)`).
    static let keyTakingLabels: Set<String> = ["prompt"]

    static let localizedInitializers: Set<String> = ["String", "AttributedString", "LocalizedStringResource"]
}

private final class LocalizedCopyVisitor: SyntaxVisitor {
    private let context: RuleContext

    init(context: RuleContext) {
        self.context = context
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let callee = calleeName(node.calledExpression) else {
            return .visitChildren
        }
        let arguments = node.arguments
        let labels = Set(arguments.compactMap { $0.label?.text })
        let first = arguments.first

        if LocalizedCopyRule.localizedInitializers.contains(callee.name) {
            let isLocalizedForm = first?.label?.text == "localized"
                || (callee.name == "LocalizedStringResource" && first?.label == nil && isCopyLiteral(first?.expression))
            if isLocalizedForm, !labels.isSuperset(of: ["bundle", "comment"]) {
                context.record(rule: LocalizedCopyRule.self, at: node)
            }
        } else if callee.name == "NSLocalizedString", !callee.isMember {
            context.record(rule: LocalizedCopyRule.self, at: node)
        } else if callee.name == "Text", !callee.isMember {
            if let first, first.label == nil, isCopyLiteral(first.expression),
               !labels.isSuperset(of: ["bundle", "comment"])
            {
                context.record(rule: LocalizedCopyRule.self, at: node)
            }
        } else if callee.isMember ? LocalizedCopyRule.keyTakingModifiers.contains(callee.name)
            : LocalizedCopyRule.keyTakingControls.contains(callee.name)
        {
            if let first, first.label == nil, isCopyLiteral(first.expression) {
                context.record(rule: LocalizedCopyRule.self, at: first)
            }
        }

        for argument in arguments
            where argument.label.map({ LocalizedCopyRule.keyTakingLabels.contains($0.text) }) == true
            && callee.isMember
            && isCopyLiteral(argument.expression)
        {
            context.record(rule: LocalizedCopyRule.self, at: argument)
        }
        return .visitChildren
    }

    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == "LocalizedStringKey" {
            context.record(rule: LocalizedCopyRule.self, at: node)
        }
        return .visitChildren
    }

    private struct Callee {
        let name: String
        let isMember: Bool
    }

    private func calleeName(_ expression: ExprSyntax) -> Callee? {
        if let reference = expression.as(DeclReferenceExprSyntax.self) {
            return Callee(name: reference.baseName.text, isMember: false)
        }
        if let member = expression.as(MemberAccessExprSyntax.self) {
            return Callee(name: member.declName.baseName.text, isMember: member.base != nil)
        }
        return nil
    }

    /// A string literal with at least one letter or interpolation; `""` and `"→"` are not copy.
    /// Looks through `a ? "x" : "y"` and `a ?? "x"`, which parse as unresolved sequences.
    private func isCopyLiteral(_ expression: ExprSyntax?) -> Bool {
        guard let expression else {
            return false
        }
        if let sequence = expression.as(SequenceExprSyntax.self) {
            return sequence.elements.contains { element in
                if let ternary = element.as(UnresolvedTernaryExprSyntax.self) {
                    return isCopyLiteral(ternary.thenExpression)
                }
                return isCopyLiteral(element)
            }
        }
        guard let literal = expression.as(StringLiteralExprSyntax.self) else {
            return false
        }
        return literal.segments.contains { segment in
            segment.as(StringSegmentSyntax.self)?.content.text.contains(where: \.isLetter) == true
                || segment.is(ExpressionSegmentSyntax.self)
        }
    }
}

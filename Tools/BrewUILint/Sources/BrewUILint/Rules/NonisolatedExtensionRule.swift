import SwiftSyntax

/// Flags `extension X { ... }` where `X` is declared `nonisolated` but the extension itself has
/// no isolation modifier. Under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` the unannotated
/// extension silently inherits MainActor from the file default — even though the type is
/// nonisolated — and any nonisolated caller (background `Task`, `@Sendable` closure, test) hitting
/// the extension's members will trap at runtime with `swift_task_checkIsolated`.
///
/// The fix is one of:
/// - Mark the extension `nonisolated` (the usual case for value-type domain helpers).
/// - Mark it `@MainActor` if MainActor isolation is intentional here.
struct NonisolatedExtensionRule: Rule {
    static let identifier = "nonisolated_extension_isolation"
    static let message =
        "Extension on a `nonisolated` type is missing an isolation modifier. " +
        "Without it, members inherit MainActor from the file default and trap at runtime " +
        "when called from nonisolated callers. Mark the extension `nonisolated`, or add " +
        "`@MainActor` if MainActor isolation is intentional here."

    func makeVisitor(context: RuleContext) -> SyntaxVisitor {
        NonisolatedExtensionVisitor(context: context)
    }
}

private final class NonisolatedExtensionVisitor: SyntaxVisitor {
    private let context: RuleContext

    init(context: RuleContext) {
        self.context = context
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let extendedName = extendedTypeName(node.extendedType),
              context.nonisolatedTypeNames.contains(extendedName),
              !hasIsolationAnnotation(node)
        else {
            return .visitChildren
        }

        context.record(rule: NonisolatedExtensionRule.self, at: node.extensionKeyword)
        return .visitChildren
    }

    private func extendedTypeName(_ type: TypeSyntax) -> String? {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            return identifier.name.text
        }
        if let member = type.as(MemberTypeSyntax.self) {
            return member.name.text
        }
        return nil
    }

    private func hasIsolationAnnotation(_ node: ExtensionDeclSyntax) -> Bool {
        if node.modifiers.contains(where: { $0.name.text == "nonisolated" }) {
            return true
        }

        for attribute in node.attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else {
                continue
            }
            // Any global actor attribute counts as "explicit isolation". Recognising every
            // global actor name in the codebase is out of scope; `@MainActor` is the only one
            // BrewUI uses today, but the principle is the same for any future global actor.
            if attr.attributeName.trimmedDescription == "MainActor" {
                return true
            }
        }

        return false
    }
}

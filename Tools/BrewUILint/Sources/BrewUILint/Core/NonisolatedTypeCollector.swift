import SwiftSyntax

/// Walks a parsed file and collects the names of types declared with the `nonisolated` modifier
/// at the type-declaration level (e.g. `nonisolated struct Foo`, `nonisolated enum Bar`).
///
/// `Runner` runs this across every file before linting so rules can decide whether to flag an
/// extension as missing isolation — the type being extended may live in a different file.
final class NonisolatedTypeCollector: SyntaxVisitor {
    private(set) var nonisolatedTypeNames: Set<String> = []

    override init(viewMode: SyntaxTreeViewMode) {
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        recordIfNonisolated(name: node.name.text, modifiers: node.modifiers)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        recordIfNonisolated(name: node.name.text, modifiers: node.modifiers)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        recordIfNonisolated(name: node.name.text, modifiers: node.modifiers)
        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        recordIfNonisolated(name: node.name.text, modifiers: node.modifiers)
        return .visitChildren
    }

    private func recordIfNonisolated(name: String, modifiers: DeclModifierListSyntax) {
        if modifiers.contains(where: { $0.name.text == "nonisolated" }) {
            nonisolatedTypeNames.insert(name)
        }
    }
}

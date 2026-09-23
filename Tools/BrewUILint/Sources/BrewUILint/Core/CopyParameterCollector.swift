import SwiftSyntax

/// Which initializer arguments of each project type are declared `LocalizedStringResource`, from
/// both the memberwise initializer and explicit `init`s. `Runner` collects these across all files
/// before linting.
final class CopyParameterCollector: SyntaxVisitor {
    /// Stands in for the first argument of a call when the initializer declares it unlabeled.
    static let positionalLabel = "_"

    private(set) var copyParameters: [String: Set<String>] = [:]

    override init(viewMode: SyntaxTreeViewMode) {
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        record(typeName: node.name.text, members: node.memberBlock.members)
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        record(typeName: node.name.text, members: node.memberBlock.members)
        return .visitChildren
    }

    private func record(typeName: String, members: MemberBlockItemListSyntax) {
        var labels: Set<String> = []
        for member in members {
            if let variable = member.decl.as(VariableDeclSyntax.self) {
                labels.formUnion(storedCopyProperties(variable))
            }
            if let initializer = member.decl.as(InitializerDeclSyntax.self) {
                labels.formUnion(copyParameters(of: initializer))
            }
        }
        guard !labels.isEmpty else {
            return
        }
        copyParameters[typeName, default: []].formUnion(labels)
    }

    /// Stored properties only: a computed property is not a memberwise-initializer parameter.
    private func storedCopyProperties(_ variable: VariableDeclSyntax) -> Set<String> {
        var labels: Set<String> = []
        for binding in variable.bindings {
            guard binding.accessorBlock == nil,
                  let annotation = binding.typeAnnotation,
                  isCopyType(annotation.type),
                  let identifier = binding.pattern.as(IdentifierPatternSyntax.self)
            else {
                continue
            }
            labels.insert(identifier.identifier.text)
        }
        return labels
    }

    private func copyParameters(of initializer: InitializerDeclSyntax) -> Set<String> {
        var labels: Set<String> = []
        for (index, parameter) in initializer.signature.parameterClause.parameters.enumerated()
            where isCopyType(parameter.type)
        {
            let label = parameter.firstName.text
            if label == Self.positionalLabel {
                // Only a leading `_` is matchable; later ones shift once earlier arguments default away.
                if index == 0 {
                    labels.insert(Self.positionalLabel)
                }
            } else {
                labels.insert(label)
            }
        }
        return labels
    }

    private func isCopyType(_ type: TypeSyntax) -> Bool {
        if let optional = type.as(OptionalTypeSyntax.self) {
            return isCopyType(optional.wrappedType)
        }
        return type.as(IdentifierTypeSyntax.self)?.name.text == "LocalizedStringResource"
    }
}

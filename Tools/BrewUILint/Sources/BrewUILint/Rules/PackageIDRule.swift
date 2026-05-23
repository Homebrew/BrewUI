import SwiftSyntax

struct PackageIDRule: Rule {
    static let identifier = "package_id_type"
    static let message =
        "Types whose name contains 'Package' must declare `id` as `HomebrewPackageID` (or `HomebrewPackageID?`)."

    func makeVisitor(context: RuleContext) -> SyntaxVisitor {
        PackageIDVisitor(context: context)
    }
}

private final class PackageIDVisitor: SyntaxVisitor {
    private let context: RuleContext
    private var enclosingTypeNames: [String] = []

    init(context: RuleContext) {
        self.context = context
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        pushTypeName(node.name.text)
        return .visitChildren
    }

    override func visitPost(_: StructDeclSyntax) {
        popTypeName()
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        pushTypeName(node.name.text)
        return .visitChildren
    }

    override func visitPost(_: ClassDeclSyntax) {
        popTypeName()
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        pushTypeName(node.name.text)
        return .visitChildren
    }

    override func visitPost(_: EnumDeclSyntax) {
        popTypeName()
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        pushTypeName(node.name.text)
        return .visitChildren
    }

    override func visitPost(_: ActorDeclSyntax) {
        popTypeName()
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        pushTypeName(node.extendedType.trimmedDescription)
        return .visitChildren
    }

    override func visitPost(_: ExtensionDeclSyntax) {
        popTypeName()
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard isInsidePackageNamedType else {
            return .skipChildren
        }

        for binding in node.bindings {
            guard bindingPatternIsID(binding.pattern) else {
                continue
            }

            guard let typeAnnotation = binding.typeAnnotation?.type else {
                context.record(rule: PackageIDRule.self, at: binding)
                continue
            }

            if !PackageIDTypeMatcher.isHomebrewPackageID(typeAnnotation) {
                context.record(rule: PackageIDRule.self, at: typeAnnotation)
            }
        }

        return .skipChildren
    }

    private var isInsidePackageNamedType: Bool {
        enclosingTypeNames.contains { $0.contains("Package") }
    }

    private func pushTypeName(_ name: String) {
        enclosingTypeNames.append(name)
    }

    private func popTypeName() {
        _ = enclosingTypeNames.popLast()
    }

    private func bindingPatternIsID(_ pattern: PatternSyntax) -> Bool {
        guard let identifierPattern = pattern.as(IdentifierPatternSyntax.self) else {
            return false
        }
        return identifierPattern.identifier.text == "id"
    }
}

private enum PackageIDTypeMatcher {
    private static let canonicalTypeName = "HomebrewPackageID"

    static func isHomebrewPackageID(_ type: TypeSyntax) -> Bool {
        if let optional = type.as(OptionalTypeSyntax.self) {
            return isHomebrewPackageID(optional.wrappedType)
        }

        if let identifierType = type.as(IdentifierTypeSyntax.self),
           identifierType.name.text == "Self"
        {
            return true
        }

        if let memberType = type.as(MemberTypeSyntax.self) {
            return memberType.baseType.trimmedDescription == canonicalTypeName
        }

        if let identifierType = type.as(IdentifierTypeSyntax.self),
           identifierType.name.text == canonicalTypeName
        {
            return true
        }

        return type.trimmedDescription == canonicalTypeName
    }
}

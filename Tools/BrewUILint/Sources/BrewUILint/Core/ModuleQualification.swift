import SwiftSyntax

/// `SwiftUI.Text("…")` is the same call as `Text("…")`, so a module prefix must not hide copy from
/// a rule.
enum ModuleQualification {
    static let moduleNames: Set<String> = ["Swift", "Foundation", "SwiftUI", "AppKit"]
}

extension MemberAccessExprSyntax {
    /// Whether the callee is reached through a value rather than named directly.
    var callsThroughValue: Bool {
        guard let base else {
            return false
        }
        guard let reference = base.as(DeclReferenceExprSyntax.self) else {
            return true
        }
        return !ModuleQualification.moduleNames.contains(reference.baseName.text)
    }
}

extension MemberTypeSyntax {
    /// Whether the type is only prefixed with the module it comes from.
    var namesAModuleMember: Bool {
        guard let base = baseType.as(IdentifierTypeSyntax.self) else {
            return false
        }
        return ModuleQualification.moduleNames.contains(base.name.text)
    }
}

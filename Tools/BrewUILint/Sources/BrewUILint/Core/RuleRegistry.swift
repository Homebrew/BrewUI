enum RuleRegistry {
    static let allRules: [any Rule.Type] = [
        PackageIDRule.self,
        NonisolatedExtensionRule.self,
    ]
}

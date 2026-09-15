@testable import BrewUILint
import Testing

@Suite("LocalizationLayerRule")
struct LocalizationLayerRuleTests {
    private static let localizing = [
        #"let s = String(localized: "Homebrew command failed.", bundle: #bundle, comment: "c")"#,
        #"let s = NSLocalizedString("Homebrew command failed.", comment: "")"#,
        #"let r = LocalizedStringResource("Homebrew command failed.", bundle: #bundle, comment: "c")"#,
        #"let b = #bundle"#,
        #"let t = Text("Homebrew command failed.", bundle: #bundle, comment: "c")"#,
    ]

    @Test(arguments: [
        "Sources/BrewUIComponents/Copy/BrewErrorCopy.swift",
        "Sources/BrewFeatureDoctor/Views/DoctorView.swift",
        "Sources/BrewFeatureInstalled/ViewModels/InstalledViewModel.swift",
        "Homebrew/Views/SidebarItem.swift",
        "/Users/ci/work/BrewUI/Sources/BrewFeatureConsole/Views/ConsoleBody.swift",
    ])
    func `UI layers may localise`(file: String) {
        for source in Self.localizing {
            #expect(LintHarness.lintLocalizationLayerRule(source, file: file).isEmpty, "\(source)")
        }
    }

    @Test(arguments: [
        "Sources/BrewCore/Operations/OperationFailure.swift",
        "Sources/BrewRepositories/BrewInstalledPackagesRepository.swift",
        "Sources/BrewRepositoryInterfaces/RepositoryError.swift",
        "Sources/BrewCLI/BrewCommandService.swift",
        "Sources/BrewNetworking/BrewAPIClient.swift",
        "Sources/BrewServicesTestSupport/InstalledPackagesTestSupport.swift",
        "/Users/ci/work/Homebrew/Sources/BrewCore/X.swift",
    ])
    func `other layers may not localise`(file: String) {
        for source in Self.localizing {
            let violations = LintHarness.lintLocalizationLayerRule(source, file: file)
            #expect(violations.count == 1 && violations.first?.ruleID == LocalizationLayerRule.identifier, "\(source)")
        }
    }

    @Test
    func `typed errors and plain strings are fine anywhere`() {
        let source = """
        public enum BrewRepositoryError: Error { case malformedBrewOutput(command: String) }
        let diagnostic = "brew exited \\(code)"
        logger.error("Tap refresh failed: \\(error.localizedDescription, privacy: .public)")
        """
        let file = "Sources/BrewRepositories/BrewInstalledPackagesRepository.swift"
        #expect(LintHarness.lintLocalizationLayerRule(source, file: file).isEmpty)
    }
}

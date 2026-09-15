@testable import BrewUILint
import Testing

@Suite("LocalizedCopyRule")
struct LocalizedCopyRuleTests {
    @Test(arguments: [
        #"Text("Doctor", bundle: #bundle, comment: "Doctor tab heading")"#,
        #"Text(verbatim: "v\(version)")"#,
        #"Text(viewModel.subtitle)"#,
        #"Text(count, format: .number)"#,
        #"Button(String(localized: "Run Again", bundle: #bundle, comment: "Doctor: re-run")) {}"#,
        #"Button(action: run) { Text(verbatim: "Debug") }"#,
        #"let s = String(localized: "Loading…", bundle: #bundle, comment: "Subtitle")"#,
        #"let s = String(localized: "\(count) packages", bundle: #bundle, comment: "%lld is the count")"#,
        #"view.help(String(localized: "Dismiss", bundle: #bundle, comment: "Tooltip"))"#,
        #"view.accessibilityLabel(title)"#,
        #"let s = String(localized: viewModel.subtitle)"#,
        #"let s = String(localized: section.title)"#,
        #"Text("→")"#,
        #"Text("")"#,
        #"Label(item.title, systemImage: "gear")"#,
        #"Image(systemName: "checkmark")"#,
        #"Color("WindowBase", bundle: .module)"#,
        #"logger.info("Refreshing installed packages")"#,
        #"SwiftUI.Text("Doctor", bundle: #bundle, comment: "Doctor tab heading")"#,
    ])
    func `accepted forms pass`(source: String) {
        #expect(LintHarness.lintLocalizedCopyRule(source).isEmpty)
    }

    @Test(arguments: [
        #"Text("Doctor")"#,
        #"Text("Doctor", bundle: #bundle)"#,
        #"Text("Doctor", comment: "Heading")"#,
        #"Text("\(lead) \(time)")"#,
        #"Button("Run Again") {}"#,
        #"Button("Cancel", role: .cancel) {}"#,
        #"Label("Refresh", systemImage: "arrow.clockwise")"#,
        #"Toggle("Expand automatically", isOn: $flag)"#,
        #"Picker("Scope", selection: $scope) {}"#,
        #"Section("Details") {}"#,
        #"Link("Homebrew Documentation", destination: url)"#,
        #"Menu("Force Crash") {}"#,
        #"CommandMenu("Debug") {}"#,
        #"ContentUnavailableView("No activity", systemImage: "terminal")"#,
        #"let s = String(localized: "Loading…")"#,
        #"let s = String(localized: "Loading…", comment: "Subtitle")"#,
        #"let s = String(localized: "Loading…", bundle: .module)"#,
        #"let r = LocalizedStringResource("Run Again")"#,
        #"let s = NSLocalizedString("Run Again", comment: "")"#,
        #"view.help("Dismiss")"#,
        #"view.navigationTitle("Doctor")"#,
        #"view.navigationSubtitle("Browse \(count) packages")"#,
        #"view.accessibilityLabel("Installed packages")"#,
        #"view.accessibilityHint("Opens the package")"#,
        #"view.alert("Failed", isPresented: $shown) {}"#,
        #"view.confirmationDialog("Uninstall?", isPresented: $shown) {}"#,
        #"view.searchable(text: $query, prompt: "Search Packages")"#,
        #"view.accessibilityLabel(expanded ? "Hide console" : "Show console")"#,
        #"view.accessibilityHint(hint ?? "Opens the package")"#,
        #"var title: LocalizedStringKey { "Installed" }"#,
        #"func row(actionTitle: LocalizedStringKey?) {}"#,
        // A module prefix names the same call.
        #"SwiftUI.Text("Doctor")"#,
        #"let s = Swift.String(localized: "Loading…")"#,
        #"let s = Foundation.NSLocalizedString("Run Again", comment: "")"#,
        #"var title: SwiftUI.LocalizedStringKey { "Installed" }"#,
        #"func row(actionTitle: SwiftUI.LocalizedStringKey?) {}"#,
        // A bundle that is not the package's own never finds the key.
        #"Text("Doctor", bundle: .main, comment: "Heading")"#,
        #"let s = String(localized: "Loading…", bundle: Bundle.main, comment: "Subtitle")"#,
        #"let r = LocalizedStringResource("Run Again", bundle: resourceBundle, comment: "Doctor: re-run")"#,
    ])
    func `bare copy fails`(source: String) {
        let violations = LintHarness.lintLocalizedCopyRule(source)
        #expect(violations.count == 1 && violations.first?.ruleID == LocalizedCopyRule.identifier)
    }

    // MARK: - Project components

    @Test(arguments: [
        #"BrewActionButton("Retry", systemImage: "arrow.clockwise") {}"#,
        #"BrewActionButton(LocalizedStringResource("Retry", bundle: #bundle, comment: "x"), confirmationTitle: "Copied") {}"#,
        #"PackageDetailSectionHeading(title: "Details")"#,
        #"CommandBlockView(command: viewModel.command, summaryText: "Installs this package")"#,
    ])
    func `bare copy passed to a project component fails`(call: String) {
        let source = """
        struct BrewActionButton: View {
            init(
                _ title: LocalizedStringResource,
                systemImage: String = "",
                confirmationTitle: LocalizedStringResource? = nil,
                action: () -> Void,
            ) {}
        }
        struct PackageDetailSectionHeading: View {
            let title: LocalizedStringResource
        }
        struct CommandBlockView: View {
            let command: String
            let summaryText: LocalizedStringResource?
        }
        struct Caller: View {
            var body: some View { \(call) }
        }
        """
        let violations = LintHarness.lintLocalizedCopyRule(source)
        #expect(violations.count == 1 && violations.first?.ruleID == LocalizedCopyRule.identifier)
    }

    @Test(arguments: [
        #"BrewActionButton(title, systemImage: "arrow.clockwise")"#,
        #"CommandBlockView(command: "brew upgrade git")"#,
        #"PackageDetailSectionHeading(title: LocalizedStringResource("Details", bundle: #bundle, comment: "x"))"#,
        #"PackageDetailSectionHeading(title: viewModel.heading)"#,
        #"SomeOtherType(title: "Details")"#,
    ])
    func `non-copy arguments to a project component pass`(call: String) {
        let source = """
        struct BrewActionButton: View {
            init(_ title: LocalizedStringResource, systemImage: String = "") {}
        }
        struct PackageDetailSectionHeading: View {
            let title: LocalizedStringResource
        }
        struct CommandBlockView: View {
            let command: String
            let summaryText: LocalizedStringResource?
        }
        struct Caller: View {
            var body: some View { \(call) }
        }
        """
        #expect(LintHarness.lintLocalizedCopyRule(source).isEmpty)
    }

    @Test
    func `preview sample copy is exempt from the component check`() {
        let source = """
        struct NoteCallout: View {
            let text: LocalizedStringResource
        }
        #if DEBUG
            #Preview("Note callout") {
                NoteCallout(text: "Casks and formulae are installed to different prefixes.")
            }
        #endif
        """
        #expect(LintHarness.lintLocalizedCopyRule(source).isEmpty)
    }

    @Test
    func `a preview does not exempt the SwiftUI checks`() {
        let source = """
        #Preview {
            Button("Run Again") {}
        }
        """
        #expect(LintHarness.lintLocalizedCopyRule(source).count == 1)
    }

    @Test
    func `debug-only code is held to the same rule`() {
        let source = """
        #if DEBUG
            struct DebugMenu: Commands {
                var body: some Commands { CommandMenu("Debug") {} }
            }
        #endif
        """
        #expect(LintHarness.lintLocalizedCopyRule(source).count == 1)
    }

    @Test
    func `violations point at the offending line`() {
        let source = """
        struct V: View {
            var body: some View {
                Text("Doctor", bundle: #bundle, comment: "Heading")
                Button("Run Again") {}
            }
        }
        """
        #expect(LintHarness.lintLocalizedCopyRule(source).map(\.line) == [4])
    }
}

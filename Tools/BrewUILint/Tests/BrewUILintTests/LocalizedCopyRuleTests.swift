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
        #"Text("→")"#,
        #"Text("")"#,
        #"Label(item.title, systemImage: "gear")"#,
        #"Image(systemName: "checkmark")"#,
        #"Color("WindowBase", bundle: .module)"#,
        #"logger.info("Refreshing installed packages")"#,
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
    ])
    func `bare copy fails`(source: String) {
        let violations = LintHarness.lintLocalizedCopyRule(source)
        #expect(violations.count == 1 && violations.first?.ruleID == LocalizedCopyRule.identifier)
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

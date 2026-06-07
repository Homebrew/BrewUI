//
//  ConfigEnvironmentEditorCard.swift
//  BrewFeatureConfig
//

import BrewCore
import BrewUIComponents
import SwiftUI

/// Editable Environment card: replaces the read-only `HOMEBREW_*` section with typed controls per
/// allowlist row, read-only badges for shell-overridden / install-time keys, and an inline form for
/// adding custom `HOMEBREW_*` values. All edits flow through the view model's draft and only land in
/// `brew.env` when the header's Save button is pressed.
struct ConfigEnvironmentEditorCard: View {
    @Bindable var viewModel: ConfigViewModel
    /// The currently loaded `brew.env` content from the page payload. Drives row provenance and lets
    /// `AsyncContentView`'s placeholder render a realistic redacted skeleton.
    let envFile: BrewEnvFile

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            PackageDetailSectionHeading(title: "Environment (HOMEBREW_*)")

            if let saveError = viewModel.saveError {
                saveErrorBanner(saveError)
            }

            ForEach(viewModel.envRows(envFile: envFile)) { row in
                ConfigEnvironmentRow(row: row, viewModel: viewModel)
            }

            Divider()
                .overlay(Color.brewBorderSeparator)

            ConfigCustomRowAffordance(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrewSpacing.lg)
        .background(Color.brewSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.lg)
                .stroke(Color.brewBorderDefault, lineWidth: 1),
        )
    }

    private func saveErrorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: BrewSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.brewSubheadline)
                .foregroundStyle(Color.brewStatusError)
            Text(message)
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextPrimary)
        }
        .padding(BrewSpacing.sm)
        .background(Color.brewStatusErrorSubtle)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
    }
}

/// One Environment row. Switches on `row.status` to pick the right control (toggle / integer /
/// string / secret) or a read-only presentation with a provenance badge and shell-rc hint.
private struct ConfigEnvironmentRow: View {
    let row: EnvRowItem
    @Bindable var viewModel: ConfigViewModel

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: BrewSpacing.md) {
            labelColumn
                .frame(width: 240, alignment: .leading)
            valueColumn
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, BrewSpacing.xxs)
    }

    private var labelColumn: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
            Text(row.descriptor?.label ?? row.key)
                .font(.brewCallout.weight(.medium))
                .foregroundStyle(Color.brewTextPrimary)
            Text(row.key)
                .font(.brewCaption2)
                .foregroundStyle(Color.brewTextTertiary)
                .textSelection(.enabled)
            if let summary = row.descriptor?.summary {
                Text(summary)
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var valueColumn: some View {
        switch row.status {
        case let .editable(kind):
            editableControl(for: kind)
        case let .readOnlyShellOverridden(rcHint):
            readOnlyValue(badge: "set by your shell", hint: "Remove the export from \(rcHint) to edit here.")
        case .readOnlyInstallTime:
            readOnlyValue(
                badge: "fixed at install",
                hint: "Set by Homebrew at install time — can't be changed in brew.env.",
            )
        }
    }

    @ViewBuilder
    private func editableControl(for kind: EnvKeyDescriptor.Kind) -> some View {
        switch kind {
        case .toggle:
            Toggle("", isOn: toggleBinding)
                .labelsHidden()
                .toggleStyle(.switch)
        case let .integer(minimum, maximum):
            TextField("Default", text: integerBinding(minimum: minimum, maximum: maximum))
                .textFieldStyle(.roundedBorder)
                .font(.brewCode)
                .frame(maxWidth: 120)
        case .string:
            TextField("Default", text: stringBinding)
                .textFieldStyle(.roundedBorder)
                .font(.brewCode)
        case .secret:
            SecretField(text: stringBinding)
        }
    }

    private func readOnlyValue(badge: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
            HStack(spacing: BrewSpacing.sm) {
                Text(row.value.isEmpty ? "—" : row.value)
                    .font(.brewCode)
                    .foregroundStyle(Color.brewTextSecondary)
                    .textSelection(.enabled)
                Text(badge)
                    .font(.brewCaption2.weight(.semibold))
                    .foregroundStyle(Color.brewStatusWarning)
                    .padding(.horizontal, BrewSpacing.xs)
                    .padding(.vertical, BrewSpacing.xxs)
                    .background(Color.brewStatusWarningSubtle)
                    .clipShape(RoundedRectangle(cornerRadius: BrewRadius.sm))
            }
            Text(hint)
                .font(.brewCaption2)
                .foregroundStyle(Color.brewTextTertiary)
        }
    }

    // MARK: - Bindings
    // Thin wrappers around `ConfigViewModel` sinks/sources. The conditional remove-vs-set rules and
    // the integer digit-filter/clamp live in the VM so they can be unit-tested without spinning up a
    // SwiftUI view tree.

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isToggleOn(forKey: row.key) },
            set: { viewModel.setToggle(forKey: row.key, on: $0) },
        )
    }

    private var stringBinding: Binding<String> {
        Binding(
            get: { viewModel.textValue(forKey: row.key) },
            set: { viewModel.setString(forKey: row.key, to: $0) },
        )
    }

    private func integerBinding(minimum: Int, maximum: Int) -> Binding<String> {
        Binding(
            get: { viewModel.textValue(forKey: row.key) },
            set: { viewModel.setInteger(forKey: row.key, rawText: $0, minimum: minimum, maximum: maximum) },
        )
    }
}

/// `SecureField` with a reveal toggle, since most users want to confirm they pasted the right token
/// before saving. Keeps the value untouched while toggling visibility.
private struct SecretField: View {
    @Binding var text: String
    @State private var isRevealed: Bool = false

    var body: some View {
        HStack(spacing: BrewSpacing.xs) {
            Group {
                if isRevealed {
                    TextField("", text: $text)
                } else {
                    SecureField("", text: $text)
                }
            }
            .textFieldStyle(.roundedBorder)
            .font(.brewCode)

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(Color.brewTextSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? "Hide" : "Reveal")
        }
    }
}

/// Inline form for adding a custom `HOMEBREW_*` row. The key field is locked to the `HOMEBREW_`
/// prefix and the Add button only enables once the user has typed something past it.
private struct ConfigCustomRowAffordance: View {
    @Bindable var viewModel: ConfigViewModel
    @State private var keyDraft: String = "HOMEBREW_"
    @State private var valueDraft: String = ""
    @State private var rejectionMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            Text("Add a custom HOMEBREW_*")
                .font(.brewCaption.weight(.semibold))
                .foregroundStyle(Color.brewTextSecondary)
            HStack(spacing: BrewSpacing.sm) {
                TextField("HOMEBREW_KEY", text: $keyDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.brewCode)
                    .frame(maxWidth: 260)
                TextField("value", text: $valueDraft)
                    .textFieldStyle(.roundedBorder)
                    .font(.brewCode)
                    .frame(maxWidth: .infinity)
                Button("Add", action: addRow)
                    .disabled(!isAddable)
            }
            if let rejectionMessage {
                Text(rejectionMessage)
                    .font(.brewCaption2)
                    .foregroundStyle(Color.brewStatusError)
            }
        }
    }

    private var isAddable: Bool {
        keyDraft.hasPrefix("HOMEBREW_") && keyDraft.count > "HOMEBREW_".count && !valueDraft.isEmpty
    }

    private func addRow() {
        let accepted = viewModel.addCustomRow(key: keyDraft, value: valueDraft)
        if accepted {
            keyDraft = "HOMEBREW_"
            valueDraft = ""
            rejectionMessage = nil
        } else {
            rejectionMessage = String(
                localized: "That key is already covered by a built-in row or isn't a valid HOMEBREW_* name.",
                comment: "Configuration tab, custom row rejection",
            )
        }
    }
}

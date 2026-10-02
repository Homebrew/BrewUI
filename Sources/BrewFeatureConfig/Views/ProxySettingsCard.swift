//
//  ProxySettingsCard.swift
//  BrewFeatureConfig
//

import BrewAccessibilityID
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Manual proxy editor shaped like a desktop IDE HTTP Proxy page, backed by the user `brew.env` file.
///
/// Explicit Save keeps a bad proxy from silently breaking every later `brew` command. PAC /
/// auto-detect is intentionally absent: `brew.env` and curl do not consume automatic proxy
/// configuration. Credentials are written into the composed URL, not the macOS keychain.
struct ProxySettingsCard: View {
    @Bindable var viewModel: ProxySettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            PackageDetailSectionHeading(
                title: LocalizedStringResource(
                    "Network proxy",
                    bundle: #bundle,
                    comment: "Configuration card title: Homebrew proxy settings written to brew.env",
                ),
            )

            Text(
                LocalizedStringResource(
                    """
                    Applies to future Homebrew commands, including those run in Terminal. \
                    System-wide Homebrew settings may take priority. \
                    App browsing uses the macOS system proxy. PAC is not supported here.
                    """,
                    bundle: #bundle,
                    comment: "Configuration proxy card: where the values are stored and what they affect",
                ),
            )
            .font(.brewCaption)
            .foregroundStyle(Color.brewTextSecondary)
            .fixedSize(horizontal: false, vertical: true)

            modePicker
            if !viewModel.isManualConfigurationEnabled {
                Text(
                    LocalizedStringResource(
                        "Saving removes proxy settings from ~/.homebrew/brew.env. Installation and system settings still apply.",
                        bundle: #bundle,
                        comment: "Proxy settings: removing user settings does not force a direct connection",
                    ),
                )
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            if viewModel.isManualConfigurationEnabled {
                manualForm
            }

            if let saveErrorMessage = viewModel.saveErrorMessage {
                Text(saveErrorMessage)
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewStatusError)
                    .fixedSize(horizontal: false, vertical: true)
            } else if viewModel.didSaveSuccessfully {
                Text(
                    LocalizedStringResource(
                        "Saved. Homebrew will read the user configuration on its next command.",
                        bundle: #bundle,
                        comment: "Proxy settings: save success confirmation",
                    ),
                )
                .font(.brewCaption)
                .foregroundStyle(Color.brewStatusSuccess)
            }

            HStack(spacing: BrewSpacing.sm) {
                Button(
                    String(localized: "Save proxy settings", bundle: #bundle, comment: "Proxy settings: save button"),
                    systemImage: "square.and.arrow.down",
                ) {
                    Task { await viewModel.save() }
                }
                .disabled(!viewModel.canSave)

                if viewModel.isDirty {
                    Button(
                        String(localized: "Discard changes", bundle: #bundle, comment: "Proxy settings: discard button"),
                        systemImage: "arrow.uturn.backward",
                    ) {
                        viewModel.discardChanges()
                    }
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(BrewSpacing.lg)
        .background(Color.brewSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.lg)
                .stroke(Color.brewBorderDefault, lineWidth: 1),
        )
        .accessibilityElement(children: .contain)
        .axid(.proxySettingsCard)
        .onAppear {
            viewModel.load()
        }
    }

    private var modePicker: some View {
        Picker(
            String(localized: "Proxy mode", bundle: #bundle, comment: "Proxy settings: mode picker label"),
            selection: Binding(
                get: { viewModel.draft.mode },
                set: { viewModel.draft.mode = $0 },
            ),
        ) {
            Text(
                LocalizedStringResource(
                    "Remove user proxy settings",
                    bundle: #bundle,
                    comment: "Proxy settings mode: remove user keys and inherit installation or system settings",
                ),
            )
            .tag(BrewProxySettings.Mode.none)
            Text(
                LocalizedStringResource(
                    "Manual proxy configuration",
                    bundle: #bundle,
                    comment: "Proxy settings mode: manual host and port",
                ),
            )
            .tag(BrewProxySettings.Mode.manual)
        }
        .pickerStyle(.radioGroup)
        .axid(.proxySettingsModePicker)
    }

    private var manualForm: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            Picker(
                String(localized: "Proxy type", bundle: #bundle, comment: "Proxy settings: HTTP or SOCKS picker label"),
                selection: Binding(
                    get: { viewModel.draft.type },
                    set: { viewModel.draft.type = $0 },
                ),
            ) {
                Text(LocalizedStringResource("HTTP", bundle: #bundle, comment: "Proxy type: HTTP"))
                    .tag(BrewProxySettings.ProxyType.http)
                Text(LocalizedStringResource("SOCKS", bundle: #bundle, comment: "Proxy type: SOCKS"))
                    .tag(BrewProxySettings.ProxyType.socks)
            }
            .pickerStyle(.radioGroup)
            .axid(.proxySettingsTypePicker)

            field(
                .host,
                label: LocalizedStringResource("Host name", bundle: #bundle, comment: "Proxy settings field label"),
                placeholder: "127.0.0.1",
            )
            field(
                .port,
                label: LocalizedStringResource("Port number", bundle: #bundle, comment: "Proxy settings field label"),
                placeholder: "7890",
            )
            field(
                .noProxy,
                label: LocalizedStringResource(
                    "No proxy for",
                    bundle: #bundle,
                    comment: "Proxy settings field label for no_proxy",
                ),
                placeholder: "localhost, .example.com, 192.168.0.0/16",
            )

            Toggle(
                String(
                    localized: "Proxy authentication",
                    bundle: #bundle,
                    comment: "Proxy settings: enable login and password",
                ),
                isOn: Binding(
                    get: { viewModel.draft.usesAuthentication },
                    set: { viewModel.draft.usesAuthentication = $0 },
                ),
            )
            .axid(.proxySettingsAuthenticationToggle)

            if viewModel.draft.usesAuthentication {
                field(
                    .username,
                    label: LocalizedStringResource("Login", bundle: #bundle, comment: "Proxy settings field label"),
                    placeholder: "",
                )
                field(
                    .password,
                    label: LocalizedStringResource("Password", bundle: #bundle, comment: "Proxy settings field label"),
                    placeholder: "",
                )
                Text(
                    LocalizedStringResource(
                        "Credentials are saved in plain text inside brew.env.",
                        bundle: #bundle,
                        comment: "Proxy settings: credentials are not stored in the keychain",
                    ),
                )
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.leading, BrewSpacing.lg)
    }

    private func field(
        _ field: BrewProxySettings.Field,
        label: LocalizedStringResource,
        placeholder: String,
    ) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
            Text(label)
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
            Group {
                if field == .password {
                    SecureField(placeholder, text: binding(for: field), prompt: Text(placeholder))
                } else {
                    TextField(placeholder, text: binding(for: field), prompt: Text(placeholder))
                }
            }
            .accessibilityLabel(Text(label))
            .textFieldStyle(.roundedBorder)
            .font(.brewCode)
            .autocorrectionDisabled()
            .axid(.proxySettingsField(AXID.BrewProxySettingsField(rawValue: field.rawValue) ?? .host))
            if let message = viewModel.validationMessage(for: field) {
                Text(message)
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewStatusError)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func binding(for field: BrewProxySettings.Field) -> Binding<String> {
        Binding(
            get: { viewModel.draft[field] },
            set: { viewModel.draft[field] = $0 },
        )
    }
}

#Preview {
    ProxySettingsCard(
        viewModel: ProxySettingsViewModel(
            store: StubUserBrewEnvironmentStore(
                settings: BrewProxySettings(
                    mode: .manual,
                    type: .http,
                    host: "127.0.0.1",
                    port: "7890",
                    noProxy: "localhost, .example.com, 192.168.0.0/16",
                ),
            ),
            configRepository: StubConfigRepository(
                snapshot: BrewConfigSnapshot(entries: []),
            ),
        ),
    )
    .frame(width: 520)
    .padding()
}

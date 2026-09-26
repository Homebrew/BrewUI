//
//  ConfigView.swift
//  BrewFeatureConfig
//

import AppKit
import BrewAccessibilityID
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Single scrolling pane presenting `brew config` output, with copy/refresh.
struct ConfigView: View {
    @State private var viewModel: ConfigViewModel
    @AppStorage(BrewCommands.forceBottlePreferenceKey) private var forceBottleForFormulae = false

    init(repository: any ConfigRepository) {
        _viewModel = State(initialValue: ConfigViewModel(repository: repository))
    }

    var body: some View {
        VStack(spacing: 3) {
            header
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .axid(.configScreen)
        .task {
            await viewModel.load()
        }
    }

    private var header: some View {
        HStack(spacing: BrewSpacing.sm) {
            Spacer(minLength: 0)
            Button(String(localized: "Copy report", bundle: #bundle, comment: "Configuration header: copy the diagnostic report"), systemImage: "doc.on.doc") {
                copyReport()
            }
            .disabled(!viewModel.canCopyReport)
            Button(String(localized: "Refresh", bundle: #bundle, comment: "Configuration header: re-run brew config"), systemImage: "arrow.clockwise") {
                Task { await viewModel.refresh() }
            }
        }
        .padding(.horizontal, BrewSpacing.lg)
        .padding(.vertical, BrewSpacing.md)
        .brewPaneContentWidth()
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isBrewNotFound {
            brewNotFoundState
        } else {
            AsyncContentView(
                state: viewModel.pageState,
                onRetry: { Task { await viewModel.refresh() } },
                loaded: { snapshot in
                    loadedCards(snapshot: snapshot)
                },
            )
        }
    }

    private var settingsNote: LocalizedStringResource {
        LocalizedStringResource("""
        Homebrew settings are read from brew.env files. Shell profiles and exported variables are ignored. \
        Put user settings in ~/.homebrew/brew.env, then relaunch BrewUI.
        """, bundle: #bundle, comment: "Configuration tab: where Homebrew reads its settings from")
    }

    private func loadedCards(snapshot: BrewConfigSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewSpacing.lg) {
                NoteCallout(settingsNote, tone: .info)
                formulaInstallSettings
                ForEach(viewModel.sections(for: snapshot)) { section in
                    ConfigSectionCard(section: section)
                }
            }
            .padding(BrewSpacing.lg)
            .brewPaneContentWidth()
        }
    }

    private var formulaInstallSettings: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            Toggle(isOn: $forceBottleForFormulae) {
                VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                    Text("Require prebuilt packages for formulae", bundle: #bundle, comment: "Configuration setting: title")
                        .font(.brewCallout.weight(.semibold))
                    Text("If a formula or dependency has no bottle, Homebrew stops instead of building it from source.", bundle: #bundle, comment: "Configuration setting: explanation")
                        .font(.brewCaption)
                        .foregroundStyle(Color.brewTextSecondary)
                }
            }
            .toggleStyle(.switch)
            .axid(.forceBottleFormulaeSwitch)
        }
        .padding(BrewSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brewSurface, in: RoundedRectangle(cornerRadius: BrewRadius.md))
    }

    private var brewNotFoundState: some View {
        emptyState(
            systemImage: "questionmark.folder",
            title: String(localized: "Homebrew not found", bundle: #bundle, comment: "Configuration tab, brew-not-found title"),
            message: String(
                localized: "Couldn't locate the brew executable. Install Homebrew, then refresh.",
                bundle: #bundle,
                comment: "Configuration tab, brew-not-found message",
            ),
        )
        .axid(.brewNotFoundState)
    }

    private func emptyState(
        systemImage: String,
        title: String,
        message: String,
        tint: Color = Color.brewTextSecondary,
    ) -> some View {
        VStack(spacing: BrewSpacing.md) {
            Image(systemName: systemImage)
                .font(.brewTitle1)
                .foregroundStyle(tint)
            Text(title)
                .font(.brewTitle3)
                .foregroundStyle(Color.brewTextPrimary)
            Text(message)
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextSecondary)
                .multilineTextAlignment(.center)
            Button(String(localized: "Refresh", bundle: #bundle, comment: "Configuration header: re-run brew config"), systemImage: "arrow.clockwise") {
                Task { await viewModel.refresh() }
            }
            .padding(.top, BrewSpacing.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(BrewSpacing.xl)
        .accessibilityElement(children: .combine)
    }

    private func copyReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(viewModel.copyReport, forType: .string)
    }
}

#if DEBUG
    #Preview("Loaded") {
        ConfigView(repository: PreviewSupport.makeConfigRepository())
            .frame(width: 720, height: 600)
    }
#endif

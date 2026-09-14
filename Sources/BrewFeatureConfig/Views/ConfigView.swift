//
//  ConfigView.swift
//  BrewFeatureConfig
//

import AppKit
import BrewAccessibilityID
import BrewAppEnvironment
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Single scrolling pane presenting `brew config` output, with copy/refresh.
struct ConfigView: View {
    @State private var viewModel: ConfigViewModel
    @State private var selectedLanguage: AppLanguage
    @State private var showsLanguageRestartAlert = false
    private let languageStore: AppLanguageStore

    init(repository: any ConfigRepository, languageStore: AppLanguageStore = AppLanguageStore()) {
        _viewModel = State(initialValue: ConfigViewModel(repository: repository))
        _selectedLanguage = State(initialValue: languageStore.language)
        self.languageStore = languageStore
    }

    var body: some View {
        VStack(spacing: 3) {
            header
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .axid(.configScreen)
        .alert(
            String(localized: "Restart Required", comment: "Language setting alert title"),
            isPresented: $showsLanguageRestartAlert,
        ) {
            Button("OK") {}
        } message: {
            Text(
                String(
                    localized: "Language changes will take effect after restarting the app.",
                    comment: "Language setting alert message",
                ),
            )
        }
        .task {
            await viewModel.load()
        }
    }

    private var header: some View {
        HStack(spacing: BrewSpacing.sm) {
            languagePicker
            Spacer(minLength: 0)
            Button("Copy report", systemImage: "doc.on.doc") {
                copyReport()
            }
            .disabled(!viewModel.canCopyReport)
            Button("Refresh", systemImage: "arrow.clockwise") {
                Task { await viewModel.refresh() }
            }
        }
        .padding(.horizontal, BrewSpacing.lg)
        .padding(.vertical, BrewSpacing.md)
        .brewPaneContentWidth()
    }

    private var languagePicker: some View {
        HStack(spacing: BrewSpacing.xs) {
            Picker(String(localized: "Language", comment: "Configuration language setting label"), selection: $selectedLanguage) {
                Text("System Default").tag(AppLanguage.system)
                Text("English").tag(AppLanguage.english)
                Text("Simplified Chinese").tag(AppLanguage.simplifiedChinese)
            }
            .pickerStyle(.menu)
            .onChange(of: selectedLanguage) { oldLanguage, newLanguage in
                languageStore.language = newLanguage
                if LanguageSettingsPresentation.shouldPresentRestartAlert(from: oldLanguage, to: newLanguage) {
                    showsLanguageRestartAlert = true
                }
            }
        }
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

    private func loadedCards(snapshot: BrewConfigSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewSpacing.lg) {
                ForEach(viewModel.sections(for: snapshot)) { section in
                    ConfigSectionCard(section: section)
                }
            }
            .padding(BrewSpacing.lg)
            .brewPaneContentWidth()
        }
    }

    private var brewNotFoundState: some View {
        emptyState(
            systemImage: "questionmark.folder",
            title: String(localized: "Homebrew not found", comment: "Configuration tab, brew-not-found title"),
            message: String(
                localized: "Couldn't locate the brew executable. Install Homebrew, then refresh.",
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
            Button("Refresh", systemImage: "arrow.clockwise") {
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

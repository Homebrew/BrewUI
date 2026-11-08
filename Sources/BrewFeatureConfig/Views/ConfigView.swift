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
    @Environment(\.aiModelManager) private var aiModelManager
    @State private var showModelPicker = false

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

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewSpacing.lg) {
                NoteCallout(settingsNote, tone: .info)
                aiModelsCard
                if viewModel.isBrewNotFound {
                    brewNotFoundState
                } else {
                    AsyncContentView(
                        state: viewModel.pageState,
                        onRetry: { Task { await viewModel.refresh() } },
                        loaded: { snapshot in
                            VStack(alignment: .leading, spacing: BrewSpacing.lg) {
                                ForEach(viewModel.sections(for: snapshot)) { section in
                                    ConfigSectionCard(section: section)
                                }
                            }
                        },
                    )
                }
            }
            .padding(BrewSpacing.lg)
            .brewPaneContentWidth()
        }
    }

    private var settingsNote: LocalizedStringResource {
        LocalizedStringResource("""
        Homebrew settings are read from brew.env files. Shell profiles and exported variables are ignored. \
        Put user settings in ~/.homebrew/brew.env, then relaunch BrewUI.
        """, bundle: #bundle, comment: "Configuration tab: where Homebrew reads its settings from")
    }

    private var aiModelsCard: some View {
        let activeModel = aiModelManager.availableModels.first(where: { $0.id == aiModelManager.activeModelID })
        let modelName = activeModel?.name ?? String(localized: "Local Expert Engine", bundle: #bundle, comment: "Config: default built-in AI engine name")
        let ramText = String(format: "%.1f GB", aiModelManager.hardwareProfile.totalMemoryGB)

        return VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            HStack(spacing: BrewSpacing.sm) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.brewBrandPrimary)
                Text("On-Device AI Engine & Models", bundle: #bundle, comment: "Config card title: AI diagnostics")
                    .font(.brewBodyEmphasized)
                    .foregroundStyle(Color.brewTextPrimary)
                Spacer()
                Button(String(localized: "Manage Models…", bundle: #bundle, comment: "Config: open model manager sheet")) {
                    showModelPicker = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
                HStack {
                    Text("Active Engine:", bundle: #bundle, comment: "Config: active AI engine label")
                        .font(.brewSubheadline)
                        .foregroundStyle(Color.brewTextSecondary)
                    Text(modelName)
                        .font(.brewSubheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.brewTextPrimary)
                }

                HStack {
                    Text("Host RAM:", bundle: #bundle, comment: "Config: host memory label")
                        .font(.brewCaption)
                        .foregroundStyle(Color.brewTextSecondary)
                    Text(ramText)
                        .font(.brewCaption)
                        .foregroundStyle(Color.brewTextPrimary)
                    Text("• Zero telemetry, runs 100% locally", bundle: #bundle, comment: "Config: local privacy note")
                        .font(.brewCaption)
                        .foregroundStyle(Color.brewTextSecondary)
                }
            }
        }
        .padding(BrewSpacing.lg)
        .background(Color.brewSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.lg))
        .sheet(isPresented: $showModelPicker) {
            AIModelPickerSheet(modelManager: aiModelManager)
        }
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

//
//  ConfigView.swift
//  BrewFeatureConfig
//

import AppKit
import BrewCore
import BrewRepositoryInterfaces
import BrewUIComponents
import SwiftUI

/// Single scrolling pane presenting `brew config` + the `HOMEBREW_*` environment, with copy/refresh.
struct ConfigView: View {
    @State private var viewModel: ConfigViewModel

    init(repository: any ConfigRepository) {
        _viewModel = State(initialValue: ConfigViewModel(repository: repository))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .overlay(Color.brewBorderSeparator)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await viewModel.load()
        }
    }

    private var header: some View {
        HStack(spacing: BrewSpacing.sm) {
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
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        case .loaded:
            loadedCards
        case .failed:
            if viewModel.isBrewNotFound {
                brewNotFoundState
            } else {
                errorState
            }
        }
    }

    private var loadedCards: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: BrewSpacing.lg) {
                ForEach(viewModel.sections) { section in
                    ConfigSectionCard(section: section)
                }
            }
            .padding(BrewSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .topLeading)
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
    }

    private var errorState: some View {
        emptyState(
            systemImage: "exclamationmark.triangle",
            title: String(localized: "Couldn't load configuration", comment: "Configuration tab, error title"),
            message: viewModel.errorMessage,
            tint: Color.brewStatusError,
        )
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

//
//  AIModelPickerSheet.swift
//  BrewUIComponents
//

import BrewCore
import BrewRepositoryInterfaces
import SwiftUI

/// Sheet allowing users to view hardware fit, download on-device AI models, and select the active engine.
public struct AIModelPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let modelManager: any AIModelManaging

    public init(modelManager: any AIModelManaging) {
        self.modelManager = modelManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: BrewSpacing.lg) {
                    systemProfileBanner
                    modelsSection
                }
                .padding(BrewSpacing.xl)
            }
            Divider()
            footer
        }
        .frame(minWidth: 580, minHeight: 460)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
                Text("Local AI Models", bundle: #bundle, comment: "AI Models Sheet: title")
                    .font(.brewTitle2)
                    .foregroundStyle(Color.brewTextPrimary)
                Text("Choose and download on-device models to power intelligent diagnostics and command explanation.", bundle: #bundle, comment: "AI Models Sheet: subtitle")
                    .font(.brewSubheadline)
                    .foregroundStyle(Color.brewTextSecondary)
            }
            Spacer()
            Button(String(localized: "Done", bundle: #bundle, comment: "AI Models Sheet: dismiss button")) {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(BrewSpacing.lg)
    }

    private var systemProfileBanner: some View {
        HStack(spacing: BrewSpacing.md) {
            Image(systemName: "cpu")
                .font(.system(size: 24))
                .foregroundStyle(Color.brewBrandPrimary)

            VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
                Text("System Memory: \(String(format: "%.1f", modelManager.hardwareProfile.totalMemoryGB)) GB Unified RAM", bundle: #bundle, comment: "AI Models Sheet: hardware specs banner; %.1f is memory size in gigabytes")
                    .font(.brewSubheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.brewTextPrimary)

                Text("Models are matched to your unified memory capacity to prevent system slowdowns.", bundle: #bundle, comment: "AI Models Sheet: hardware fit explanation")
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextSecondary)
            }
            Spacer()
        }
        .padding(BrewSpacing.md)
        .background(Color.brewSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
    }

    private var modelsSection: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            ForEach(modelManager.availableModels) { model in
                modelRow(model)
            }
        }
    }

    private func modelRow(_ model: AIModelSpec) -> some View {
        let fit = modelManager.hardwareProfile.fit(for: model)
        let state = modelManager.downloadState(for: model)
        let isActive = modelManager.activeModelID == model.id

        return VStack(alignment: .leading, spacing: BrewSpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
                    HStack(spacing: BrewSpacing.sm) {
                        Text(verbatim: model.name)
                            .font(.brewBodyEmphasized)
                            .foregroundStyle(Color.brewTextPrimary)

                        fitBadge(fit)

                        if isActive {
                            Text("Active", bundle: #bundle, comment: "AI Models Sheet: active model badge")
                                .font(.brewCaption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, BrewSpacing.xs)
                                .padding(.vertical, 2)
                                .background(Color.brewBrandPrimary.opacity(0.15))
                                .foregroundStyle(Color.brewBrandPrimary)
                                .clipShape(Capsule())
                        }
                    }

                    Text(verbatim: model.summary)
                        .font(.brewBody)
                        .foregroundStyle(Color.brewTextSecondary)

                    HStack(spacing: BrewSpacing.md) {
                        Text("Size: \(model.downloadSizeMB) MB", bundle: #bundle, comment: "AI Models Sheet: model download size; %lld is size in MB")
                            .font(.brewCaption)
                            .foregroundStyle(Color.brewTextSecondary)

                        Text("RAM: \(String(format: "%.1f", model.requiredMemoryGB)) GB", bundle: #bundle, comment: "AI Models Sheet: model memory requirement; %.1f is memory in GB")
                            .font(.brewCaption)
                            .foregroundStyle(Color.brewTextSecondary)

                        Text("Quantization: \(model.quantization)", bundle: #bundle, comment: "AI Models Sheet: model quantization level; %@ is quantization string")
                            .font(.brewCaption)
                            .foregroundStyle(Color.brewTextSecondary)
                    }
                }

                Spacer()

                actionButtons(for: model, state: state, isActive: isActive)
            }

            if case let .downloading(progress) = state {
                VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
                    ProgressView(value: progress, total: 1.0)
                        .progressViewStyle(.linear)
                    Text("Downloading… \(Int(progress * 100))%", bundle: #bundle, comment: "AI Models Sheet: download progress percentage; %lld is percentage")
                        .font(.brewCaption)
                        .foregroundStyle(Color.brewTextSecondary)
                }
            }
        }
        .padding(BrewSpacing.md)
        .background(Color.brewSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
    }

    @ViewBuilder
    private func fitBadge(_ fit: AISystemFit) -> some View {
        let (color, text): (Color, LocalizedStringResource) = {
            switch fit {
            case .optimal:
                return (.green, LocalizedStringResource("Optimal Fit", bundle: #bundle, comment: "AI model memory fit: optimal"))
            case .acceptable:
                return (.orange, LocalizedStringResource("Acceptable Fit", bundle: #bundle, comment: "AI model memory fit: acceptable"))
            case .heavy:
                return (.red, LocalizedStringResource("Heavy Memory Usage", bundle: #bundle, comment: "AI model memory fit: heavy"))
            }
        }()

        Text(text)
            .font(.brewCaption)
            .padding(.horizontal, BrewSpacing.xs)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func actionButtons(for model: AIModelSpec, state: AIModelDownloadState, isActive: Bool) -> some View {
        switch state {
        case .notDownloaded:
            Button(String(localized: "Download", bundle: #bundle, comment: "AI Models Sheet: download button")) {
                Task {
                    await modelManager.startDownload(for: model)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

        case .downloading:
            Button(String(localized: "Cancel", bundle: #bundle, comment: "AI Models Sheet: cancel download button")) {
                modelManager.cancelDownload(for: model)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

        case .ready:
            HStack(spacing: BrewSpacing.xs) {
                if !isActive {
                    Button(String(localized: "Use Model", bundle: #bundle, comment: "AI Models Sheet: select active model button")) {
                        modelManager.setActiveModel(id: model.id)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Button(String(localized: "Delete", bundle: #bundle, comment: "AI Models Sheet: delete local model button"), role: .destructive) {
                    modelManager.deleteModel(for: model)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("Models run 100% locally on your Mac. No prompts or diagnostic data leave your machine.", bundle: #bundle, comment: "AI Models Sheet: privacy assurance notice")
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextSecondary)
            Spacer()
        }
        .padding(BrewSpacing.md)
    }
}

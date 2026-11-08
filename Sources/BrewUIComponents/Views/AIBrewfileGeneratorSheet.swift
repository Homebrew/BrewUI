//
//  AIBrewfileGeneratorSheet.swift
//  BrewUIComponents
//

import AppKit
import BrewCore
import BrewRepositoryInterfaces
import SwiftUI

/// Modal sheet for conversational Brewfile and development environment generation.
public struct AIBrewfileGeneratorSheet: View {
    public let aiEngine: any AIEngineProtocol
    public let onRunCommand: ((String) -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var promptText: String = ""
    @State private var environment: AIBrewfileEnvironment?
    @State private var isGenerating: Bool = false
    @State private var didCopy: Bool = false
    @State private var saveErrorMessage: String?
    @State private var generationTask: Task<Void, Never>?

    public init(
        aiEngine: any AIEngineProtocol,
        onRunCommand: ((String) -> Void)? = nil,
    ) {
        self.aiEngine = aiEngine
        self.onRunCommand = onRunCommand
    }

    private struct Preset: Identifiable {
        var id: String {
            prompt
        }

        let title: LocalizedStringResource
        let prompt: String
    }

    private let presets: [Preset] = [
        Preset(
            title: LocalizedStringResource("Fullstack Web", bundle: #bundle, comment: "Brewfile preset: web development"),
            prompt: "Modern fullstack TypeScript and Node web development with React and Chrome",
        ),
        Preset(
            title: LocalizedStringResource("Python & ML", bundle: #bundle, comment: "Brewfile preset: python and ML"),
            prompt: "Python 3.12 data science, machine learning with uv and jupyter",
        ),
        Preset(
            title: LocalizedStringResource("Apple & Swift", bundle: #bundle, comment: "Brewfile preset: iOS and macOS Swift engineering"),
            prompt: "iOS and macOS developer setup with SwiftLint, SwiftFormat, and fastlane",
        ),
        Preset(
            title: LocalizedStringResource("DevOps & Cloud", bundle: #bundle, comment: "Brewfile preset: DevOps and Cloud"),
            prompt: "Cloud infrastructure with Docker, Kubernetes, Terraform, and AWS CLI",
        ),
        Preset(
            title: LocalizedStringResource("Modern CLI", bundle: #bundle, comment: "Brewfile preset: modern CLI tools"),
            prompt: "Rust-based modern command-line power tools and zsh terminal utilities",
        ),
    ]

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: BrewSpacing.lg) {
                    if let error = saveErrorMessage {
                        NoteCallout(verbatim: error, tone: .info)
                    }
                    promptInputSection
                    presetChipsSection

                    if isGenerating {
                        HStack(spacing: BrewSpacing.sm) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Architecting environment Brewfile…", bundle: #bundle, comment: "Brewfile generator progress label")
                                .font(.brewBody)
                                .foregroundStyle(Color.brewTextSecondary)
                        }
                        .padding(.vertical, BrewSpacing.lg)
                    } else if let env = environment {
                        AIBrewfileResultCard(
                            env: env,
                            didCopy: didCopy,
                            onSave: { saveBrewfileToFile(content: $0) },
                            onCopy: { copyToClipboard($0) },
                            onRunCommand: onRunCommand,
                            onDismiss: { dismiss() },
                        )
                    }
                }
                .padding(BrewSpacing.xl)
            }

            Divider()
            footer
        }
        .frame(minWidth: 580, idealWidth: 640, maxWidth: 740, minHeight: 520, idealHeight: 620)
        .background(Color.brewSurfaceElevated)
    }

    private var header: some View {
        HStack(spacing: BrewSpacing.sm) {
            Image(systemName: "sparkles")
                .font(.brewTitle2)
                .foregroundStyle(Color.brewBrandPrimary)
            VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
                Text("AI Brewfile & Environment Architect", bundle: #bundle, comment: "Brewfile generator title")
                    .font(.brewTitle3)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brewTextPrimary)
                Text("Describe your project stack or choose a preset to generate a curated Brewfile.", bundle: #bundle, comment: "Brewfile generator subtitle")
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextSecondary)
            }
            Spacer()
        }
        .padding(BrewSpacing.lg)
    }

    private var promptInputSection: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            Text("Describe Your Target Environment", bundle: #bundle, comment: "Brewfile prompt section heading")
                .font(.brewSubheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.brewTextPrimary)

            HStack(spacing: BrewSpacing.sm) {
                TextField(
                    String(localized: "e.g. Fullstack React + Go backend with PostgreSQL", bundle: #bundle, comment: "Brewfile prompt placeholder"),
                    text: $promptText,
                )
                .textFieldStyle(.roundedBorder)
                .onSubmit { generate() }

                Button {
                    generate()
                } label: {
                    Label {
                        Text("Generate", bundle: #bundle, comment: "Generate Brewfile button")
                    } icon: {
                        Image(systemName: "wand.and.stars")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
            }
        }
    }

    private var presetChipsSection: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            Text("Quick Presets", bundle: #bundle, comment: "Brewfile presets section heading")
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BrewSpacing.xs) {
                    ForEach(presets) { preset in
                        Button {
                            promptText = preset.prompt
                            generate()
                        } label: {
                            Text(preset.title)
                                .font(.brewCaption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isGenerating)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button(String(localized: "Close", bundle: #bundle, comment: "Brewfile generator close button")) {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.cancelAction)
        }
        .padding(BrewSpacing.lg)
    }
}

extension AIBrewfileGeneratorSheet {
    private func generate() {
        guard !isGenerating else { return }
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        generationTask?.cancel()
        isGenerating = true
        generationTask = Task { @MainActor in
            let res = await aiEngine.generateBrewfileEnvironment(prompt: trimmed)
            if !Task.isCancelled {
                environment = res
                isGenerating = false
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            didCopy = false
        }
    }

    private func saveBrewfileToFile(content: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Brewfile"
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                saveErrorMessage = nil
            } catch {
                saveErrorMessage = error.localizedDescription
            }
        }
    }
}

private struct AIBrewfileResultCard: View {
    let env: AIBrewfileEnvironment
    let didCopy: Bool
    let onSave: (String) -> Void
    let onCopy: (String) -> Void
    let onRunCommand: ((String) -> Void)?
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            headerRow
            previewSection
            installSection
        }
        .padding(BrewSpacing.md)
        .background(Color.brewSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.md, style: .continuous)
                .stroke(Color.brewBorderDefault, lineWidth: 1),
        )
    }

    private var headerRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
                Text(verbatim: env.title)
                    .font(.brewBodyEmphasized)
                    .foregroundStyle(Color.brewTextPrimary)
                Text(verbatim: env.explanation)
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextSecondary)
            }
            Spacer()

            Button {
                onSave(env.generatedBrewfileContent)
            } label: {
                Label {
                    Text("Save As…", bundle: #bundle, comment: "Save Brewfile to disk button")
                } icon: {
                    Image(systemName: "square.and.arrow.down")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                onCopy(env.generatedBrewfileContent)
            } label: {
                Label {
                    Text(didCopy ? "Copied" : "Copy", bundle: #bundle, comment: "Copy Brewfile button")
                } icon: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            Text("Brewfile Preview", bundle: #bundle, comment: "Brewfile preview section header")
                .font(.brewCaption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.brewTextSecondary)

            ScrollView(.horizontal) {
                Text(verbatim: env.generatedBrewfileContent)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Color.brewTextPrimary)
                    .padding(BrewSpacing.sm)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brewSurface)
            .clipShape(RoundedRectangle(cornerRadius: BrewRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: BrewRadius.sm, style: .continuous)
                    .stroke(Color.brewBorderDefault, lineWidth: 1),
            )
        }
    }

    private var installSection: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            Text("Install Environment", bundle: #bundle, comment: "Brewfile install section header")
                .font(.brewCaption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.brewTextSecondary)

            HStack(spacing: BrewSpacing.sm) {
                CommandBlockView(command: "brew bundle")
                if let onRunCommand {
                    Button {
                        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Brewfile-\(UUID().uuidString)")
                        try? env.generatedBrewfileContent.write(to: tempURL, atomically: true, encoding: .utf8)
                        onRunCommand("brew bundle --file \(tempURL.path)")
                        onDismiss()
                    } label: {
                        Text("Run", bundle: #bundle, comment: "AI run command button")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
}

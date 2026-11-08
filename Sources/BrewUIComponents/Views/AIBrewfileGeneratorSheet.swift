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

    public init(
        aiEngine: any AIEngineProtocol,
        onRunCommand: ((String) -> Void)? = nil
    ) {
        self.aiEngine = aiEngine
        self.onRunCommand = onRunCommand
    }

    private let presets: [(title: String, prompt: String)] = [
        ("Fullstack Web", "Modern fullstack TypeScript and Node web development with React and Chrome"),
        ("Python & ML", "Python 3.12 data science, machine learning with uv and jupyter"),
        ("Apple & Swift", "iOS and macOS developer setup with SwiftLint, SwiftFormat, and fastlane"),
        ("DevOps & Cloud", "Cloud infrastructure with Docker, Kubernetes, Terraform, and AWS CLI"),
        ("Modern CLI", "Rust-based modern command-line power tools and zsh terminal utilities"),
    ]

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: BrewSpacing.lg) {
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
                        generatedResultSection(env)
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
                    text: $promptText
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
                    ForEach(presets, id: \.title) { preset in
                        Button {
                            promptText = preset.prompt
                            generate()
                        } label: {
                            Text(verbatim: preset.title)
                                .font(.brewCaption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private func generatedResultSection(_ env: AIBrewfileEnvironment) -> some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
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
                    saveBrewfileToFile(content: env.generatedBrewfileContent)
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
                    copyToClipboard(env.generatedBrewfileContent)
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
                        .stroke(Color.brewBorderDefault, lineWidth: 1)
                )
            }

            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                Text("Install Environment", bundle: #bundle, comment: "Brewfile install section header")
                    .font(.brewCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.brewTextSecondary)

                HStack(spacing: BrewSpacing.sm) {
                    CommandBlockView(command: env.bundleCommand)
                    if let onRunCommand {
                        Button {
                            onRunCommand(env.bundleCommand)
                            dismiss()
                        } label: {
                            Text("Run", bundle: #bundle, comment: "AI run command button")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(BrewSpacing.md)
        .background(Color.brewSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.md, style: .continuous)
                .stroke(Color.brewBorderDefault, lineWidth: 1)
        )
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

    private func generate() {
        guard !isGenerating else { return }
        let trimmed = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isGenerating = true
        Task {
            let res = await aiEngine.generateBrewfileEnvironment(prompt: trimmed)
            await MainActor.run {
                self.environment = res
                self.isGenerating = false
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
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}

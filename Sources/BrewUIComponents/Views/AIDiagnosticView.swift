//
//  AIDiagnosticView.swift
//  BrewUIComponents
//

import BrewCore
import SwiftUI

/// Elegant presentation of an AI diagnostic analysis with explanations and executable commands.
public struct AIDiagnosticView: View {
    public let result: AIAnalysisResult
    public let isCommandRunning: ((String) -> Bool)?
    public let errorMessage: ((String) -> String?)?
    public let onRunCommand: ((String) -> Void)?

    public init(
        result: AIAnalysisResult,
        isCommandRunning: ((String) -> Bool)? = nil,
        errorMessage: ((String) -> String?)? = nil,
        onRunCommand: ((String) -> Void)? = nil
    ) {
        self.result = result
        self.isCommandRunning = isCommandRunning
        self.errorMessage = errorMessage
        self.onRunCommand = onRunCommand
    }

    private func isRunnableCommand(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("brew ") &&
            !trimmed.contains("<") &&
            !trimmed.contains(">") &&
            !trimmed.contains("sudo ")
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            headerRow

            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                Text("What this means", bundle: #bundle, comment: "AI Diagnostic: explanation section heading")
                    .font(.brewSubheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.brewTextPrimary)

                Text(result.summary)
                    .font(.brewBody)
                    .foregroundStyle(Color.brewTextSecondary)
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                Text("Probable Cause", bundle: #bundle, comment: "AI Diagnostic: root cause heading")
                    .font(.brewSubheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.brewTextPrimary)

                Text(result.rootCause)
                    .font(.brewBody)
                    .foregroundStyle(Color.brewTextSecondary)
                    .textSelection(.enabled)
            }

            if !result.suggestedCommands.isEmpty {
                VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                    Text("Suggested Remediation", bundle: #bundle, comment: "AI Diagnostic: suggested fix commands heading")
                        .font(.brewSubheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.brewTextPrimary)

                    ForEach(result.suggestedCommands, id: \.self) { cmd in
                        VStack(alignment: .leading, spacing: BrewSpacing.xxs) {
                            HStack(spacing: BrewSpacing.sm) {
                                CommandBlockView(
                                    command: cmd,
                                    summaryText: nil,
                                    title: nil,
                                    collapsible: false
                                )

                                if onRunCommand != nil, isRunnableCommand(cmd) {
                                    let running = isCommandRunning?(cmd) ?? false
                                    Button {
                                        onRunCommand?(cmd)
                                    } label: {
                                        if running {
                                            ProgressView()
                                                .controlSize(.small)
                                                .frame(minWidth: 54)
                                        } else {
                                            Text("Run Fix", bundle: #bundle, comment: "AI Diagnostic: run fix button")
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    .disabled(running)
                                    .accessibilityLabel(String(localized: "Run Fix", bundle: #bundle, comment: "VoiceOver: run-fix button"))
                                }
                            }

                            if let error = errorMessage?(cmd) {
                                Text(error)
                                    .font(.brewCallout)
                                    .foregroundStyle(Color.brewStatusError)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
        }
        .padding(BrewSpacing.lg)
        .background(Color.brewSurface)
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.lg)
                .stroke(Color.brewBrandPrimary.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.lg))
    }

    private var headerRow: some View {
        HStack(spacing: BrewSpacing.sm) {
            Image(systemName: "sparkles")
                .font(.brewTitle3)
                .foregroundStyle(Color.brewBrandPrimary)

            Text("AI Remediation Analysis", bundle: #bundle, comment: "AI Diagnostic: card header title")
                .font(.brewBodyEmphasized)
                .foregroundStyle(Color.brewTextPrimary)

            Spacer()

            Text(result.modelName)
                .font(.brewCaption)
                .padding(.horizontal, BrewSpacing.sm)
                .padding(.vertical, BrewSpacing.xxs)
                .background(Color.brewBrandPrimary.opacity(0.12))
                .foregroundStyle(Color.brewBrandPrimary)
                .clipShape(Capsule())
        }
    }
}

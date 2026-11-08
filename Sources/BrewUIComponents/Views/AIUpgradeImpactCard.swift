//
//  AIUpgradeImpactCard.swift
//  BrewUIComponents
//

import BrewCore
import SwiftUI

/// Card detailing upgrade risk assessment, major version shifts, and dependent package impacts.
public struct AIUpgradeImpactCard: View {
    public let impact: AIUpgradeImpact
    public let onRunCommand: ((String) -> Void)?

    public init(
        impact: AIUpgradeImpact,
        onRunCommand: ((String) -> Void)? = nil,
    ) {
        self.impact = impact
        self.onRunCommand = onRunCommand
    }

    private var riskColor: Color {
        switch impact.riskLevel {
        case .low:
            Color.brewStatusSuccess
        case .medium:
            Color.brewStatusWarning
        case .high:
            Color.brewStatusError
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            HStack(spacing: BrewSpacing.sm) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.brewBrandPrimary)
                Text("AI Upgrade Impact Advisor", bundle: #bundle, comment: "AI upgrade impact card title")
                    .font(.brewSubheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.brewTextPrimary)

                Spacer()

                Text(verbatim: impact.riskLevel.title)
                    .font(.brewCaption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, BrewSpacing.sm)
                    .padding(.vertical, BrewSpacing.xxs)
                    .background(riskColor.opacity(0.15))
                    .foregroundStyle(riskColor)
                    .clipShape(Capsule())
            }

            Text(verbatim: impact.summary)
                .font(.brewBody)
                .foregroundStyle(Color.brewTextSecondary)
                .textSelection(.enabled)

            if let breaking = impact.breakingChangesWarning {
                HStack(alignment: .top, spacing: BrewSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.brewStatusWarning)
                        .padding(.top, 2)
                    Text(verbatim: breaking)
                        .font(.brewCaption)
                        .foregroundStyle(Color.brewTextPrimary)
                        .textSelection(.enabled)
                }
                .padding(BrewSpacing.sm)
                .background(Color.brewStatusWarning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: BrewRadius.sm, style: .continuous))
            }

            if let serviceNotice = impact.serviceRestartNotice {
                HStack(alignment: .top, spacing: BrewSpacing.sm) {
                    Image(systemName: "gearshape.arrow.triangle.2.circlepath")
                        .foregroundStyle(Color.brewBrandPrimary)
                        .padding(.top, 2)
                    Text(verbatim: serviceNotice)
                        .font(.brewCaption)
                        .foregroundStyle(Color.brewTextPrimary)
                        .textSelection(.enabled)
                }
                .padding(BrewSpacing.sm)
                .background(Color.brewBrandPrimary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: BrewRadius.sm, style: .continuous))
            }

            if !impact.recommendedVerificationCommands.isEmpty {
                VStack(alignment: .leading, spacing: BrewSpacing.xs) {
                    Text("Recommended Verification", bundle: #bundle, comment: "AI Upgrade Impact: verification commands section")
                        .font(.brewCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.brewTextPrimary)

                    ForEach(impact.recommendedVerificationCommands, id: \.self) { cmd in
                        HStack(spacing: BrewSpacing.sm) {
                            CommandBlockView(command: cmd)
                            if let onRunCommand {
                                Button {
                                    onRunCommand(cmd)
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
        }
        .padding(BrewSpacing.md)
        .background(Color.brewSurface)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.md, style: .continuous)
                .stroke(Color.brewBorderDefault, lineWidth: 1),
        )
    }
}

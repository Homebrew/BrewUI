//
//  PackageDetailSubviews.swift
//  BrewDesignSystem
//

import AppKit
import SwiftUI

/// Section heading used across package-detail surfaces.
public struct PackageDetailSectionHeading: View {
    let title: String

    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(.brewSubheadline.weight(.semibold))
            .foregroundStyle(Color.brewTextPrimary)
    }
}

/// Hairline divider between package-detail sections.
public struct PackageDetailSectionDivider: View {
    public init() {}

    public var body: some View {
        Divider()
            .overlay(Color.brewBorderSeparator)
    }
}

/// Terminal-command card with a copy button and an optional footer summary line.
public struct PackageDetailCommandConsole: View {
    let command: String
    let summaryText: String?

    public init(command: String, summaryText: String? = nil) {
        self.command = command
        self.summaryText = summaryText
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Terminal command", systemImage: "terminal")
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextSecondary)
                Spacer()
                Button("Copy", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                }
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextSecondary)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, BrewSpacing.md)
            .padding(.vertical, BrewSpacing.sm)
            .background(Color.brewSurfaceRecessed)

            Text(command)
                .font(.brewCode)
                .foregroundStyle(Color.brewCodeDefault)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(BrewSpacing.md)
                .background(Color.brewTerminal)
                .textSelection(.enabled)

            if let summaryText {
                Text(summaryText)
                    .font(.brewCaption)
                    .foregroundStyle(Color.brewTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, BrewSpacing.md)
                    .padding(.vertical, BrewSpacing.sm)
                    .background(Color.brewSurfaceRecessed)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: BrewRadius.md)
                .stroke(Color.brewBorderDefault, lineWidth: 1),
        )
    }
}

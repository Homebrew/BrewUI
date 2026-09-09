//
//  NoteCallout.swift
//  BrewUIComponents
//

import SwiftUI

/// Which register a ``NoteCallout`` speaks in. Both are informational; the difference is what the
/// surrounding screen already uses.
public enum NoteCalloutTone: Sendable {
    /// Homebrew's own amber.
    case brand
    /// The neutral information blue, for screens whose content is already amber or red — a brand-tinted
    /// note there would read as one more warning.
    case info

    var iconColor: Color {
        switch self {
        case .brand: .brewTextBrand
        case .info: .brewStatusInfo
        }
    }

    var background: Color {
        switch self {
        case .brand: .brewBrandTint
        case .info: .brewStatusInfoSubtle
        }
    }
}

public struct NoteCallout: View {
    private let text: Text
    private let tone: NoteCalloutTone

    public init(_ text: LocalizedStringResource, tone: NoteCalloutTone = .brand) {
        self.text = Text(text)
        self.tone = tone
    }

    /// For copy that must reach the screen exactly as given and therefore owns no catalogue key —
    /// `brew`'s own output, or a package's caveats. Named after `Text(verbatim:)`, which it wraps, so
    /// a call site cannot silently opt out of localization without saying so.
    public init(verbatim text: String, tone: NoteCalloutTone = .brand) {
        self.text = Text(verbatim: text)
        self.tone = tone
    }

    public var body: some View {
        HStack(alignment: .top, spacing: BrewSpacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.brewSubheadline)
                .foregroundStyle(tone.iconColor)
            text
                .font(.brewCallout)
                .foregroundStyle(Color.brewTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(BrewSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.background)
        .clipShape(RoundedRectangle(cornerRadius: BrewRadius.md))
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
    #Preview("Note callout") {
        VStack(alignment: .leading, spacing: BrewSpacing.md) {
            NoteCallout("Casks and formulae are installed to different prefixes.")
            NoteCallout(
                verbatim: "Please note that these warnings are just used to help the Homebrew maintainers.",
                tone: .info,
            )
        }
        .padding()
        .frame(width: 320)
    }
#endif

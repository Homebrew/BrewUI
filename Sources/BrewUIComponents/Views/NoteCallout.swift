//
//  NoteCallout.swift
//  BrewUIComponents
//

import SwiftUI

/// Which register a ``NoteCallout`` speaks in. Both are informational; the difference is what the
/// surrounding screen already uses.
public enum NoteCalloutTone: Sendable {
    /// Homebrew's own amber. The default, used where the note is the only tinted thing on screen.
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

/// Tinted "note" block: an info glyph beside a short piece of explanatory text. Wraps rather than
/// truncates, however narrow the column gets.
public struct NoteCallout: View {
    private let text: String
    private let tone: NoteCalloutTone

    public init(_ text: String, tone: NoteCalloutTone = .brand) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        HStack(alignment: .top, spacing: BrewSpacing.sm) {
            Image(systemName: "info.circle.fill")
                .font(.brewSubheadline)
                .foregroundStyle(tone.iconColor)
            Text(text)
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
                "Please note that these warnings are just used to help the Homebrew maintainers.",
                tone: .info,
            )
        }
        .padding()
        .frame(width: 320)
    }
#endif

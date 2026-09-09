//
//  LastUpdatedLabel.swift
//  BrewUIComponents
//

import Foundation
import SwiftUI

/// Spelled out rather than left to `RelativeDateTimeFormatter` so the phrase is a catalogue entry a
/// translator can see and reword. Interpolating the count produces a `%lld` key, which the catalogue
/// answers with per-language plural variations — pluralisation rules differ by language, so a
/// hand-written singular/plural ternary is only ever right for one of them.
public enum RelativeTimeText {
    public static func resource(for date: Date, relativeTo now: Date) -> LocalizedStringResource {
        let seconds = now.timeIntervalSince(date)
        guard seconds >= 60 else {
            // Also covers a future date: a clock that moved backwards should read as "now", not a countdown.
            return LocalizedStringResource(uiComponents: "just now")
        }
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return LocalizedStringResource(uiComponents: "\(minutes) minutes ago")
        }
        let hours = minutes / 60
        if hours < 24 {
            return LocalizedStringResource(uiComponents: "\(hours) hours ago")
        }
        let days = hours / 24
        return LocalizedStringResource(uiComponents: "\(days) days ago")
    }
}

public struct LastUpdatedLabel: View {
    private let lead: LocalizedStringResource
    private let date: Date

    /// `lead` is the phrase the relative time is appended to, e.g. `"Last checked"`. It arrives as a
    /// resource rather than a `String` so it resolves against the calling module's catalogue, not
    /// this one's.
    ///
    /// The two halves are joined lead-then-time with a space, which is a limit of this shape rather
    /// than a general answer: a language that puts the time first, or joins with something other than
    /// a space, cannot express that here. Resolving the halves separately is what forces it — they
    /// belong to different catalogues, so neither can hold a format string with the other's slot in
    /// it. A language that needs a different order wants one catalogue entry that takes the relative
    /// phrase as an argument, which means moving the lead into the component's own catalogue.
    public init(lead: LocalizedStringResource, date: Date) {
        self.lead = lead
        self.date = date
    }

    public var body: some View {
        TimelineView(.periodic(from: date, by: 60)) { context in
            // Two `Text` values concatenated rather than one interpolated string: the lead and the
            // relative phrase live in different catalogues and must resolve separately.
            (Text(lead) + Text(verbatim: " ") + Text(RelativeTimeText.resource(for: date, relativeTo: context.date)))
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextTertiary)
        }
    }
}

#if DEBUG
    #Preview("Last updated") {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            LastUpdatedLabel(lead: LocalizedStringResource(uiComponents: "Last checked"), date: .now)
            LastUpdatedLabel(
                lead: LocalizedStringResource(uiComponents: "Last checked"),
                date: .now.addingTimeInterval(-3600),
            )
        }
        .padding()
    }
#endif

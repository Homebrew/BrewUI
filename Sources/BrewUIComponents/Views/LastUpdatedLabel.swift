//
//  LastUpdatedLabel.swift
//  BrewUIComponents
//

import Foundation
import SwiftUI

/// Time buckets are language-agnostic; the presentation layer supplies copy resolution so translated strings are not cached.
public enum RelativeTimeText {
    public static func string(
        for date: Date,
        relativeTo now: Date,
        localize: (String.LocalizationValue) -> String = { String(localized: $0) },
    ) -> String {
        let seconds = now.timeIntervalSince(date)
        guard seconds >= 60 else {
            return localize("just now")
        }
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return minutes == 1 ? localize("1 minute ago") : localize("\(minutes) minutes ago")
        }
        let hours = minutes / 60
        if hours < 24 {
            return hours == 1 ? localize("1 hour ago") : localize("\(hours) hours ago")
        }
        let days = hours / 24
        return days == 1 ? localize("1 day ago") : localize("\(days) days ago")
    }
}

public struct LastUpdatedLabel: View {
    @Environment(\.brewLocalization) private var localization

    private let lead: String.LocalizationValue
    private let date: Date

    /// `lead` is the phrase the relative time is appended to, e.g. `"Last checked"`.
    public init(lead: String.LocalizationValue, date: Date) {
        self.lead = lead
        self.date = date
    }

    public var body: some View {
        TimelineView(.periodic(from: date, by: 60)) { context in
            let relativeTime = RelativeTimeText.string(
                for: date,
                relativeTo: context.date,
                localize: localization.string,
            )
            Text(localization.string("\(localization.string(lead)) \(relativeTime)"))
                .font(.brewCaption)
                .foregroundStyle(Color.brewTextTertiary)
        }
    }
}

#if DEBUG
    #Preview("Last updated") {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            LastUpdatedLabel(lead: "Last checked", date: .now)
            LastUpdatedLabel(lead: "Last checked", date: .now.addingTimeInterval(-3600))
        }
        .padding()
    }
#endif

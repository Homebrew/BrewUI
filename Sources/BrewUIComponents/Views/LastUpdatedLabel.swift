//
//  LastUpdatedLabel.swift
//  BrewUIComponents
//

import Foundation
import SwiftUI

/// Keeps the existing minute-granularity thresholds while localizing complete time phrases.
public enum RelativeTimeText {
    public static func string(for date: Date, relativeTo now: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        guard seconds >= 60 else {
            // Also covers a future date: a clock that moved backwards should read as "now", not a countdown.
            return String(localized: "just now")
        }
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return minutes == 1 ? String(localized: "1 minute ago") : String(localized: "\(minutes) minutes ago")
        }
        let hours = minutes / 60
        if hours < 24 {
            return hours == 1 ? String(localized: "1 hour ago") : String(localized: "\(hours) hours ago")
        }
        let days = hours / 24
        return days == 1 ? String(localized: "1 day ago") : String(localized: "\(days) days ago")
    }
}

public struct LastUpdatedLabel: View {
    private let lead: LocalizedStringKey
    private let date: Date

    /// `lead` is the phrase the relative time is appended to, e.g. `"Last checked"`.
    public init(lead: LocalizedStringKey, date: Date) {
        self.lead = lead
        self.date = date
    }

    public var body: some View {
        TimelineView(.periodic(from: date, by: 60)) { context in
            Text("\(Text(lead)) \(RelativeTimeText.string(for: date, relativeTo: context.date))")
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

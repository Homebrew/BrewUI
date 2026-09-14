//
//  LastUpdatedLabel.swift
//  BrewUIComponents
//

import Foundation
import SwiftUI

/// Spelled out rather than left to `RelativeDateTimeFormatter`, which follows the system locale and would
/// put a translated phrase after an English lead-in.
public enum RelativeTimeText {
    public static func string(for date: Date, relativeTo now: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        guard seconds >= 60 else {
            // Also covers a future date: a clock that moved backwards should read as "now", not a countdown.
            return String(localized: "just now", comment: "Relative timestamp under one minute")
        }
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return minutes == 1
                ? String(localized: "1 minute ago", comment: "Relative timestamp one minute ago")
                : String(localized: "\(minutes) minutes ago", comment: "Relative timestamp in minutes")
        }
        let hours = minutes / 60
        if hours < 24 {
            return hours == 1
                ? String(localized: "1 hour ago", comment: "Relative timestamp one hour ago")
                : String(localized: "\(hours) hours ago", comment: "Relative timestamp in hours")
        }
        let days = hours / 24
        return days == 1
            ? String(localized: "1 day ago", comment: "Relative timestamp one day ago")
            : String(localized: "\(days) days ago", comment: "Relative timestamp in days")
    }
}

public struct LastUpdatedLabel: View {
    private let lead: String
    private let date: Date

    /// `lead` is the phrase the relative time is appended to, e.g. `"Last checked"`.
    public init(lead: String, date: Date) {
        self.lead = lead
        self.date = date
    }

    public var body: some View {
        TimelineView(.periodic(from: date, by: 60)) { context in
            Text("\(lead) \(RelativeTimeText.string(for: date, relativeTo: context.date))")
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

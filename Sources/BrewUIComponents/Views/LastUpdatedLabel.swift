//
//  LastUpdatedLabel.swift
//  BrewUIComponents
//

import Foundation
import SwiftUI

/// Coarser than `RelativeDateTimeFormatter` on purpose: minute granularity, no seconds, no "in …".
public enum RelativeTimeText {
    public static func string(for date: Date, relativeTo now: Date) -> String {
        let seconds = now.timeIntervalSince(date)
        guard seconds >= 60 else {
            // Also covers a future date: a clock that moved backwards should read as "now", not a countdown.
            return String(localized: "just now", bundle: #bundle, comment: "Relative time: under a minute ago")
        }
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return minutes == 1
                ? String(localized: "1 minute ago", bundle: #bundle, comment: "Relative time")
                : String(localized: "\(minutes) minutes ago", bundle: #bundle, comment: "Relative time, %lld ≥ 2")
        }
        let hours = minutes / 60
        if hours < 24 {
            return hours == 1
                ? String(localized: "1 hour ago", bundle: #bundle, comment: "Relative time")
                : String(localized: "\(hours) hours ago", bundle: #bundle, comment: "Relative time, %lld ≥ 2")
        }
        let days = hours / 24
        return days == 1
            ? String(localized: "1 day ago", bundle: #bundle, comment: "Relative time")
            : String(localized: "\(days) days ago", bundle: #bundle, comment: "Relative time, %lld ≥ 2")
    }
}

public struct LastUpdatedLabel: View {
    private let lead: LocalizedStringResource
    private let date: Date
    private let font: Font
    private let color: Color

    /// 默认保留时间元数据样式；页面可复用现有字体和颜色 token。
    public init(
        lead: LocalizedStringResource,
        date: Date,
        font: Font = .brewCaption,
        color: Color = .brewTextTertiary,
    ) {
        self.lead = lead
        self.date = date
        self.font = font
        self.color = color
    }

    public var body: some View {
        TimelineView(.periodic(from: date, by: 60)) { context in
            // One key, not concatenation: translations reorder the two halves.
            Text(LocalizedStringResource(
                "\(String(localized: lead)) \(RelativeTimeText.string(for: date, relativeTo: context.date))",
                bundle: #bundle,
                comment: "Last-updated label: %1$@ is the lead phrase (e.g. “Last checked”), %2$@ the relative time",
            ))
            .font(font)
            .foregroundStyle(color)
        }
    }
}

#if DEBUG
    #Preview("Last updated") {
        VStack(alignment: .leading, spacing: BrewSpacing.xs) {
            LastUpdatedLabel(lead: previewCopy("Last checked"), date: .now)
            LastUpdatedLabel(lead: previewCopy("Last checked"), date: .now.addingTimeInterval(-3600))
        }
        .padding()
    }
#endif

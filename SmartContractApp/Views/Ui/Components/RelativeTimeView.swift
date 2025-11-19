//
//  RelativeTimeView.swift
//  SmartContractApp
//
//  Created by Claude on 11/19/25.
//

import SwiftUI

/// A view that displays relative time with an absolute timestamp tooltip on hover
struct RelativeTimeView: View {
    let date: Date
    let font: Font
    let foregroundColor: Color

    init(
        date: Date,
        font: Font = .caption2,
        foregroundColor: Color = .secondary
    ) {
        self.date = date
        self.font = font
        self.foregroundColor = foregroundColor
    }

    var body: some View {
        Text(RelativeTimeFormatter.formatRelativeTime(from: date))
            .font(font)
            .foregroundColor(foregroundColor)
            .help(RelativeTimeFormatter.formatAbsoluteTime(from: date))
    }
}

// MARK: - Preview

#Preview("Just now") {
    VStack(spacing: 16) {
        RelativeTimeView(date: Date())
        RelativeTimeView(date: Date().addingTimeInterval(-5))
        RelativeTimeView(date: Date().addingTimeInterval(-30))
    }
    .padding()
}

#Preview("Minutes and Hours") {
    VStack(spacing: 16) {
        RelativeTimeView(date: Date().addingTimeInterval(-90)) // 1.5 min
        RelativeTimeView(date: Date().addingTimeInterval(-600)) // 10 min
        RelativeTimeView(date: Date().addingTimeInterval(-3600)) // 1 hour
        RelativeTimeView(date: Date().addingTimeInterval(-7200)) // 2 hours
    }
    .padding()
}

#Preview("Days and Weeks") {
    VStack(spacing: 16) {
        RelativeTimeView(date: Date().addingTimeInterval(-86400)) // 1 day
        RelativeTimeView(date: Date().addingTimeInterval(-172800)) // 2 days
        RelativeTimeView(date: Date().addingTimeInterval(-604800)) // 1 week
        RelativeTimeView(date: Date().addingTimeInterval(-1209600)) // 2 weeks
    }
    .padding()
}

#Preview("Months and Years") {
    VStack(spacing: 16) {
        RelativeTimeView(date: Date().addingTimeInterval(-2592000)) // 1 month
        RelativeTimeView(date: Date().addingTimeInterval(-5184000)) // 2 months
        RelativeTimeView(date: Date().addingTimeInterval(-31536000)) // 1 year
        RelativeTimeView(date: Date().addingTimeInterval(-63072000)) // 2 years
    }
    .padding()
}

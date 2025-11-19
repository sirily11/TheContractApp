//
//  RelativeTimeFormatter.swift
//  SmartContractApp
//
//  Created by Claude on 11/19/25.
//

import Foundation

/// Utility for formatting dates as relative time strings
enum RelativeTimeFormatter {
    /// Format a date as a relative time string (e.g., "a few seconds ago", "2 hours ago")
    /// - Parameter date: The date to format
    /// - Returns: A human-readable relative time string
    static func formatRelativeTime(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)

        // Handle future dates
        if timeInterval < 0 {
            return "just now"
        }

        let seconds = Int(timeInterval)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        let weeks = days / 7
        let months = days / 30
        let years = days / 365

        switch timeInterval {
        case 0..<10:
            return "just now"
        case 10..<60:
            return "a few seconds ago"
        case 60..<120:
            return "a minute ago"
        case 120..<3600:
            return "\(minutes) minutes ago"
        case 3600..<7200:
            return "an hour ago"
        case 7200..<86400:
            return "\(hours) hours ago"
        case 86400..<172800:
            return "a day ago"
        case 172800..<604800:
            return "\(days) days ago"
        case 604800..<1209600:
            return "a week ago"
        case 1209600..<2592000:
            return "\(weeks) weeks ago"
        case 2592000..<5184000:
            return "a month ago"
        case 5184000..<31536000:
            return "\(months) months ago"
        case 31536000..<63072000:
            return "a year ago"
        default:
            return "\(years) years ago"
        }
    }

    /// Format a date as an absolute timestamp string
    /// - Parameter date: The date to format
    /// - Returns: A formatted timestamp string (e.g., "Nov 19, 2025 at 11:45 PM")
    static func formatAbsoluteTime(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

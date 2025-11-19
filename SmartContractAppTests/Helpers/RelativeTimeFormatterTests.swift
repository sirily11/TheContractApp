//
//  RelativeTimeFormatterTests.swift
//  SmartContractAppTests
//
//  Created by Claude on 11/19/25.
//

import Foundation
import Testing
@testable import SmartContractApp

@Suite("RelativeTimeFormatter Tests")
struct RelativeTimeFormatterTests {
    // MARK: - formatRelativeTime Tests

    @Test("formatRelativeTime returns 'just now' for very recent times")
    func testFormatRelativeTime_JustNow() {
        let now = Date()

        // Test current moment
        let result1 = RelativeTimeFormatter.formatRelativeTime(from: now)
        #expect(result1 == "just now")

        // Test 5 seconds ago
        let fiveSecondsAgo = now.addingTimeInterval(-5)
        let result2 = RelativeTimeFormatter.formatRelativeTime(from: fiveSecondsAgo)
        #expect(result2 == "just now")

        // Test 9 seconds ago (edge case)
        let nineSecondsAgo = now.addingTimeInterval(-9)
        let result3 = RelativeTimeFormatter.formatRelativeTime(from: nineSecondsAgo)
        #expect(result3 == "just now")
    }

    @Test("formatRelativeTime returns 'a few seconds ago' for 10-59 seconds")
    func testFormatRelativeTime_FewSeconds() {
        let now = Date()

        // Test 10 seconds ago
        let tenSecondsAgo = now.addingTimeInterval(-10)
        let result1 = RelativeTimeFormatter.formatRelativeTime(from: tenSecondsAgo)
        #expect(result1 == "a few seconds ago")

        // Test 30 seconds ago
        let thirtySecondsAgo = now.addingTimeInterval(-30)
        let result2 = RelativeTimeFormatter.formatRelativeTime(from: thirtySecondsAgo)
        #expect(result2 == "a few seconds ago")

        // Test 59 seconds ago (edge case)
        let fiftyNineSecondsAgo = now.addingTimeInterval(-59)
        let result3 = RelativeTimeFormatter.formatRelativeTime(from: fiftyNineSecondsAgo)
        #expect(result3 == "a few seconds ago")
    }

    @Test("formatRelativeTime returns 'a minute ago' for 1-2 minutes")
    func testFormatRelativeTime_OneMinute() {
        let now = Date()

        // Test 60 seconds ago (exactly 1 minute)
        let oneMinuteAgo = now.addingTimeInterval(-60)
        let result1 = RelativeTimeFormatter.formatRelativeTime(from: oneMinuteAgo)
        #expect(result1 == "a minute ago")

        // Test 90 seconds ago (1.5 minutes)
        let ninetySecondsAgo = now.addingTimeInterval(-90)
        let result2 = RelativeTimeFormatter.formatRelativeTime(from: ninetySecondsAgo)
        #expect(result2 == "a minute ago")

        // Test 119 seconds ago (edge case)
        let oneNineteenSecondsAgo = now.addingTimeInterval(-119)
        let result3 = RelativeTimeFormatter.formatRelativeTime(from: oneNineteenSecondsAgo)
        #expect(result3 == "a minute ago")
    }

    @Test("formatRelativeTime returns 'X minutes ago' for 2-59 minutes")
    func testFormatRelativeTime_MultipleMinutes() {
        let now = Date()

        // Test 2 minutes ago
        let twoMinutesAgo = now.addingTimeInterval(-120)
        let result1 = RelativeTimeFormatter.formatRelativeTime(from: twoMinutesAgo)
        #expect(result1 == "2 minutes ago")

        // Test 30 minutes ago
        let thirtyMinutesAgo = now.addingTimeInterval(-1800)
        let result2 = RelativeTimeFormatter.formatRelativeTime(from: thirtyMinutesAgo)
        #expect(result2 == "30 minutes ago")

        // Test 59 minutes ago
        let fiftyNineMinutesAgo = now.addingTimeInterval(-3540)
        let result3 = RelativeTimeFormatter.formatRelativeTime(from: fiftyNineMinutesAgo)
        #expect(result3 == "59 minutes ago")
    }

    @Test("formatRelativeTime returns 'an hour ago' for 1-2 hours")
    func testFormatRelativeTime_OneHour() {
        let now = Date()

        // Test 1 hour ago
        let oneHourAgo = now.addingTimeInterval(-3600)
        let result1 = RelativeTimeFormatter.formatRelativeTime(from: oneHourAgo)
        #expect(result1 == "an hour ago")

        // Test 1.5 hours ago
        let oneHalfHoursAgo = now.addingTimeInterval(-5400)
        let result2 = RelativeTimeFormatter.formatRelativeTime(from: oneHalfHoursAgo)
        #expect(result2 == "an hour ago")
    }

    @Test("formatRelativeTime returns 'X hours ago' for 2-23 hours")
    func testFormatRelativeTime_MultipleHours() {
        let now = Date()

        // Test 2 hours ago
        let twoHoursAgo = now.addingTimeInterval(-7200)
        let result1 = RelativeTimeFormatter.formatRelativeTime(from: twoHoursAgo)
        #expect(result1 == "2 hours ago")

        // Test 12 hours ago
        let twelveHoursAgo = now.addingTimeInterval(-43200)
        let result2 = RelativeTimeFormatter.formatRelativeTime(from: twelveHoursAgo)
        #expect(result2 == "12 hours ago")

        // Test 23 hours ago
        let twentyThreeHoursAgo = now.addingTimeInterval(-82800)
        let result3 = RelativeTimeFormatter.formatRelativeTime(from: twentyThreeHoursAgo)
        #expect(result3 == "23 hours ago")
    }

    @Test("formatRelativeTime returns 'a day ago' for 1-2 days")
    func testFormatRelativeTime_OneDay() {
        let now = Date()

        // Test 1 day ago
        let oneDayAgo = now.addingTimeInterval(-86400)
        let result1 = RelativeTimeFormatter.formatRelativeTime(from: oneDayAgo)
        #expect(result1 == "a day ago")

        // Test 1.5 days ago
        let oneHalfDaysAgo = now.addingTimeInterval(-129600)
        let result2 = RelativeTimeFormatter.formatRelativeTime(from: oneHalfDaysAgo)
        #expect(result2 == "a day ago")
    }

    @Test("formatRelativeTime returns 'X days ago' for 2-6 days")
    func testFormatRelativeTime_MultipleDays() {
        let now = Date()

        // Test 2 days ago
        let twoDaysAgo = now.addingTimeInterval(-172800)
        let result1 = RelativeTimeFormatter.formatRelativeTime(from: twoDaysAgo)
        #expect(result1 == "2 days ago")

        // Test 5 days ago
        let fiveDaysAgo = now.addingTimeInterval(-432000)
        let result2 = RelativeTimeFormatter.formatRelativeTime(from: fiveDaysAgo)
        #expect(result2 == "5 days ago")
    }

    @Test("formatRelativeTime returns 'a week ago' for 1-2 weeks")
    func testFormatRelativeTime_OneWeek() {
        let now = Date()

        // Test 1 week ago
        let oneWeekAgo = now.addingTimeInterval(-604800)
        let result1 = RelativeTimeFormatter.formatRelativeTime(from: oneWeekAgo)
        #expect(result1 == "a week ago")

        // Test 10 days ago
        let tenDaysAgo = now.addingTimeInterval(-864000)
        let result2 = RelativeTimeFormatter.formatRelativeTime(from: tenDaysAgo)
        #expect(result2 == "a week ago")
    }

    @Test("formatRelativeTime returns 'X weeks ago' for 2-4 weeks")
    func testFormatRelativeTime_MultipleWeeks() {
        let now = Date()

        // Test 2 weeks ago
        let twoWeeksAgo = now.addingTimeInterval(-1209600)
        let result1 = RelativeTimeFormatter.formatRelativeTime(from: twoWeeksAgo)
        #expect(result1 == "2 weeks ago")

        // Test 3 weeks ago
        let threeWeeksAgo = now.addingTimeInterval(-1814400)
        let result2 = RelativeTimeFormatter.formatRelativeTime(from: threeWeeksAgo)
        #expect(result2 == "3 weeks ago")
    }

    @Test("formatRelativeTime returns 'a month ago' for 1-2 months")
    func testFormatRelativeTime_OneMonth() {
        let now = Date()

        // Test 1 month ago (30 days)
        let oneMonthAgo = now.addingTimeInterval(-2592000)
        let result1 = RelativeTimeFormatter.formatRelativeTime(from: oneMonthAgo)
        #expect(result1 == "a month ago")

        // Test 45 days ago
        let fortyFiveDaysAgo = now.addingTimeInterval(-3888000)
        let result2 = RelativeTimeFormatter.formatRelativeTime(from: fortyFiveDaysAgo)
        #expect(result2 == "a month ago")
    }

    @Test("formatRelativeTime returns 'X months ago' for 2-11 months")
    func testFormatRelativeTime_MultipleMonths() {
        let now = Date()

        // Test 2 months ago
        let twoMonthsAgo = now.addingTimeInterval(-5184000)
        let result1 = RelativeTimeFormatter.formatRelativeTime(from: twoMonthsAgo)
        #expect(result1 == "2 months ago")

        // Test 6 months ago
        let sixMonthsAgo = now.addingTimeInterval(-15552000)
        let result2 = RelativeTimeFormatter.formatRelativeTime(from: sixMonthsAgo)
        #expect(result2 == "6 months ago")
    }

    @Test("formatRelativeTime returns 'a year ago' for 1-2 years")
    func testFormatRelativeTime_OneYear() {
        let now = Date()

        // Test 1 year ago
        let oneYearAgo = now.addingTimeInterval(-31536000)
        let result1 = RelativeTimeFormatter.formatRelativeTime(from: oneYearAgo)
        #expect(result1 == "a year ago")

        // Test 1.5 years ago
        let oneHalfYearsAgo = now.addingTimeInterval(-47304000)
        let result2 = RelativeTimeFormatter.formatRelativeTime(from: oneHalfYearsAgo)
        #expect(result2 == "a year ago")
    }

    @Test("formatRelativeTime returns 'X years ago' for 2+ years")
    func testFormatRelativeTime_MultipleYears() {
        let now = Date()

        // Test 2 years ago
        let twoYearsAgo = now.addingTimeInterval(-63072000)
        let result1 = RelativeTimeFormatter.formatRelativeTime(from: twoYearsAgo)
        #expect(result1 == "2 years ago")

        // Test 5 years ago
        let fiveYearsAgo = now.addingTimeInterval(-157680000)
        let result2 = RelativeTimeFormatter.formatRelativeTime(from: fiveYearsAgo)
        #expect(result2 == "5 years ago")
    }

    @Test("formatRelativeTime handles future dates")
    func testFormatRelativeTime_FutureDates() {
        let now = Date()

        // Test future date
        let futureDate = now.addingTimeInterval(3600)
        let result = RelativeTimeFormatter.formatRelativeTime(from: futureDate)
        #expect(result == "just now")
    }

    // MARK: - formatAbsoluteTime Tests

    @Test("formatAbsoluteTime returns formatted date string")
    func testFormatAbsoluteTime() {
        // Create a specific date for testing
        let calendar = Calendar.current
        let components = DateComponents(
            year: 2025,
            month: 11,
            day: 19,
            hour: 23,
            minute: 45
        )
        let date = calendar.date(from: components)!

        let result = RelativeTimeFormatter.formatAbsoluteTime(from: date)

        // The exact format may vary by locale, but it should contain the date components
        #expect(result.contains("2025"))
        #expect(result.contains("19"))
    }

    @Test("formatAbsoluteTime is consistent")
    func testFormatAbsoluteTime_Consistency() {
        let date = Date()

        let result1 = RelativeTimeFormatter.formatAbsoluteTime(from: date)
        let result2 = RelativeTimeFormatter.formatAbsoluteTime(from: date)

        // Same date should produce same string
        #expect(result1 == result2)
    }
}

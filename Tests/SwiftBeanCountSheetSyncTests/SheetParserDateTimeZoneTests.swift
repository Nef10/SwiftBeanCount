import Foundation
@testable import SwiftBeanCountSheetSync
import Testing

@Suite(.serialized)
struct SheetParserDateTimeZoneTests {

    @Test
    func parseSheetTotalAmountFormatPreservesLocalCalendarDate() {
        withDefaultTimeZone(TimeZone(secondsFromGMT: -8 * 60 * 60)!) { timeZone in
            let data = [
                ["Date", "Paid to", "Amount", "Category", "Who paid", "Comment", "Part Alice", "Part Bob"],
                ["2024-01-15", "Store", "100.00", "Groceries", "Alice", "Weekly shopping", "50.00", "50.00"]
            ]

            let parsed = SheetParser.parseSheetData(data, name: "Alice")

            #expect(parsed.errors.isEmpty)
            #expect(parsed.rows.count == 1)
            #expect(dateString(parsed.rows[0].transactionData.date, timeZone: timeZone) == "2024-01-15")
        }
    }

    @Test
    func parseSheetShareAmountFormatPreservesLocalCalendarDate() {
        withDefaultTimeZone(TimeZone(secondsFromGMT: -8 * 60 * 60)!) { timeZone in
            let data = [
                ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person"],
                ["2024-01-15", "Bob", "Store", "Lunch", "Food", "15.00"]
            ]

            let parsed = SheetParser.parseSheetData(data, name: "Alice")

            #expect(parsed.errors.isEmpty)
            #expect(parsed.rows.count == 1)
            #expect(dateString(parsed.rows[0].transactionData.date, timeZone: timeZone) == "2024-01-15")
        }
    }

    private func withDefaultTimeZone(_ timeZone: TimeZone, perform: (TimeZone) -> Void) {
        let previousTimeZone = NSTimeZone.default
        NSTimeZone.default = timeZone
        defer {
            NSTimeZone.default = previousTimeZone
        }
        perform(timeZone)
    }

    private func dateString(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

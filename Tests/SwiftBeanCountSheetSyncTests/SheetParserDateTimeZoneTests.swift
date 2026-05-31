import Foundation
@testable import SwiftBeanCountSheetSync
import Testing

@Suite
struct SheetParserDateTimeZoneTests {

    @Test
    func parseSheetTotalAmountFormatPreservesLocalCalendarDate() throws {
        let timeZone = try #require(TimeZone(identifier: "America/Vancouver"))
        let data = [
            ["Date", "Paid to", "Amount", "Category", "Who paid", "Comment", "Part Alice", "Part Bob"],
            ["2024-01-15", "Store", "100.00", "Groceries", "Bob", "Weekly shopping", "50.00", "50.00"]
        ]

        let parsed = SheetParser.parseSheetData(data, name: "Alice", timeZone: timeZone)

        #expect(parsed.errors.isEmpty)
        #expect(parsed.rows.count == 1)
        let row = try #require(parsed.rows.first)
        #expect(dateString(row.transactionData.date, timeZone: timeZone) == "2024-01-15")
    }

    @Test
    func parseSheetShareAmountFormatPreservesLocalCalendarDate() throws {
        let timeZone = try #require(TimeZone(identifier: "America/Vancouver"))
        let data = [
            ["Date", "Payor", "Payee", "Description", "Category", "Share Other Person"],
            ["2024-01-15", "Bob", "Store", "Lunch", "Food", "15.00"]
        ]

        let parsed = SheetParser.parseSheetData(data, name: "Alice", timeZone: timeZone)

        #expect(parsed.errors.isEmpty)
        #expect(parsed.rows.count == 1)
        let row = try #require(parsed.rows.first)
        #expect(dateString(row.transactionData.date, timeZone: timeZone) == "2024-01-15")
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

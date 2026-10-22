import Foundation

/// Parses Ritual's English order dates into ledger-compatible local calendar dates.
enum RitualDateParser {

    /// Parses dates such as "Mon., Oct. 5, 2026 at 12:30 PM", rejecting invalid dates.
    static func date(from text: String) throws -> Date {
        let regex = try NSRegularExpression(pattern: #"^(?:[A-Za-z]{3,9}\.?,\s+)?([A-Za-z]{3,9})\.?\s+(\d{1,2}),\s+(\d{4})(?:\s|$)"#)
        guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            throw RitualDownloadError.invalidResponse("Unreadable order date")
        }
        let values = (1...3).map { String(text[Range(match.range(at: $0), in: text)!]) }
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        guard let month = months.firstIndex(of: String(values[0].prefix(3)).lowercased()), let day = Int(values[1]), let year = Int(values[2]) else {
            throw RitualDownloadError.invalidResponse("Unreadable order date")
        }
        let components = DateComponents(year: year, month: month + 1, day: day)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard components.isValidDate(in: calendar), let date = calendar.date(from: components) else {
            throw RitualDownloadError.invalidResponse("Invalid order calendar date")
        }
        return date
    }

}

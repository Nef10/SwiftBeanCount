import ArgumentParser
import Foundation
import SwiftBeanCountModel
import SwiftyTextTable

struct Accounts: LedgerCommand {

    static var configuration = CommandConfiguration(abstract: "Print all accounts")

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    @OptionGroup() var options: LedgerOption
    @Argument(default: "", help: "String to filter account names by.") var filter: String
    @ArgumentParser.Flag(help: "Hide the table outline.") var hideTable: Bool
    @ArgumentParser.Flag(help: "Hide the opening and closing date.") var hideDates: Bool
    @ArgumentParser.Flag(help: "Hide closed accounts.") var hideClosed: Bool
    @ArgumentParser.Flag(help: "Hide open accounts.") var hideOpen: Bool

    func run() throws {
        let ledger = try parseLedger()

        let name = TextTableColumn(header: "Name")
        let opening = TextTableColumn(header: "opening")
        let closing = TextTableColumn(header: "closing")
        var columns = [name, opening, closing]
        if hideDates {
            columns = [name]
        } else if hideClosed {
            columns = [name, opening]
        }
        var table = TextTable(columns: columns, header: "Accounts")

        var accounts = ledger.accounts.sorted { $0.name.fullName < $1.name.fullName }
        if !filter.isEmpty {
            accounts = accounts.filter { $0.name.fullName.contains(filter) }
        }
        if hideClosed {
            accounts = accounts.filter { $0.closing == nil || $0.closing! > Date() }
        }
        if hideOpen {
            accounts = accounts.filter { $0.closing != nil && $0.closing! < Date() }
        }

        table.addRows(values: accounts.map {
            hideDates ? [$0.name] : [$0.name, dateString($0.opening), dateString($0.closing)]
        })

        var result: String

        if hideTable {
            table.columnFence = ""
            table.rowFence = ""
            table.cornerFence = ""
            result = table.render().split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
        } else {
            result = table.render()
        }

        print(result)
    }

    private func dateString(_ date: Date?) -> String {
        guard let date = date else {
            return ""
        }
        return Self.dateFormatter.string(from: date)
    }

}

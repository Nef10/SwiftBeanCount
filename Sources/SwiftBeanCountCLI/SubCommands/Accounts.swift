import ArgumentParser
import Foundation
import SwiftBeanCountModel

struct Accounts: FormattableLedgerCommand {

    static var configuration = CommandConfiguration(abstract: "Print all accounts")

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    @OptionGroup() var options: LedgerOption
    @ArgumentParser.Option(name: [.short, .long], default: .table, help: "Output format. Supported formats: \(Format.allCases.map { $0.rawValue }.joined(separator: ", "))") var format: Format
    @Argument(default: "", help: "String to filter account names by.") private var filter: String
    @ArgumentParser.Flag(help: "Hide the opening and closing date.") private var hideDates: Bool
    @ArgumentParser.Flag(help: "Hide closed accounts.") private var hideClosed: Bool
    @ArgumentParser.Flag(help: "Hide open accounts.") private var hideOpen: Bool
    @ArgumentParser.Flag(name: [.short, .long], help: "Display the number of accounts.") private var count: Bool

    func run() throws {
        let ledger = try parseLedger()

        var columns = ["Name", "Opening", "Closing"]
        if hideDates {
            columns = ["Name"]
        } else if hideClosed {
            columns = ["Name", "Opening"]
        }

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

        let values = accounts.map {
            hideDates ? [$0.name.fullName] : [$0.name.fullName, dateString($0.opening), dateString($0.closing)]
        }

        printFormatted(title: "Accounts", columns: columns, values: values)
        if count {
            print("\n \(accounts.count) Accounts")
        }
    }

    private func dateString(_ date: Date?) -> String {
        guard let date = date else {
            return ""
        }
        return Self.dateFormatter.string(from: date)
    }

}

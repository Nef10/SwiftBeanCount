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
    @ArgumentParser.Option(name: [.short, .long], default: .table, help: "Output format. \(Self.supportedFormats())") var format: Format
    @Argument(default: "", help: "String to filter account names by.") private var filter: String
    @ArgumentParser.Flag(default: true, inversion: .prefixedNo, help: "Show open accounts.") private var open: Bool
    @ArgumentParser.Flag(default: true, inversion: .prefixedNo, help: "Show closed accounts.") private var closed: Bool
    @ArgumentParser.Flag(default: true, inversion: .prefixedNo, help: "Show dates of account opening and closing.") private var dates: Bool
    @ArgumentParser.Flag(name: [.short, .long], help: "Display the number of accounts.") private var count: Bool

    func validate() throws {
        if format == .csv && count {
            throw ValidationError("Cannot print count in csv format. Please remove count flag or specify another format.")
        }
    }

    func run() throws {
        let ledger = try parseLedger()

        var columns = ["Name", "Opening", "Closing"]
        if !dates {
            columns = ["Name"]
        } else if !closed {
            columns = ["Name", "Opening"]
        }

        var accounts = ledger.accounts.sorted { $0.name.fullName < $1.name.fullName }
        if !filter.isEmpty {
            accounts = accounts.filter { $0.name.fullName.contains(filter) }
        }
        if !closed {
            accounts = accounts.filter { $0.closing == nil || $0.closing! > Date() }
        }
        if !open {
            accounts = accounts.filter { $0.closing != nil && $0.closing! < Date() }
        }

        let values = accounts.map {
            dates ? [$0.name.fullName, dateString($0.opening), dateString($0.closing)] : [$0.name.fullName]
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

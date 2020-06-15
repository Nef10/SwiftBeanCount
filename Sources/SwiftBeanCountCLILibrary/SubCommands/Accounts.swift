import ArgumentParser
import Foundation
import SwiftBeanCountModel

struct Accounts: LedgerCommand, FormattableCommand {

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
    @ArgumentParser.Flag(default: false, inversion: .prefixedNo, help: "Show number of postings in each account.") private var postings: Bool
    @ArgumentParser.Flag(default: false, inversion: .prefixedNo, help: "Show the date of the last activity in each account.") private var activity: Bool
    @ArgumentParser.Flag(name: [.short, .long], help: "Display the number of accounts.") private var count: Bool

    func validate() throws {
        if format == .csv && count {
            throw ValidationError("Cannot print count in csv format. Please remove count flag or specify another format.")
        }
    }

    func run() throws {
        let ledger = try parseLedger()

        var columns = ["Name"]
        if postings {
            columns.append("# Postings")
        }
        if activity {
            columns.append("Last Activity")
        }
        if dates {
            columns.append("Opening")
            if closed {
                columns.append("Closing")
            }
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

        let values: [[String]] = accounts.map { account in
            var result = [account.name.fullName]
            if postings {
                result.append(String(ledger.transactions.map { $0.postings.filter { $0.accountName == account.name }.count }.reduce(0) { $0 + $1 }))
            }
            if activity {
                let transactionDates = ledger.transactions.compactMap { $0.postings.contains { $0.accountName == account.name } ? $0.metaData.date : nil }
                let balanceDates = account.balances.map { $0.date }
                let dates = (transactionDates + balanceDates + [account.opening] + [account.closing]).compactMap { $0 }.sorted(by: >)
                result.append(dateString(dates.first))
            }
            if dates {
                result.append(dateString(account.opening))
                if closed {
                    result.append(dateString(account.closing))
                }
            }
            return result
        }

        printFormatted(title: "Accounts", columns: columns, values: values)
        if count {
            print("\n\(accounts.count) Accounts")
        }
    }

    private func dateString(_ date: Date?) -> String {
        guard let date = date else {
            return ""
        }
        return Self.dateFormatter.string(from: date)
    }

}

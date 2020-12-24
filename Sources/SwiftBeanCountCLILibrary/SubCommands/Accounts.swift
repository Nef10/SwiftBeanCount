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
    @Argument(help: "String to filter account names by.") private var filter: String = ""
    @ArgumentParser.Option(name: [.short, .long], help: "Output format. \(Self.supportedFormats())") var format: Format = .table
    @ArgumentParser.Flag(help: Self.noColorHelp()) var noColor: Bool = false
    @ArgumentParser.Flag(inversion: .prefixedNo, help: "Show open accounts.") private var open: Bool = true
    @ArgumentParser.Flag(inversion: .prefixedNo, help: "Show closed accounts.") private var closed: Bool = true
    @ArgumentParser.Flag(inversion: .prefixedNo, help: "Show dates of account opening and closing.") private var dates: Bool = true
    @ArgumentParser.Flag(inversion: .prefixedNo, help: "Show number of postings in each account.") private var postings: Bool = false
    @ArgumentParser.Flag(inversion: .prefixedNo, help: "Show the date of the last activity in each account.") private var activity: Bool = false
    @ArgumentParser.Flag(name: [.short, .long], help: "Display the number of accounts.") private var count: Bool = false

    func validate() throws {
        if format == .csv && count {
            throw ValidationError("Cannot print count in csv format. Please remove count flag or specify another format.")
        }
    }

    func getResult(from ledger: Ledger, parsingDuration _: Double) -> FormattableResult {
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
                let allDates = transactionDates + balanceDates + [account.opening] + [account.closing]
                let dates = allDates.compactMap { $0 }.sorted(by: >)
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

        var footer: String?
        if count {
           footer = "\(accounts.count) Accounts"
        }

        return FormattableResult(title: "Accounts", columns: columns(), values: values, footer: footer)
    }

     private func columns() -> [String] {
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
        return columns
    }

    private func dateString(_ date: Date?) -> String {
        guard let date = date else {
            return ""
        }
        return Self.dateFormatter.string(from: date)
    }

}

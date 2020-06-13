import ArgumentParser
import Foundation
import SwiftBeanCountModel

struct Stats: FormattableLedgerCommand {

    static var configuration = CommandConfiguration(abstract: "Statistics of a ledger (e.g. # of transactions)")

    @OptionGroup() var options: LedgerOption
    @ArgumentParser.Option(name: [.short, .long], default: .table, help: "Output format. \(Self.supportedFormats())") var format: Format

    func run() throws {
        let start = Date.timeIntervalSinceReferenceDate
        let ledger = try parseLedger()
        let end = Date.timeIntervalSinceReferenceDate
        let time = end - start

        let values: [[String]] = [
            ["Transactions", String(ledger.transactions.count)],
            ["Accounts", String(ledger.accounts.count)],
            ["Account openings", String(ledger.accounts.filter { $0.opening != nil }.count)],
            ["Account closings", String(ledger.accounts.filter { $0.closing != nil }.count)],
            ["Commodities", String(ledger.commodities.count)],
            ["Tags", String(ledger.tags.count)],
            ["Events", String(ledger.events.count)],
            ["Customs", String(ledger.custom.count)],
            ["Options", String(ledger.option.count)],
            ["Plugins", String(ledger.plugins.count)]
        ]

        printFormatted(title: "Statistics", columns: ["Type", "Number"], values: values)
        if format != .csv {
            print(String(format: "\nParsing time: %.3f sec", time))
        }
    }

}

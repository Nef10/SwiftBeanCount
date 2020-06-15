import ArgumentParser
import Foundation
import Rainbow
import SwiftBeanCountModel

struct Stats: LedgerCommand, FormattableCommand, ColorizedCommand {

    static var configuration = CommandConfiguration(abstract: "Statistics of a ledger (e.g. # of transactions)")

    @OptionGroup() var options: LedgerOption
    @ArgumentParser.Option(name: [.short, .long], default: .table, help: "Output format. \(Self.supportedFormats())") var format: Format
    @ArgumentParser.Flag(help: Self.noColorHelp()) var noColor: Bool

    func run() throws {
        adjustColorization()
        let start = Date.timeIntervalSinceReferenceDate
        let ledger = try parseLedger()
        let end = Date.timeIntervalSinceReferenceDate
        let time = end - start

        let values: [[String]] = [
            ["Transactions", String(ledger.transactions.count)],
            ["Accounts", String(ledger.accounts.count)],
            ["Account openings", String(ledger.accounts.filter { $0.opening != nil }.count)],
            ["Account closings", String(ledger.accounts.filter { $0.closing != nil }.count)],
            ["Balances", String(ledger.accounts.map { $0.balances.count }.reduce(0) { $0 + $1 })],
            ["Prices", String(ledger.prices.count)],
            ["Commodities", String(ledger.commodities.count)],
            ["Tags", String(ledger.tags.count)],
            ["Events", String(ledger.events.count)],
            ["Customs", String(ledger.custom.count)],
            ["Options", String(ledger.option.count)],
            ["Plugins", String(ledger.plugins.count)]
        ]

        print(formatted(title: "Statistics", columns: ["Type", "Number"], values: values))
        if format != .csv {
            print(String(format: "\nParsing time: %.3f sec".lightBlack, time))
        }
    }

}

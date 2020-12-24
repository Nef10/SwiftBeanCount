import ArgumentParser
import SwiftBeanCountModel

struct Stats: FormattableLedgerCommand {

    static var configuration = CommandConfiguration(abstract: "Statistics of a ledger (e.g. # of transactions)")

    @OptionGroup() var options: LedgerOption
    @ArgumentParser.Option(name: [.short, .long], help: "Output format. \(Self.supportedFormats())") var format: Format = .table
    @ArgumentParser.Flag(help: Self.noColorHelp()) var noColor: Bool = false

    func getResult(from ledger: Ledger, parsingDuration: Double) -> FormattableResult {
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

        let footer = String(format: "Parsing time: %.3f sec", parsingDuration)
        return FormattableResult(title: "Statistics", columns: ["Type", "Number"], values: values, footer: footer)
    }

}

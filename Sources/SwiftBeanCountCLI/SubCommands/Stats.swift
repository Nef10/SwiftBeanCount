import ArgumentParser
import Foundation
import SwiftBeanCountModel

struct Stats: LedgerCommand {

    static var configuration = CommandConfiguration(abstract: "Statistics of a ledger (e.g. # of transactions)")

    @OptionGroup() var options: LedgerOption

    func run() throws {
        let start = Date.timeIntervalSinceReferenceDate
        let ledger = try parseLedger()
        let end = Date.timeIntervalSinceReferenceDate
        let time = end - start

        print("""
            \(ledger.transactions.count) Transactions
            \(ledger.accounts.count) Accounts
            \(ledger.accounts.filter { $0.opening != nil }.count) Account openings
            \(ledger.accounts.filter { $0.closing != nil }.count) Account closings
            \(ledger.tags.count) Tags
            \(ledger.commodities.count) Commodities
            \(ledger.events.count) Events
            \(ledger.custom.count) Customs
            \(ledger.option.count) Options
            \(ledger.plugins.count) Plugins
            \(String(format: "\nParsing time: %.3f sec", time))
            """)
    }

}

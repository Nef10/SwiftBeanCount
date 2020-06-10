import ArgumentParser
import Foundation
import SwiftBeanCountModel
import SwiftBeanCountParser

extension SwiftBeanCountCLI {

    struct Stats: ParsableCommand {

        struct CheckOptions: ParsableArguments { //swiftlint:disable:this nesting
            @Argument(help: "The file to parse")
            var file: String
        }

        static var configuration = CommandConfiguration(abstract: "Parses a ledger and prints statistics")

        @OptionGroup() var options: CheckOptions

        func run() throws {
            let ledger: Ledger
            var time: Double
            do {
                let start = Date.timeIntervalSinceReferenceDate
                ledger = try Parser.parse(contentOf: URL(fileURLWithPath: options.file))
                let end = Date.timeIntervalSinceReferenceDate
                time = end - start
            } catch {
                print(error.localizedDescription)
                throw ExitCode.failure
            }
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

}

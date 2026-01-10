import ArgumentParser
import Foundation
import SwiftBeanCountModel
import SwiftBeanCountParser

struct LedgerCommandOptions: ParsableArguments {
    @Argument(help: "The file to parse.")
    var file: String
}

protocol LedgerCommand: ParsableCommand {
    var ledgerOptions: LedgerCommandOptions { get }
}

extension LedgerCommand {

    func parseLedger() throws(any Error) -> Ledger {
        let ledger: Ledger
        do {
            ledger = try Parser.parse(contentOf: URL(fileURLWithPath: ledgerOptions.file))
        } catch {
            print(error.localizedDescription)
            throw ExitCode.failure
        }
        return ledger
    }

}

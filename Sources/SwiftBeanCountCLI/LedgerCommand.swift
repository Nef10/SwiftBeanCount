import ArgumentParser
import Foundation
import SwiftBeanCountModel
import SwiftBeanCountParser

struct LedgerOption: ParsableArguments {
    @Argument(help: "The file to parse.") var file: String
}

protocol LedgerCommand: ParsableCommand {
    var options: LedgerOption { get }
}

extension LedgerCommand {

    func parseLedger() throws -> Ledger {
        let ledger: Ledger
        do {
            ledger = try Parser.parse(contentOf: URL(fileURLWithPath: options.file))
        } catch {
            print(error.localizedDescription)
            throw ExitCode.failure
        }
        return ledger
    }

}

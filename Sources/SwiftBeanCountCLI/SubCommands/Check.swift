import ArgumentParser
import SwiftBeanCountModel

struct Check: LedgerCommand {

    static var configuration = CommandConfiguration(abstract: "Parses a ledger and prints any errors it finds")

    @OptionGroup() var options: LedgerOption

    func run() throws {
        let ledger = try parseLedger()
        let errors = ledger.errors
        if !errors.isEmpty {
            print(errors.joined(separator: "\n"))
            throw ExitCode(65)
        }
    }

}

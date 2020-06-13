import ArgumentParser
import SwiftBeanCountModel

struct Check: LedgerCommand {

    static var configuration = CommandConfiguration(abstract: "Parses a ledger and prints any errors it finds")

    @OptionGroup() var options: LedgerOption
    @ArgumentParser.Flag(name: [.short, .long], help: "Don't print errors, only indicate via exit code.") var quiet: Bool


    func run() throws {
        let ledger = try parseLedger()
        let errors = ledger.errors
        if !errors.isEmpty {
            if !quiet {
                print(errors.joined(separator: "\n"))
            }
            throw ExitCode(65)
        }
    }

}

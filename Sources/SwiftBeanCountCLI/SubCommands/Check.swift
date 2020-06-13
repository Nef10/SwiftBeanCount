import ArgumentParser
import SwiftBeanCountModel
import Rainbow

struct Check: LedgerCommand {

    static var configuration = CommandConfiguration(abstract: "Parses a ledger and prints any errors it finds")

    @OptionGroup() var options: LedgerOption
    @ArgumentParser.Flag(name: [.short, .long], help: "Don't print errors, only indicate via exit code.") private var quiet: Bool
    @ArgumentParser.Flag(help: "Disable colors in output.\nNote: When output is not connected to a terminal, colorization is disabled automatically.\nYou can also use the NO_COLOR environment variable.") private var noColor: Bool

    func run() throws {
        if noColor || ProcessInfo.processInfo.environment["NO_COLOR"] != nil {
            Rainbow.enabled = false
        }
        let ledger = try parseLedger()
        let errors = ledger.errors
        if !errors.isEmpty {
            if !quiet {
                print("Found ".red + String(errors.count).bold.red + " errors:\n".red)
                print(errors.joined(separator: "\n"))
            }
            throw ExitCode(65)
        } else if !quiet {
            print("No errors found.".green)
        }
    }

}

import ArgumentParser
import Foundation
import Rainbow
import SwiftBeanCountModel

struct Check: LedgerCommand, ColorizedCommand {

    static var configuration = CommandConfiguration(abstract: "Parses a ledger and prints any errors it finds")

    @OptionGroup() var options: LedgerOption
    @ArgumentParser.Flag(name: [.short, .long], help: "Don't print errors, only indicate via exit code.") private var quiet: Bool = false
    @ArgumentParser.Flag(help: Self.noColorHelp()) var noColor: Bool = false

    func run() throws {
        adjustColorization()
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

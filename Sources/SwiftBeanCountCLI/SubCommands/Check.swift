import ArgumentParser
import Foundation
import SwiftBeanCountModel
import SwiftBeanCountParser

extension SwiftBeanCountCLI {

    struct Check: ParsableCommand {

        struct CheckOptions: ParsableArguments { //swiftlint:disable:this nesting
            @Argument(help: "The file to parse")
            var file: String
        }

        static var configuration = CommandConfiguration(abstract: "Parses a ledger and prints any errors it finds")

        @OptionGroup() var options: CheckOptions

        func run() throws {
            let ledger: Ledger
            do {
                ledger = try Parser.parse(contentOf: URL(fileURLWithPath: options.file))
            } catch {
                print(error.localizedDescription)
                throw ExitCode.failure
            }
            let errors = ledger.errors
            if !errors.isEmpty {
                print(errors.joined(separator: "\n"))
                throw ExitCode(65)
            }
        }

    }

}

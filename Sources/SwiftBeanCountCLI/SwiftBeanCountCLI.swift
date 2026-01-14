import ArgumentParser

@main
public struct SwiftBeanCountCLI: ParsableCommand {

    public static var configuration = CommandConfiguration(
        commandName: "swiftbeancount",
        abstract: "A CLI tool for SwiftBeanCount",
        version: "0.1.0",
        subcommands: [Check.self, Stats.self, Accounts.self, TaxSlips.self, TaxableSales.self]
    )

    public init() {
        // Empty
    }

}

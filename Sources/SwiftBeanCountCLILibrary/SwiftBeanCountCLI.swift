import ArgumentParser

public struct SwiftBeanCountCLI: ParsableCommand {

    public static var configuration = CommandConfiguration(
        commandName: "swiftbeancount",
        abstract: "A CLI tool for SwiftBeanCount",
        version: "0.0.1",
        subcommands: [Check.self, Stats.self, Accounts.self]
    )

    public init() {
    }

}

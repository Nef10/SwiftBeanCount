import ArgumentParser

struct SwiftBeanCountCLI: ParsableCommand {

    static var configuration = CommandConfiguration(
        commandName: "swiftbeancount",
        abstract: "A CLI tool for SwiftBeanCount",
        version: "0.0.1",
        subcommands: [Check.self]
    )

}

SwiftBeanCountCLI.main()

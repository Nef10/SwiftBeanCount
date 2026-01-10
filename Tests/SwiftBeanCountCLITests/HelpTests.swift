
import Foundation
@testable import SwiftBeanCountCLI
import Testing

#if os(macOS)

@Suite

struct HelpTests {

  @Test


  func testHelp() {
        let result = outputFromExecutionWith(arguments: ["--help"])
        #expect(result.exitCode == 0)
        #expect(result.errorOutput.isEmpty)
        #expect(result.output.contains("OVERVIEW: A CLI tool for SwiftBeanCount"))
        #expect(result.output.contains("USAGE: swiftbeancount <subcommand>"))
        #expect(result.output.contains("See 'swiftbeancount help <subcommand>' for detailed help."))
    }

}

#endif // os(macOS)

@testable import SwiftBeanCountCLILibrary
import XCTest

class HelpTests: XCTestCase {

   func testHelp() {
        let (exitCode, output) = outputFromExecutionWith(arguments: ["--help"])
        XCTAssertEqual(exitCode, 0)
        XCTAssertTrue(output.contains("OVERVIEW: A CLI tool for SwiftBeanCount"))
        XCTAssertTrue(output.contains("USAGE: swiftbeancount <subcommand>"))
        XCTAssertTrue(output.contains("See 'swiftbeancount help <subcommand>' for detailed help."))
    }

}

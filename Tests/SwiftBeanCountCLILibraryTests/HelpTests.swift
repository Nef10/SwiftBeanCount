@testable import SwiftBeanCountCLILibrary
import XCTest

class HelpTests: XCTestCase {

   func testHelp() {
        let result = outputFromExecutionWith(arguments: ["--help"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.errorOutput.isEmpty)
        XCTAssertTrue(result.output.contains("OVERVIEW: A CLI tool for SwiftBeanCount"))
        XCTAssertTrue(result.output.contains("USAGE: swiftbeancount <subcommand>"))
        XCTAssertTrue(result.output.contains("See 'swiftbeancount help <subcommand>' for detailed help."))
    }

}

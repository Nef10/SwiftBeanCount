@testable import SwiftBeanCountCLILibrary
import XCTest

class HelpTests: XCTestCase {

   func testHelp() {
        let output = outputFromExecutionWith(arguments: ["--help"])
        XCTAssertTrue(output.contains("OVERVIEW: A CLI tool for SwiftBeanCount"))
        XCTAssertTrue(output.contains("USAGE: swiftbeancount <subcommand>"))
        XCTAssertTrue(output.contains("See 'swiftbeancount help <subcommand>' for detailed help."))
    }

}

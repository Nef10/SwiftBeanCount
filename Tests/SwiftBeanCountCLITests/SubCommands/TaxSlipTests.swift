#if os(macOS)

@testable import SwiftBeanCountCLI
import XCTest

final class TaxSlipTests: XCTestCase {

    func testFileDoesNotExist() {
        let url = temporaryFileURL()
        let result = outputFromExecutionWith(arguments: ["tax-slips", url.path])
        XCTAssertEqual(result.exitCode, 1)
        XCTAssert(result.errorOutput.isEmpty)
        #if os(Linux)
        XCTAssertEqual(result.output, "The operation could not be completed. The file doesn’t exist.")
        #else
        XCTAssertEqual(result.output, "The file “\(url.lastPathComponent)” couldn’t be opened because there is no such file.")
        #endif
    }

    func testEmptyFile() {
        let url = emptyFileURL()
        let result = outputFromExecutionWith(arguments: ["tax-slips", url.path])
        XCTAssertEqual(result.exitCode, 1)
        XCTAssert(result.errorOutput.starts(with: "Error: There was no configured tax slip found for year "))
    }

    func testNoSlip() {
        let url = temporaryFileURL()
        createFile(at: url, content: """
                                     2020-06-13 custom "tax-slip-settings" "slip-names" "t4"
                                     2020-06-13 custom "tax-slip-settings" "slip-currency" "t4" "CAD"
                                     """)
        assertSuccessfulExecutionResult(arguments: ["tax-slips", url.path], output: "")
    }

    func testSimpleSlip() {
        let url = temporaryFileURL()
        createFile(at: url, content: """
                                     2020-06-13 custom "tax-slip-settings" "slip-names" "t4"
                                     2020-06-13 custom "tax-slip-settings" "slip-currency" "t4" "CAD"
                                     2020-06-13 open Income:Work
                                       t4: "Box 1"
                                     2020-06-13 open Assets:Bank
                                     2020-06-13 * "" ""
                                       Income:Work -10.00 CAD
                                       Assets:Bank 10.00 CAD
                                     """)
        assertSuccessfulExecutionResult(arguments: ["tax-slips", url.path, "2020", "--format", "text"], output: """
                                        Tax Slip T4 - Tax year 2020

                                        Box 1
                                        10.00 CAD
                                        """)
    }

    func testSlipArgument() {
        let url = temporaryFileURL()
        createFile(at: url, content: """
                                     2020-06-13 custom "tax-slip-settings" "slip-names" "t5"
                                     2020-06-13 custom "tax-slip-settings" "slip-currency" "t4" "CAD"
                                     2020-06-13 custom "tax-slip-settings" "slip-currency" "t5" "CAD"
                                     2020-06-13 open Income:Work
                                       t4: "Box 1"
                                     2020-06-13 open Income:Bank
                                       t5: "Box 1"
                                     2020-06-13 open Assets:Bank
                                     2020-06-13 * "" ""
                                       Income:Work -10.00 CAD
                                       Assets:Bank 10.00 CAD
                                     2020-06-13 * "" ""
                                       Income:Bank -15.00 CAD
                                       Assets:Bank 15.00 CAD
                                     """)
        assertSuccessfulExecutionResult(arguments: ["tax-slips", url.path, "2020", "--format", "text", "--slip", "t5"], output: """
                                        Tax Slip T5 - Tax year 2020

                                        Box 1
                                        15.00 CAD
                                        """)
    }

    func testSlipSymbol() {
        let url = temporaryFileURL()
        createFile(at: url, content: """
                                     2020-06-13 custom "tax-slip-settings" "slip-names" "t4"
                                     2020-06-13 custom "tax-slip-settings" "slip-currency" "t4" "CAD"
                                     2020-06-13 open Income:Work
                                       t4: "Box 1"
                                       tax-symbol: "ABC"
                                       tax-description: "A-B-C-D"
                                     2020-06-13 open Assets:Bank
                                     2020-06-13 * "" ""
                                       Income:Work -10.00 CAD
                                       Assets:Bank 10.00 CAD
                                     """)
        assertSuccessfulExecutionResult(arguments: ["tax-slips", url.path, "2020"], output: """
                                        +------------------------------+
                                        | Tax Slip T4 - Tax year 2020  |
                                        +------------------------------+
                                        | Symbol | Name    | Box 1     |
                                        +--------+---------+-----------+
                                        | ABC    | A-B-C-D | 10.00 CAD |
                                        |        | Sum     | 10.00 CAD |
                                        +--------+---------+-----------+
                                        """)
    }

}

#endif // os(macOS)

@testable import SwiftBeanCountCLILibrary
import XCTest

class CheckTests: XCTestCase {

    func testFileDoesNotExist() {
        let url = temporaryFileURL()
        let result = outputFromExecutionWith(arguments: ["check", url.path])
        XCTAssertEqual(result.exitCode, 1)
        XCTAssert(result.errorOutput.isEmpty)
        #if os(Linux)
        XCTAssertEqual(result.output, "The operation could not be completed. No such file or directory")
        #else
        XCTAssertEqual(result.output, "The file “\(url.lastPathComponent)” couldn’t be opened because there is no such file.")
        #endif
    }

    func testEmptyFile() {
        let url = emptyFileURL()
        assertSuccessfulExecutionResult(arguments: ["check", url.path], output: "No errors found.")
    }

    func testSuccessful() {
        let url = temporaryFileURL()
        createFile(at: url, content: """
                                     2020-06-13 commodity CAD
                                     2020-06-13 open Assets:CAD
                                     2020-06-13 open Income:Job
                                     2020-06-13 * "" ""
                                       Assets:CAD 10.00 CAD
                                       Income:Job -10.00 CAD
                                     """)
        assertSuccessfulExecutionResult(arguments: ["check", url.path], output: "No errors found.")
    }

    func testError() {
        let url = temporaryFileURL()
        createFile(at: url, content: "2020-06-13 * \"\" \"\"\n  Assets:CAD 10.00 CAD\n  Income:Job -15.00 CAD")
        let result = outputFromExecutionWith(arguments: ["check", url.path])
        XCTAssertEqual(result.exitCode, 65)
        XCTAssert(result.errorOutput.isEmpty)
        XCTAssertEqual(result.output, """
                                        Found 2 errors:

                                        2020-06-13 * "" ""
                                          Assets:CAD 10.00 CAD
                                          Income:Job -15.00 CAD is not balanced - -5 CAD too much (0.005 tolerance)
                                        Commodity CAD does not have an opening date
                                        """)
    }

    func testQuietSuccessful() {
        let url = temporaryFileURL()
        createFile(at: url, content: "\n")
        assertSuccessfulExecutionResult(arguments: ["check", url.path, "-q"], output: "")
        assertSuccessfulExecutionResult(arguments: ["check", url.path, "--quiet"], output: "")
    }

    func testQuietError() {
        let url = temporaryFileURL()
        createFile(at: url, content: "2020-06-13 * \"\" \"\"\n  Assets:CAD 10.00 CAD\n  Income:Job -15.00 CAD")
        var result = outputFromExecutionWith(arguments: ["check", url.path, "-q"])
        XCTAssertEqual(result.exitCode, 65)
        XCTAssert(result.errorOutput.isEmpty)
        XCTAssert(result.output.isEmpty)
        result = outputFromExecutionWith(arguments: ["check", url.path, "--quiet"])
        XCTAssertEqual(result.exitCode, 65)
        XCTAssert(result.errorOutput.isEmpty)
        XCTAssert(result.output.isEmpty)
    }

}

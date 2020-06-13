@testable import SwiftBeanCountCLILibrary
import XCTest

class CheckTests: XCTestCase {

    func testEmptyFile() {
        let url = temporaryFileURL()
        createFile(at: url, content: "\n")
        let (exitCode, output) = outputFromExecutionWith(arguments: ["check", url.path])
        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(output, "No errors found.")
    }

    func testSuccessful() {
        let url = temporaryFileURL()
        createFile(at: url, content: "2020-06-13 commodity CAD\n2020-06-13 open Assets:CAD\n2020-06-13 open Income:Job\n2020-06-13 * \"\" \"\"\n  Assets:CAD 10.00 CAD\n  Income:Job -10.00 CAD")
        let (exitCode, output) = outputFromExecutionWith(arguments: ["check", url.path])
        XCTAssertEqual(exitCode, 0)
        XCTAssertEqual(output, "No errors found.")
    }

    func testError() {
        let url = temporaryFileURL()
        createFile(at: url, content: "2020-06-13 * \"\" \"\"\n  Assets:CAD 10.00 CAD\n  Income:Job -15.00 CAD")
        let (exitCode, output) = outputFromExecutionWith(arguments: ["check", url.path])
        XCTAssertEqual(exitCode, 65)
        XCTAssertEqual(output, "Found 2 errors:\n\n2020-06-13 * \"\" \"\"\n  Assets:CAD 10.00 CAD\n  Income:Job -15.00 CAD is not balanced - -5 CAD too much (0.005 tolerance)\nCommodity CAD does not have an opening date")
    }

    func testQuietSuccessful() {
        let url = temporaryFileURL()
        createFile(at: url, content: "\n")
        var (exitCode, output) = outputFromExecutionWith(arguments: ["check", url.path, "-q"])
        XCTAssertEqual(exitCode, 0)
        XCTAssert(output.isEmpty)
        (exitCode, output) = outputFromExecutionWith(arguments: ["check", url.path, "--quiet"])
        XCTAssertEqual(exitCode, 0)
        XCTAssert(output.isEmpty)
    }

    func testQuietError() {
        let url = temporaryFileURL()
        createFile(at: url, content: "2020-06-13 * \"\" \"\"\n  Assets:CAD 10.00 CAD\n  Income:Job -15.00 CAD")
        var (exitCode, output) = outputFromExecutionWith(arguments: ["check", url.path, "-q"])
        XCTAssertEqual(exitCode, 65)
        XCTAssert(output.isEmpty)
        (exitCode, output) = outputFromExecutionWith(arguments: ["check", url.path, "--quiet"])
        XCTAssertEqual(exitCode, 65)
        XCTAssert(output.isEmpty)
    }

}

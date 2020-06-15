@testable import SwiftBeanCountCLILibrary
import XCTest

class AccountsTests: XCTestCase { // swiftlint:disable:this type_body_length

    func testInvalidArguments() {
        let url = emptyFileURL()
        let result = outputFromExecutionWith(arguments: ["accounts", url.path, "-c", "-f", "csv"])
        XCTAssertEqual(result.exitCode, 64)
        XCTAssertEqual(result.output, "")
        XCTAssert(result.errorOutput.hasPrefix("Error: Cannot print count in csv format. Please remove count flag or specify another format."))
    }

    func testFileDoesNotExist() {
        let url = temporaryFileURL()
        let result = outputFromExecutionWith(arguments: ["accounts", url.path])
        XCTAssertEqual(result.exitCode, 1)
        XCTAssert(result.errorOutput.isEmpty)
        #if os(Linux)
        XCTAssertEqual(result.output, "The operation could not be completed. No such file or directory")
        #else
        XCTAssertEqual(result.output, "The file “\(url.lastPathComponent)” couldn’t be opened because there is no such file.")
        #endif
    }

    func testTestTable() {
        let table = """
            +---------------------------------------+
            | Accounts                              |
            +---------------------------------------+
            | Name        | Opening    | Closing    |
            +-------------+------------+------------+
            | Assets:CAD  | 2020-06-11 | 2020-06-13 |
            | Assets:USD  | 2020-05-11 | 2020-05-13 |
            | Income:Job  | 2020-06-13 |            |
            | Income:Job2 | 2020-05-13 |            |
            | Income:Job3 | 2020-05-15 |            |
            | Income:Test | 2020-05-16 |            |
            +-------------+------------+------------+
            """
        let url = basicLedgerURL()
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path], output: table)
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "table", "--open", "--closed", "--dates", "--no-activity"], output: table)
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "table", "--no-postings"], output: table)
    }

    func testCSV() {
        let csv = """
            "Name", "Opening", "Closing"
            "Assets:CAD", "2020-06-11", "2020-06-13"
            "Assets:USD", "2020-05-11", "2020-05-13"
            "Income:Job", "2020-06-13", ""
            "Income:Job2", "2020-05-13", ""
            "Income:Job3", "2020-05-15", ""
            "Income:Test", "2020-05-16", ""
            """
        let url = basicLedgerURL()
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--open", "--closed", "--dates"], output: csv)
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "csv", "--no-postings"], output: csv)
    }

    func testText() {
        let text = """
            Accounts

            Name         Opening     Closing
            Assets:CAD   2020-06-11  2020-06-13
            Assets:USD   2020-05-11  2020-05-13
            Income:Job   2020-06-13
            Income:Job2  2020-05-13
            Income:Job3  2020-05-15
            Income:Test  2020-05-16
            """
        let url = basicLedgerURL()
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "text", "--open", "--closed", "--dates", "--no-activity"], output: text)
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "text", "--no-postings"], output: text)
    }

    func testEmptyFileCSV() {
        let csv = #""Name", "Opening", "Closing""#
        let url = emptyFileURL()
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--open", "--closed", "--dates"], output: csv)
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "csv", "--no-activity"], output: csv)
    }

    func testNoDates() {
        let csv = """
            "Name"
            "Assets:CAD"
            "Assets:USD"
            "Income:Job"
            "Income:Job2"
            "Income:Job3"
            "Income:Test"
            """
        let url = basicLedgerURL()
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--open", "--closed", "--no-dates"], output: csv)
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "csv", "--no-dates"], output: csv)
    }

    func testNoOpen() {
        let csv = """
            "Name", "Opening", "Closing"
            "Assets:CAD", "2020-06-11", "2020-06-13"
            "Assets:USD", "2020-05-11", "2020-05-13"
            """
        let url = basicLedgerURL()
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--no-open", "--closed", "--dates"], output: csv)
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "csv", "--no-open"], output: csv)
    }

    func testNoClosed() {
        let csv = """
            "Name", "Opening"
            "Income:Job", "2020-06-13"
            "Income:Job2", "2020-05-13"
            "Income:Job3", "2020-05-15"
            "Income:Test", "2020-05-16"
            """
        let url = basicLedgerURL()
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--open", "--no-closed", "--dates"], output: csv)
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "csv", "--no-closed"], output: csv)
    }

    func testNoOpenNoClosed() {
        let csv = """
            "Name", "Opening"
            """
        let url = basicLedgerURL()
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--no-open", "--no-closed", "--dates"], output: csv)
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "csv", "--no-closed", "--no-open"], output: csv)
    }

    func testFilter() {
        let csv = """
            "Name", "Opening", "Closing"
            "Income:Job", "2020-06-13", ""
            "Income:Job2", "2020-05-13", ""
            "Income:Job3", "2020-05-15", ""
            """
        let url = basicLedgerURL()
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--open", "--closed", "--dates", "Job"], output: csv)
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "Job", "--format", "csv", "--no-postings"], output: csv)
    }

    func testFilterNoResult() {
        let csv = """
            "Name", "Opening", "Closing"
            """
        let url = basicLedgerURL()
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--open", "--closed", "--dates", "Job12"], output: csv)
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "Job12", "--format", "csv", "--no-postings"], output: csv)
    }

    func testPostings() {
        let csv = """
            "Name", "# Postings", "Opening", "Closing"
            "Assets:CAD", "2", "2020-06-11", "2020-06-13"
            "Assets:USD", "0", "2020-05-11", "2020-05-13"
            "Income:Job", "1", "2020-06-13", ""
            "Income:Job2", "1", "2020-05-13", ""
            "Income:Job3", "0", "2020-05-15", ""
            "Income:Test", "0", "2020-05-16", ""
            """
        let url = basicLedgerURL()
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--open", "--closed", "--dates", "--postings"], output: csv)
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "csv", "--postings", "--no-activity"], output: csv)
    }

    func testActivity() {
        let csv = """
            "Name", "# Postings", "Last Activity", "Opening", "Closing"
            "Assets:CAD", "2", "2020-06-13", "2020-06-11", "2020-06-13"
            "Assets:USD", "0", "2020-05-13", "2020-05-11", "2020-05-13"
            "Income:Job", "1", "2020-06-13", "2020-06-13", ""
            "Income:Job2", "1", "2020-06-13", "2020-05-13", ""
            "Income:Job3", "0", "2020-05-15", "2020-05-15", ""
            "Income:Test", "0", "2020-07-13", "2020-05-16", ""
            """
        let url = basicLedgerURL()
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--open", "--closed", "--dates", "--postings", "--activity"], output: csv)
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "csv", "--postings", "--activity"], output: csv)
    }

    func testTestTableCount() {
        let table = """
            +--------------------------------------+
            | Accounts                             |
            +--------------------------------------+
            | Name       | Opening    | Closing    |
            +------------+------------+------------+
            | Assets:CAD | 2020-06-11 | 2020-06-13 |
            | Assets:USD | 2020-05-11 | 2020-05-13 |
            +------------+------------+------------+

            2 Accounts
            """
        let url = basicLedgerURL()
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--no-open", "--count"], output: table)
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "table", "--no-open", "--closed", "--dates", "--count"], output: table)
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "table", "--no-postings", "-c", "--no-open"], output: table)
    }

    func testTextCount() {
        let text = """
            Accounts

            Name         Opening     Closing
            Assets:CAD   2020-06-11  2020-06-13
            Assets:USD   2020-05-11  2020-05-13
            Income:Job   2020-06-13
            Income:Job2  2020-05-13
            Income:Job3  2020-05-15
            Income:Test  2020-05-16

            6 Accounts
            """
        let url = basicLedgerURL()
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "text", "--open", "--closed", "--dates", "-c"], output: text)
        assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "text", "--no-postings", "--count"], output: text)
    }

    private func basicLedgerURL() -> URL {
        let content = """
            2020-06-11 open Assets:CAD
            2020-06-13 close Assets:CAD
            2020-06-13 open Income:Job
            2020-05-11 open Assets:USD
            2020-05-13 close Assets:USD
            2020-05-13 open Income:Job2
            2020-05-15 open Income:Job3
            2020-05-16 open Income:Test
            2020-06-13 * "" ""
              Assets:CAD 10.00 CAD
              Income:Job -10.00 CAD
            2020-06-13 * "" ""
              Assets:CAD 20.00 CAD
              Income:Job2 -20.00 CAD
            2020-07-13 balance Income:Test 0.00 CAD
            """
        let url = temporaryFileURL()
        createFile(at: url, content: content)
        return url
    }

}

import Foundation
@testable import SwiftBeanCountCLI
import Testing

#if os(macOS)

@Suite
class AccountsTests {

    private let basicLedgerURL: URL
    private let cleanup: () -> Void

    init() {
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
        (basicLedgerURL, cleanup) = TestUtils.temporaryFileURL()
        TestUtils.createFile(at: basicLedgerURL, content: content)
    }

    @Test
    func invalidArguments() {
        let (url, cleanup) = TestUtils.temporaryFileURL()
        TestUtils.createFile(at: url, content: "\n")
        defer { cleanup() }
        let result = TestUtils.outputFromExecutionWith(arguments: ["accounts", url.path, "-c", "-f", "csv"])
        #expect(result.exitCode == 64)
        #expect(result.output.isEmpty)
        #expect(result.errorOutput.hasPrefix("Error: Cannot print count in csv format. Please remove count flag or specify another format."))
    }

    @Test
    func fileDoesNotExist() {
        let (url, cleanup) = TestUtils.temporaryFileURL()
        defer { cleanup() }
        let result = TestUtils.outputFromExecutionWith(arguments: ["accounts", url.path])
        #expect(result.exitCode == 1)
        #expect(result.errorOutput.isEmpty)
        #if os(Linux)
        #expect(result.output == "The operation could not be completed. The file doesn’t exist.")
        #else
        #expect(result.output == "The file “\(url.lastPathComponent)” couldn’t be opened because there is no such file.")
        #endif
    }

    @Test
    func testTable() {
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
        let url = basicLedgerURL
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path], output: table)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "table", "--open", "--closed", "--dates", "--no-activity"], output: table)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "table", "--no-postings"], output: table)
    }

    @Test
    func csv() {
        let csv = """
            "Name", "Opening", "Closing"
            "Assets:CAD", "2020-06-11", "2020-06-13"
            "Assets:USD", "2020-05-11", "2020-05-13"
            "Income:Job", "2020-06-13", ""
            "Income:Job2", "2020-05-13", ""
            "Income:Job3", "2020-05-15", ""
            "Income:Test", "2020-05-16", ""
            """
        let url = basicLedgerURL
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--open", "--closed", "--dates"], output: csv)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "csv", "--no-postings"], output: csv)
    }

    @Test
    func text() {
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
        let url = basicLedgerURL
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "text", "--open", "--closed", "--dates", "--no-activity"], output: text)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "text", "--no-postings"], output: text)
    }

    @Test
    func emptyFileCSV() {
        let csv = #""Name", "Opening", "Closing""#
        let (url, cleanup) = TestUtils.temporaryFileURL()
        TestUtils.createFile(at: url, content: "\n")
        defer { cleanup() }
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--open", "--closed", "--dates"], output: csv)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "csv", "--no-activity"], output: csv)
    }

    @Test
    func noDates() {
        let csv = """
            "Name"
            "Assets:CAD"
            "Assets:USD"
            "Income:Job"
            "Income:Job2"
            "Income:Job3"
            "Income:Test"
            """
        let url = basicLedgerURL
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--open", "--closed", "--no-dates"], output: csv)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "csv", "--no-dates"], output: csv)
    }

    @Test
    func noOpen() {
        let csv = """
            "Name", "Opening", "Closing"
            "Assets:CAD", "2020-06-11", "2020-06-13"
            "Assets:USD", "2020-05-11", "2020-05-13"
            """
        let url = basicLedgerURL
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--no-open", "--closed", "--dates"], output: csv)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "csv", "--no-open"], output: csv)
    }

    @Test
    func noClosed() {
        let csv = """
            "Name", "Opening"
            "Income:Job", "2020-06-13"
            "Income:Job2", "2020-05-13"
            "Income:Job3", "2020-05-15"
            "Income:Test", "2020-05-16"
            """
        let url = basicLedgerURL
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--open", "--no-closed", "--dates"], output: csv)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "csv", "--no-closed"], output: csv)
    }

    @Test
    func noOpenNoClosed() {
        let csv = """
            "Name", "Opening"
            """
        let url = basicLedgerURL
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--no-open", "--no-closed", "--dates"], output: csv)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "csv", "--no-closed", "--no-open"], output: csv)
    }

    @Test
    func filter() {
        let csv = """
            "Name", "Opening", "Closing"
            "Income:Job", "2020-06-13", ""
            "Income:Job2", "2020-05-13", ""
            "Income:Job3", "2020-05-15", ""
            """
        let url = basicLedgerURL
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--open", "--closed", "--dates", "Job"], output: csv)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "Job", "--format", "csv", "--no-postings"], output: csv)
    }

    @Test
    func filterNoResult() {
        let csv = """
            "Name", "Opening", "Closing"
            """
        let url = basicLedgerURL
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--open", "--closed", "--dates", "Job12"], output: csv)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "Job12", "--format", "csv", "--no-postings"], output: csv)
    }

    @Test
    func postings() {
        let csv = """
            "Name", "# Postings", "Opening", "Closing"
            "Assets:CAD", "2", "2020-06-11", "2020-06-13"
            "Assets:USD", "0", "2020-05-11", "2020-05-13"
            "Income:Job", "1", "2020-06-13", ""
            "Income:Job2", "1", "2020-05-13", ""
            "Income:Job3", "0", "2020-05-15", ""
            "Income:Test", "0", "2020-05-16", ""
            """
        let url = basicLedgerURL
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--open", "--closed", "--dates", "--postings"], output: csv)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "csv", "--postings", "--no-activity"], output: csv)
    }

    @Test
    func activity() {
        let csv = """
            "Name", "# Postings", "Last Activity", "Opening", "Closing"
            "Assets:CAD", "2", "2020-06-13", "2020-06-11", "2020-06-13"
            "Assets:USD", "0", "2020-05-13", "2020-05-11", "2020-05-13"
            "Income:Job", "1", "2020-06-13", "2020-06-13", ""
            "Income:Job2", "1", "2020-06-13", "2020-05-13", ""
            "Income:Job3", "0", "2020-05-15", "2020-05-15", ""
            "Income:Test", "0", "2020-07-13", "2020-05-16", ""
            """
        let url = basicLedgerURL
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "csv", "--open", "--closed", "--dates", "--postings", "--activity"], output: csv)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "csv", "--postings", "--activity"], output: csv)
    }

    @Test
    func testTableCount() {
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
        let url = basicLedgerURL
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--no-open", "--count"], output: table)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "table", "--no-open", "--closed", "--dates", "--count"], output: table)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "table", "--no-postings", "-c", "--no-open"], output: table)
    }

    @Test
    func textCount() {
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
        let url = basicLedgerURL
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "-f", "text", "--open", "--closed", "--dates", "-c"], output: text)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["accounts", url.path, "--format", "text", "--no-postings", "--count"], output: text)
    }

    deinit {
        cleanup()
    }

}

#endif // os(macOS)

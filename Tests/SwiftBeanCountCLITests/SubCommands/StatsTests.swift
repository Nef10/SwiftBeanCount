import Foundation
@testable import SwiftBeanCountCLI
import Testing

#if os(macOS)

@Suite
class StatsTests {

    private let basicLedgerURL: URL
    private let cleanup: () -> Void

    init() {
        let content = """
            2020-06-13 commodity CAD
            2020-06-13 commodity CHF
            2020-06-13 commodity USD
            2020-06-11 open Assets:CAD
            2020-06-16 close Assets:CAD
            2020-06-13 open Income:Job
            2020-06-13 * "" "" #tag #tag2 #tag3 #tag4 #tag5 #tag6
              Assets:CAD 10.00 CAD
              Income:Job -10.00 CAD
            2020-06-12 balance  Assets:CAD 0.00 CAD
            2020-06-14 balance  Assets:CAD 10.00 CAD
            option "title" "Title"
            option "render_commas" "True"
            option "operating_currency" "EUR"
            option "operating_currency" "CAD"
            plugin "beancount.plugins.leafonly"
            plugin "beancount.plugins.coherent_cost"
            plugin "beancount.plugins.sellgains"
            plugin "beancount.plugins.implicit_prices"
            plugin "beancount.plugins.nounused"
            2020-06-13 custom "fava-option" "journal-show" "transaction balance note document custom budget open close"
            2020-06-13 custom "fava-option" "uptodate-indicator-grey-lookback-days" "32"
            2020-06-13 event "location" "A"
            2020-06-14 event "location" "B"
            2020-06-15 event "location" "A"
            """
        (basicLedgerURL, cleanup) = TestUtils.temporaryFileURL()
        TestUtils.createFile(at: basicLedgerURL, content: content)
    }

    @Test
    func fileDoesNotExist() {
        let (url, cleanup) = TestUtils.temporaryFileURL()
        defer { cleanup() }
        let result = TestUtils.outputFromExecutionWith(arguments: ["stats", url.path])
        #expect(result.exitCode == 1)
        #expect(result.errorOutput.isEmpty)
        #if os(Linux)
        #expect(result.output == "The operation could not be completed. The file doesn’t exist.")
        #else
        #expect(result.output == "The file “\(url.lastPathComponent)” couldn’t be opened because there is no such file.")
        #endif
    }

    @Test
    func emptyFileTable() {
        let table = """
            +---------------------------+
            | Statistics                |
            +---------------------------+
            | Type             | Number |
            +------------------+--------+
            | Transactions     | 0      |
            | Accounts         | 0      |
            | Account openings | 0      |
            | Account closings | 0      |
            | Balances         | 0      |
            | Prices           | 0      |
            | Commodities      | 0      |
            | Tags             | 0      |
            | Events           | 0      |
            | Customs          | 0      |
            | Options          | 0      |
            | Plugins          | 0      |
            +------------------+--------+
            """
        let (url, cleanup) = TestUtils.temporaryFileURL()
        TestUtils.createFile(at: url, content: "\n")
        defer { cleanup() }
        TestUtils.assertSuccessfulExecutionResult(arguments: ["stats", url.path], outputPrefix: table)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["stats", url.path, "-f", "table"], outputPrefix: table)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["stats", url.path, "--format", "table"], outputPrefix: table)
    }

    @Test
    func emptyFileCSV() {
        let csv = """
            "Type", "Number"
            "Transactions", "0"
            "Accounts", "0"
            "Account openings", "0"
            "Account closings", "0"
            "Balances", "0"
            "Prices", "0"
            "Commodities", "0"
            "Tags", "0"
            "Events", "0"
            "Customs", "0"
            "Options", "0"
            "Plugins", "0"
            """
        let (url, cleanup) = TestUtils.temporaryFileURL()
        TestUtils.createFile(at: url, content: "\n")
        defer { cleanup() }
        TestUtils.assertSuccessfulExecutionResult(arguments: ["stats", url.path, "-f", "csv"], output: csv)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["stats", url.path, "--format", "csv"], output: csv)
    }

    @Test
    func emptyFileText() {
        let text = """
            Statistics

            Type              Number
            Transactions      0
            Accounts          0
            Account openings  0
            Account closings  0
            Balances          0
            Prices            0
            Commodities       0
            Tags              0
            Events            0
            Customs           0
            Options           0
            Plugins           0
            """
        let (url, cleanup) = TestUtils.temporaryFileURL()
        TestUtils.createFile(at: url, content: "\n")
        defer { cleanup() }
        TestUtils.assertSuccessfulExecutionResult(arguments: ["stats", url.path, "-f", "text"], outputPrefix: text)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["stats", url.path, "--format", "text"], outputPrefix: text)
    }

    @Test
    func testTable() {
        let table = """
            +---------------------------+
            | Statistics                |
            +---------------------------+
            | Type             | Number |
            +------------------+--------+
            | Transactions     | 1      |
            | Accounts         | 2      |
            | Account openings | 2      |
            | Account closings | 1      |
            | Balances         | 2      |
            | Prices           | 0      |
            | Commodities      | 3      |
            | Tags             | 6      |
            | Events           | 3      |
            | Customs          | 2      |
            | Options          | 4      |
            | Plugins          | 5      |
            +------------------+--------+
            """
        let url = basicLedgerURL
        TestUtils.assertSuccessfulExecutionResult(arguments: ["stats", url.path], outputPrefix: table)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["stats", url.path, "--format", "table"], outputPrefix: table)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["stats", url.path, "-f", "table"], outputPrefix: table)
    }

    @Test
    func csv() {
        let csv = """
            "Type", "Number"
            "Transactions", "1"
            "Accounts", "2"
            "Account openings", "2"
            "Account closings", "1"
            "Balances", "2"
            "Prices", "0"
            "Commodities", "3"
            "Tags", "6"
            "Events", "3"
            "Customs", "2"
            "Options", "4"
            "Plugins", "5"
            """
        let url = basicLedgerURL
        TestUtils.assertSuccessfulExecutionResult(arguments: ["stats", url.path, "--format", "csv"], output: csv)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["stats", url.path, "-f", "csv"], output: csv)
    }

    @Test
    func text() {
        let text = """
            Statistics

            Type              Number
            Transactions      1
            Accounts          2
            Account openings  2
            Account closings  1
            Balances          2
            Prices            0
            Commodities       3
            Tags              6
            Events            3
            Customs           2
            Options           4
            Plugins           5
            """
        let url = basicLedgerURL
        TestUtils.assertSuccessfulExecutionResult(arguments: ["stats", url.path, "--format", "text"], outputPrefix: text)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["stats", url.path, "-f", "text"], outputPrefix: text)
    }

    deinit {
        cleanup()
    }

}

#endif // os(macOS)

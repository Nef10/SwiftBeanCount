@testable import SwiftBeanCountCLILibrary
import XCTest

class StatsTests: XCTestCase {

    func testFileDoesNotExist() {
        let url = temporaryFileURL()
        let result = outputFromExecutionWith(arguments: ["stats", url.path])
        XCTAssertEqual(result.exitCode, 1)
        XCTAssert(result.errorOutput.isEmpty)
        #if os(Linux)
        XCTAssertEqual(result.output, "The operation could not be completed. No such file or directory")
        #else
        XCTAssertEqual(result.output, "The file “\(url.lastPathComponent)” couldn’t be opened because there is no such file.")
        #endif
    }

    func testEmptyFileTable() {
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
        let url = emptyFileURL()
        assertSuccessfulExecutionResult(arguments: ["stats", url.path], outputPrefix: table)
        assertSuccessfulExecutionResult(arguments: ["stats", url.path, "-f", "table"], outputPrefix: table)
        assertSuccessfulExecutionResult(arguments: ["stats", url.path, "--format", "table"], outputPrefix: table)
    }

    func testEmptyFileCSV() {
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
        let url = emptyFileURL()
        assertSuccessfulExecutionResult(arguments: ["stats", url.path, "-f", "csv"], output: csv)
        assertSuccessfulExecutionResult(arguments: ["stats", url.path, "--format", "csv"], output: csv)
    }

    func testEmptyFileText() {
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
        let url = emptyFileURL()
        assertSuccessfulExecutionResult(arguments: ["stats", url.path, "-f", "text"], outputPrefix: text)
        assertSuccessfulExecutionResult(arguments: ["stats", url.path, "--format", "text"], outputPrefix: text)
    }

    func testTestTable() {
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
        let url = basicLedgerURL()
        assertSuccessfulExecutionResult(arguments: ["stats", url.path], outputPrefix: table)
        assertSuccessfulExecutionResult(arguments: ["stats", url.path, "--format", "table"], outputPrefix: table)
        assertSuccessfulExecutionResult(arguments: ["stats", url.path, "-f", "table"], outputPrefix: table)
    }

    func testCSV() {
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
        let url = basicLedgerURL()
        assertSuccessfulExecutionResult(arguments: ["stats", url.path, "--format", "csv"], output: csv)
        assertSuccessfulExecutionResult(arguments: ["stats", url.path, "-f", "csv"], output: csv)
    }

    func testText() {
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
        let url = basicLedgerURL()
        assertSuccessfulExecutionResult(arguments: ["stats", url.path, "--format", "text"], outputPrefix: text)
        assertSuccessfulExecutionResult(arguments: ["stats", url.path, "-f", "text"], outputPrefix: text)
    }

    private func basicLedgerURL() -> URL {
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
        let url = temporaryFileURL()
        createFile(at: url, content: content)
        return url
    }

}

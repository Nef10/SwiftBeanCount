#if os(macOS)

@testable import SwiftBeanCountCLI
import XCTest

final class TaxableSalesTests: XCTestCase {

    func testFileDoesNotExist() {
        let url = temporaryFileURL()
        let result = outputFromExecutionWith(arguments: ["taxable-sales", url.path])
        XCTAssertEqual(result.exitCode, 1)
        XCTAssert(result.errorOutput.isEmpty)
        #if os(Linux)
        XCTAssertEqual(result.output, "The operation could not be completed. The file doesn't exist.")
        #else
        XCTAssertEqual(result.output, "The file \"\(url.lastPathComponent)\" couldn't be opened because there is no such file.")
        #endif
    }

    func testEmptyFile() {
        let url = emptyFileURL()
        let result = outputFromExecutionWith(arguments: ["taxable-sales", url.path])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssert(result.errorOutput.isEmpty)
    }

    func testNoSales() {
        let url = temporaryFileURL()
        createFile(at: url, content: """
                                     2020-06-13 open Assets:Bank
                                     2020-06-13 open Income:Work
                                     2020-06-13 * "" ""
                                       Assets:Bank 10.00 CAD
                                       Income:Work -10.00 CAD
                                     """)
        assertSuccessfulExecutionResult(arguments: ["taxable-sales", url.path, "2020", "--format", "text"], output: """
                                        Taxable Sales 2020

                                        Date  Symbol  Name  Quantity  Proceeds  Gain  Provider
                                        """)
    }

    func testSimpleSale() {
        let url = temporaryFileURL()
        createFile(at: url, content: """
                                     2022-04-15 open Assets:Broker:STOCK
                                       tax-sale: "Broker"
                                     2022-04-15 open Assets:Bank
                                     2022-04-15 open Income:Gain
                                     2022-04-15 commodity STOCK
                                       name: "Stock Name"
                                     2022-04-15 * "" ""
                                       Assets:Broker:STOCK -1.1 STOCK {7.00 CAD}
                                       Assets:Bank 7.70 CAD
                                       Income:Gain -2.20 CAD
                                     """)
        assertSuccessfulExecutionResult(arguments: ["taxable-sales", url.path, "2022", "--format", "text"], output: """
                                        Taxable Sales 2022

                                        Date        Symbol  Name        Quantity  Proceeds    Gain        Provider
                                        2022-04-15  STOCK   Stock Name  1.1       7.70 CAD    2.20 CAD    Broker
                                        """)
    }

    func testSaleCSV() {
        let url = temporaryFileURL()
        createFile(at: url, content: """
                                     2022-04-15 open Assets:Broker:STOCK
                                       tax-sale: "Broker"
                                     2022-04-15 open Assets:Bank
                                     2022-04-15 open Income:Gain
                                     2022-04-15 commodity STOCK
                                       name: "Stock Name"
                                     2022-04-15 * "" ""
                                       Assets:Broker:STOCK -1.1 STOCK {7.00 CAD}
                                       Assets:Bank 7.70 CAD
                                       Income:Gain -2.20 CAD
                                     """)
        assertSuccessfulExecutionResult(arguments: ["taxable-sales", url.path, "2022", "--format", "csv"], output: """
                                        "Date", "Symbol", "Name", "Quantity", "Proceeds", "Gain", "Provider"
                                        "2022-04-15", "STOCK", "Stock Name", "1.1", "7.70 CAD", "2.20 CAD", "Broker"
                                        """)
    }

    func testSaleTable() {
        let url = temporaryFileURL()
        createFile(at: url, content: """
                                     2022-04-15 open Assets:Broker:STOCK
                                       tax-sale: "Broker"
                                     2022-04-15 open Assets:Bank
                                     2022-04-15 open Income:Gain
                                     2022-04-15 commodity STOCK
                                       name: "Stock Name"
                                     2022-04-15 * "" ""
                                       Assets:Broker:STOCK -1.1 STOCK {7.00 CAD}
                                       Assets:Bank 7.70 CAD
                                       Income:Gain -2.20 CAD
                                     """)
        assertSuccessfulExecutionResult(arguments: ["taxable-sales", url.path, "2022"], output: """
                                        +-----------------------------+
                                        | Taxable Sales 2022          |
                                        +-----------------------------+
                                        | Date       | Symbol | Name  |
                                        +------------+--------+-------+
                                        | 2022-04-15 | STOCK  | Stock |
                                        +------------+--------+-------+

                                        | Quantity | Proceeds | Gain     | Provider |
                                        +----------+----------+----------+----------+
                                        | 1.1      | 7.70 CAD | 2.20 CAD | Broker   |
                                        +----------+----------+----------+----------+
                                        """)
    }

    func testGroupByProvider() {
        let url = groupByProviderLedgerURL()
        assertSuccessfulExecutionResult(arguments: ["taxable-sales", url.path, "2022", "--format", "text", "--group-by-provider"], output: """
                                        Taxable Sales 2022 - Broker1

                                        Date        Symbol   Name       Quantity  Proceeds    Gain
                                        2022-04-15  STOCK1   Stock One  1.0       15.00 CAD   5.00 CAD

                                        Taxable Sales 2022 - Broker2

                                        Date        Symbol   Name       Quantity  Proceeds    Gain
                                        2022-04-16  STOCK2   Stock Two  2.0       50.00 CAD   10.00 CAD
                                        """)
    }

    private func groupByProviderLedgerURL() -> URL {
        let url = temporaryFileURL()
        createFile(at: url, content: """
                                     2022-04-15 open Assets:Broker1:STOCK1
                                       tax-sale: "Broker1"
                                     2022-04-16 open Assets:Broker2:STOCK2
                                       tax-sale: "Broker2"
                                     2022-04-15 open Assets:Bank
                                     2022-04-15 open Income:Gain
                                     2022-04-15 commodity STOCK1
                                       name: "Stock One"
                                     2022-04-15 commodity STOCK2
                                       name: "Stock Two"
                                     2022-04-15 * "" ""
                                       Assets:Broker1:STOCK1 -1.0 STOCK1 {10.00 CAD}
                                       Assets:Bank 15.00 CAD
                                       Income:Gain -5.00 CAD
                                     2022-04-16 * "" ""
                                       Assets:Broker2:STOCK2 -2.0 STOCK2 {20.00 CAD}
                                       Assets:Bank 50.00 CAD
                                       Income:Gain -10.00 CAD
                                     """)
        return url
    }

    func testGroupByProviderInvalidWithCSV() {
        let url = emptyFileURL()
        let result = outputFromExecutionWith(arguments: ["taxable-sales", url.path, "--group-by-provider", "--format", "csv"])
        XCTAssertEqual(result.exitCode, 64)
        XCTAssertEqual(result.output, "")
        XCTAssert(result.errorOutput.hasPrefix("Error: Cannot group by provider in csv format. Please remove group-by-provider flag or specify another format."))
    }

    func testDefaultYear() {
        let url = temporaryFileURL()
        let lastYear = Calendar.current.component(.year, from: Date()) - 1
        createFile(at: url, content: """
                                     \(lastYear)-04-15 open Assets:Broker:STOCK
                                       tax-sale: "Broker"
                                     \(lastYear)-04-15 open Assets:Bank
                                     \(lastYear)-04-15 open Income:Gain
                                     \(lastYear)-04-15 * "" ""
                                       Assets:Broker:STOCK -1.0 STOCK {10.00 CAD}
                                       Assets:Bank 15.00 CAD
                                       Income:Gain -5.00 CAD
                                     """)
        let result = outputFromExecutionWith(arguments: ["taxable-sales", url.path, "--format", "csv"])
        XCTAssertEqual(result.exitCode, 0)
        XCTAssert(result.errorOutput.isEmpty)
        XCTAssert(result.output.hasPrefix("\"Date\", \"Symbol\", \"Name\", \"Quantity\", \"Proceeds\", \"Gain\", \"Provider\""))
        XCTAssert(result.output.contains("\"\(lastYear)-04-15\""))
    }

}

#endif // os(macOS)

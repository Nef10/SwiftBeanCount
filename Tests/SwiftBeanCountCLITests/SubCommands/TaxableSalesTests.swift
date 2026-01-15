#if os(macOS)

import Foundation
@testable import SwiftBeanCountCLI
import Testing

@Suite
struct TaxableSalesTests {

    @Test
    func fileDoesNotExist() {
        let (url, cleanup) = TestUtils.temporaryFileURL()
        defer { cleanup() }
        let result = TestUtils.outputFromExecutionWith(arguments: ["taxable-sales", url.path])
        #expect(result.exitCode == 1)
        #expect(result.errorOutput.isEmpty)
        #if os(Linux)
        #expect(result.output == "The operation could not be completed. The file doesn’t exist.")
        #else
        #expect(result.output == "The file “\(url.lastPathComponent)” couldn’t be opened because there is no such file.")
        #endif
    }

    @Test
    func emptyFile() {
        let (url, cleanup) = TestUtils.temporaryFileURL()
        TestUtils.createFile(at: url, content: "\n")
        defer { cleanup() }
        let result = TestUtils.outputFromExecutionWith(arguments: ["taxable-sales", url.path])
        #expect(result.exitCode == 0)
        #expect(result.errorOutput.isEmpty)
    }

    @Test
    func noSales() {
        let (url, cleanup) = TestUtils.temporaryFileURL()
        defer { cleanup() }
        TestUtils.createFile(at: url, content: """
                                     2020-06-13 open Assets:Bank
                                     2020-06-13 open Income:Work
                                     2020-06-13 * "" ""
                                       Assets:Bank 10.00 CAD
                                       Income:Work -10.00 CAD
                                     """)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["taxable-sales", url.path, "2020", "--format", "text"], output: """
                                        No Taxable Sales for 2020
                                        """)
    }

    @Test
    func simpleSale() {
        let (url, cleanup) = TestUtils.temporaryFileURL()
        defer { cleanup() }
        TestUtils.createFile(at: url, content: """
                                     2022-04-15 open Assets:Broker:STOCK
                                       tax-sale: "Broker"
                                     2022-04-15 open Assets:Bank
                                     2022-04-15 open Income:Gain
                                     2022-04-15 commodity STOCK
                                       name: "Stock Name"
                                     2022-04-15 * "" ""
                                       Assets:Broker:STOCK -1.1 STOCK {}
                                       Assets:Bank 7.70 CAD
                                       Income:Gain -2.20 CAD
                                     """)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["taxable-sales", url.path, "2022", "--format", "text"], output: """
                                        Taxable Sales 2022

                                        Date        Symbol  Name        Quantity  Proceeds  Gain      Provider
                                        2022-04-15  STOCK   Stock Name  1.1       7.70 CAD  2.20 CAD  Broker
                                        Sum                                       7.70 CAD  2.20 CAD
                                        """)
    }

    @Test
    func saleCSV() {
        let (url, cleanup) = TestUtils.temporaryFileURL()
        defer { cleanup() }
        TestUtils.createFile(at: url, content: """
                                     2022-04-15 open Assets:Broker:STOCK
                                       tax-sale: "Broker"
                                     2022-04-15 open Assets:Bank
                                     2022-04-15 open Income:Gain
                                     2022-04-15 commodity STOCK
                                       name: "Stock Name"
                                     2022-04-15 * "" ""
                                       Assets:Broker:STOCK -1.1 STOCK {}
                                       Assets:Bank 7.70 CAD
                                       Income:Gain -2.20 CAD
                                     """)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["taxable-sales", url.path, "2022", "--format", "csv"], output: """
                                        "Date", "Symbol", "Name", "Quantity", "Proceeds", "Gain", "Provider"
                                        "2022-04-15", "STOCK", "Stock Name", "1.1", "7.70 CAD", "2.20 CAD", "Broker"
                                        """)
    }

    @Test
    func saleTable() {
        let (url, cleanup) = TestUtils.temporaryFileURL()
        defer { cleanup() }
        TestUtils.createFile(at: url, content: """
                                     2022-04-15 open Assets:Broker:STOCK
                                       tax-sale: "Broker"
                                     2022-04-15 open Assets:Bank
                                     2022-04-15 open Income:Gain
                                     2022-04-15 commodity STOCK
                                       name: "Stock"
                                     2022-04-15 * "" ""
                                       Assets:Broker:STOCK -1.1 STOCK {}
                                       Assets:Bank 7.70 CAD
                                       Income:Gain -2.20 CAD
                                     """)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["taxable-sales", url.path, "2022"], output: """
                                        +-------------------------------------------------------------------------+
                                        | Taxable Sales 2022                                                      |
                                        +-------------------------------------------------------------------------+
                                        | Date       | Symbol | Name  | Quantity | Proceeds | Gain     | Provider |
                                        +------------+--------+-------+----------+----------+----------+----------+
                                        | 2022-04-15 | STOCK  | Stock | 1.1      | 7.70 CAD | 2.20 CAD | Broker   |
                                        | Sum        |        |       |          | 7.70 CAD | 2.20 CAD |          |
                                        +------------+--------+-------+----------+----------+----------+----------+
                                        """)
    }

    @Test
    func groupByProvider() {
        let (url, cleanup) = groupByProviderLedgerURL()
        defer { cleanup() }
        TestUtils.assertSuccessfulExecutionResult(arguments: ["taxable-sales", url.path, "2022", "--format", "text", "--group-by-provider"], output: """
                                        Taxable Sales 2022 - Broker1

                                        Date        Symbol  Name       Quantity  Proceeds   Gain
                                        2022-04-15  STOCK1  Stock One  1         15.00 CAD  5.00 CAD
                                        Sum                                      15.00 CAD  5.00 CAD

                                        Taxable Sales 2022 - Broker2

                                        Date        Symbol  Name       Quantity  Proceeds   Gain
                                        2022-04-16  STOCK2  Stock Two  2         50.00 CAD  10.00 CAD
                                        Sum                                      50.00 CAD  10.00 CAD
                                        """)
    }

    private func groupByProviderLedgerURL() -> (URL, () -> Void) {
        let (url, cleanup) = TestUtils.temporaryFileURL()
        TestUtils.createFile(at: url, content: """
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
                                       Assets:Broker1:STOCK1 -1.0 STOCK1 {}
                                       Assets:Bank 15.00 CAD
                                       Income:Gain -5.00 CAD
                                     2022-04-16 * "" ""
                                       Assets:Broker2:STOCK2 -2.0 STOCK2 {}
                                       Assets:Bank 50.00 CAD
                                       Income:Gain -10.00 CAD
                                     """)
        return (url, cleanup)
    }

    @Test
    func groupByProviderInvalidWithCSV() {
        let (url, cleanup) = TestUtils.temporaryFileURL()
        TestUtils.createFile(at: url, content: "\n")
        defer { cleanup() }
        let result = TestUtils.outputFromExecutionWith(arguments: ["taxable-sales", url.path, "--group-by-provider", "--format", "csv"])
        #expect(result.exitCode == 64)
        #expect(result.output.isEmpty)
        #expect(result.errorOutput.hasPrefix("Error: Cannot group by provider in csv format. Please remove group-by-provider flag or specify another format."))
    }

    @Test
    func defaultYear() {
        let (url, cleanup) = TestUtils.temporaryFileURL()
        defer { cleanup() }
        let lastYear = Calendar.current.component(.year, from: Date()) - 1
        TestUtils.createFile(at: url, content: """
                                     \(lastYear)-04-15 open Assets:Broker:STOCK
                                       tax-sale: "Broker"
                                     \(lastYear)-04-15 open Assets:Bank
                                     \(lastYear)-04-15 open Income:Gain
                                     \(lastYear)-04-15 * "" ""
                                       Assets:Broker:STOCK -1.0 STOCK {}
                                       Assets:Bank 15.00 CAD
                                       Income:Gain -5.00 CAD
                                     """)
        let result = TestUtils.outputFromExecutionWith(arguments: ["taxable-sales", url.path, "--format", "csv"])
        #expect(result.exitCode == 0)
        #expect(result.errorOutput.isEmpty)
        #expect(result.output.hasPrefix("\"Date\", \"Symbol\", \"Name\", \"Quantity\", \"Proceeds\", \"Gain\", \"Provider\""))
        #expect(result.output.contains("\"\(lastYear)-04-15\""))
    }

}

#endif // os(macOS)

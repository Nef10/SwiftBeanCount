import ArgumentParser
import Foundation
import SwiftBeanCountModel
import SwiftBeanCountTax

struct TaxableSales: FormattableLedgerCommand {

    static var configuration = CommandConfiguration(abstract: "List taxable sales for a tax year")

    @OptionGroup()
    var ledgerOptions: LedgerCommandOptions
    @Argument(help: "Tax year to list sales for.")
    var year = Calendar.current.component(.year, from: Date()) - 1
    @ArgumentParser.Flag(name: .long, help: "Group sales by provider (not available in CSV format).")
    var groupByProvider = false
    @OptionGroup()
    var formatOptions: FormattableCommandOptions
    @OptionGroup()
    var colorOptions: ColorizedCommandOptions

    func validate() throws(ValidationError) {
        if formatOptions.format == .csv && groupByProvider {
            throw ValidationError("Cannot group by provider in csv format. Please remove group-by-provider flag or specify another format.")
        }
    }

    func getResult(from ledger: Ledger, parsingDuration _: Double) throws -> [FormattableResult] {
        let sales = TaxCalculator.getTaxableSales(from: ledger, for: year)
        
        if groupByProvider {
            // Group sales by provider
            let groupedSales = Dictionary(grouping: sales) { $0.provider }
            return groupedSales.keys.sorted().map { provider in
                let providerSales = groupedSales[provider]!.sorted { $0.date < $1.date }
                let values = providerSales.map { sale in
                    [
                        dateFormatter.string(from: sale.date),
                        sale.symbol,
                        sale.name ?? "",
                        String(describing: sale.quantity),
                        sale.proceeds.fullString,
                        sale.gain.fullString
                    ]
                }
                return FormattableResult(
                    title: "Taxable Sales \(year) - \(provider)",
                    columns: ["Date", "Symbol", "Name", "Quantity", "Proceeds", "Gain"],
                    values: values
                )
            }
        } else {
            // Flat list of all sales
            let sortedSales = sales.sorted { $0.date < $1.date }
            let values = sortedSales.map { sale in
                [
                    dateFormatter.string(from: sale.date),
                    sale.symbol,
                    sale.name ?? "",
                    String(describing: sale.quantity),
                    sale.proceeds.fullString,
                    sale.gain.fullString,
                    sale.provider
                ]
            }
            return [FormattableResult(
                title: "Taxable Sales \(year)",
                columns: ["Date", "Symbol", "Name", "Quantity", "Proceeds", "Gain", "Provider"],
                values: values
            )]
        }
    }

    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }

}

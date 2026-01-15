import ArgumentParser
import Foundation
import SwiftBeanCountModel
import SwiftBeanCountTax

struct TaxableSales: FormattableLedgerCommand {

    static var configuration = CommandConfiguration(abstract: "List taxable sales for a tax year")

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

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
        guard !sales.isEmpty else {
            return [
                FormattableResult(
                    title: "No Taxable Sales for \(year)",
                    columns: [""],
                    values: [[]]
                )
            ]
        }

        if groupByProvider {
            return groupedResults(from: sales)
        }
        return flatResults(from: sales)
    }

    private func groupedResults(from sales: [Sale]) -> [FormattableResult] {
        let groupedSales = Dictionary(grouping: sales) { $0.provider }
        return groupedSales.keys.sorted().map { provider in
            let providerSales = groupedSales[provider]!.sorted { $0.date < $1.date }
            var values = providerSales.map { sale in
                [
                    Self.dateFormatter.string(from: sale.date),
                    sale.symbol,
                    sale.name ?? "",
                    String(describing: sale.quantity),
                    sale.proceeds.fullString,
                    sale.gain.fullString
                ]
            }

            // Add sum row (skip for CSV format)
            if formatOptions.format != .csv {
                values.append(sumRow(from: providerSales, addEmptyColumnAtThenEnd: false))
            }

            return FormattableResult(
                title: "Taxable Sales \(year) - \(provider)",
                columns: ["Date", "Symbol", "Name", "Quantity", "Proceeds", "Gain"],
                values: values,
                lastRowIsFooter: formatOptions.format != .csv
            )
        }
    }

    private func flatResults(from sales: [Sale]) -> [FormattableResult] {
        let sortedSales = sales.sorted { $0.date < $1.date }
        var values = sortedSales.map { sale in
            [
                Self.dateFormatter.string(from: sale.date),
                sale.symbol,
                sale.name ?? "",
                String(describing: sale.quantity),
                sale.proceeds.fullString,
                sale.gain.fullString,
                sale.provider
            ]
        }

        // Add sum row (skip for CSV format)
        if formatOptions.format != .csv {
            values.append(sumRow(from: sortedSales, addEmptyColumnAtThenEnd: true))
        }

        return [
            FormattableResult(
                title: "Taxable Sales \(year)",
                columns: ["Date", "Symbol", "Name", "Quantity", "Proceeds", "Gain", "Provider"],
                values: values,
                lastRowIsFooter: formatOptions.format != .csv
            )
        ]
    }

    private func sumRow(from sales: [Sale], addEmptyColumnAtThenEnd: Bool) -> [String] {
        let totalProceeds = sales.reduce(MultiCurrencyAmount()) { $0 + $1.proceeds }
        let totalGain = sales.reduce(MultiCurrencyAmount()) { $0 + $1.gain }

        var row = ["Sum"]
        // Add empty columns before proceeds (Date, Symbol, Name, Quantity)
        row.append(contentsOf: Array(repeating: "", count: 3))
        // Add totals
        row.append(totalProceeds.fullString)
        row.append(totalGain.fullString)
        // Add empty columns after gain if needed (Provider)
        if addEmptyColumnAtThenEnd {
            row.append("")
        }
        return row
    }

}

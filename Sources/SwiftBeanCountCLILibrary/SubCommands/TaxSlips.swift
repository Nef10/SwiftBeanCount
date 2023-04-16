import ArgumentParser
import Foundation
import SwiftBeanCountModel
import SwiftBeanCountTax

struct TaxSlips: FormattableLedgerCommand {

    static var configuration = CommandConfiguration(abstract: "Generate expected tax slips")

    @OptionGroup()
    var ledgerOptions: LedgerCommandOptions
    @Argument(help: "Tax year to generate slips for.")
    var year = Calendar.current.component(.year, from: Date()) - 1
    @ArgumentParser.Option(help: "Tax slip to generate - if not specified, all will be generated")
    var slip: String?
    @OptionGroup()
    var formatOptions: FormattableCommandOptions
    @OptionGroup()
    var colorOptions: ColorizedCommandOptions

    func getResult(from ledger: Ledger, parsingDuration: Double) throws -> [FormattableResult] {
        try TaxCalculator.generateTaxSlips(from: ledger, for: year).filter { slip != nil ? $0.name.lowercased() == slip!.lowercased() : true }.map { slip in
            var values: [[String]] = slip.rows.map {
                slip.symbols.isEmpty ? $0.values.map { $0.displayValue } : [$0.symbol!, $0.name!] + $0.values.map { $0.displayValue }
            }
            if !slip.symbols.isEmpty {
                values.append([" ", "Sum"] + slip.sumRow.values.map { $0.displayValue })
            }
            let columns = slip.symbols.isEmpty ? slip.boxes : ["Symbol", "Name"] + slip.boxes
            return FormattableResult(title: slip.header, columns: columns, values: values, lastRowIsFooter: !slip.symbols.isEmpty)
        }
    }

}

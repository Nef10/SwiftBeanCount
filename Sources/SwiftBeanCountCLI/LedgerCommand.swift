import ArgumentParser
import Foundation
import SwiftBeanCountModel
import SwiftBeanCountParser
import SwiftyTextTable

enum Format: String, ExpressibleByArgument, CaseIterable {
    case text
    case table
    case csv
}

struct LedgerOption: ParsableArguments {
    @Argument(help: "The file to parse.") var file: String
}

protocol FormattableLedgerCommand: LedgerCommand {
    var format: Format { get }
}

protocol LedgerCommand: ParsableCommand {
    var options: LedgerOption { get }
}

extension LedgerCommand {

    func parseLedger() throws -> Ledger {
        let ledger: Ledger
        do {
            ledger = try Parser.parse(contentOf: URL(fileURLWithPath: options.file))
        } catch {
            print(error.localizedDescription)
            throw ExitCode.failure
        }
        return ledger
    }

}

extension FormattableLedgerCommand {

    func printFormatted(title: String, columns: [String], values: [[String]]) {
        var result: String
        switch format {
        case .text, .table:
            var table = TextTable(columns: columns.map { TextTableColumn(header: $0) }, header: title)
            table.addRows(values: values)
            if format == .text {
                table.columnFence = ""
                table.rowFence = ""
                table.cornerFence = ""
                result = table.render().split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
            } else {
                result = table.render()
            }
        case .csv:
            result = columns.map { "\"\($0)\"" }.joined(separator: ", ") + "\n"
            result += values.map { $0.map { "\"\($0)\"" }.joined(separator: ", ") }.joined(separator: "\n")
        }
        print(result)
    }

}

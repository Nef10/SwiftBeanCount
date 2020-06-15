import ArgumentParser
import Rainbow
import SwiftyTextTable

enum Format: String, ExpressibleByArgument, CaseIterable {
    case text
    case table
    case csv
}

protocol FormattableCommand: ParsableCommand {
    var format: Format { get }
}

extension FormattableCommand {

    static func supportedFormats() -> String {
        "Supported formats: \(Format.allCases.map { $0.rawValue }.joined(separator: ", "))"
    }

    func formatted(title: String, columns: [String], values: [[String]]) -> String {
        var result: String
        switch format {
        case .text:
            var table = TextTable(columns: columns.map { TextTableColumn(header: $0.bold) })
            table.addRows(values: values)
            table.columnFence = ""
            table.rowFence = ""
            table.cornerFence = ""
            result = title.bold.underline + "\n\n"
            result += table.render().split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
        case .table:
            var table = TextTable(columns: columns.map { TextTableColumn(header: $0) }, header: title.bold)
            table.addRows(values: values)
            result = table.render()
        case .csv:
            result = columns.map { "\"\($0)\"" }.joined(separator: ", ") + "\n"
            result += values.map { $0.map { "\"\($0)\"" }.joined(separator: ", ") }.joined(separator: "\n")
        }
        return result
    }

}

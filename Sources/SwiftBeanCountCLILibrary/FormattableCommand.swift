import ArgumentParser
import Rainbow
import SwiftyTextTable

enum Format: String, ExpressibleByArgument, CaseIterable {
    case text
    case table
    case csv
}

struct FormattableResult {
    let title: String
    let columns: [String]
    let values: [[String]]
    let footer: String?
}

protocol FormattableCommand: ColorizedCommand {

    var format: Format { get }

    func getResult() throws -> FormattableResult

}

extension FormattableCommand {

    static func supportedFormats() -> String {
        "Supported formats: \(Format.allCases.map { $0.rawValue }.joined(separator: ", "))"
    }

    func run() throws {
        adjustColorization()
        print(formatted(try getResult()))
    }

    func formatted(_ value: FormattableResult) -> String {
        var result: String
        switch format {
        case .text:
            var table = TextTable(columns: value.columns.map { TextTableColumn(header: $0.bold) })
            table.addRows(values: value.values)
            table.columnFence = ""
            table.rowFence = ""
            table.cornerFence = ""
            result = value.title.bold.underline + "\n\n"
            result += table.render().split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
        case .table:
            var table = TextTable(columns: value.columns.map { TextTableColumn(header: $0) }, header: value.title.bold)
            table.addRows(values: value.values)
            result = table.render()
        case .csv:
            result = value.columns.map { "\"\($0)\"" }.joined(separator: ", ") + "\n"
            result += value.values.map { $0.map { "\"\($0)\"" }.joined(separator: ", ") }.joined(separator: "\n")
        }
        if let footer = value.footer, !footer.isEmpty, format != .csv {
            result += "\n\n\(footer.lightBlack)"
        }
        return result
    }

}

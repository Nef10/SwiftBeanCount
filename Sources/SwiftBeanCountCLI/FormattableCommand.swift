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
    let lastRowIsFooter: Bool
    let footer: String?

    internal init(title: String, columns: [String], values: [[String]], lastRowIsFooter: Bool = false, footer: String? = nil) {
        self.title = title
        self.columns = columns
        self.values = values
        self.lastRowIsFooter = lastRowIsFooter
        self.footer = footer
    }
}

struct FormattableCommandOptions: ParsableArguments {
    @ArgumentParser.Option(name: [.short, .long], help: "Output format. Supported formats: \(Format.allCases.map(\.rawValue).joined(separator: ", "))")
    var format: Format = .table
}

protocol FormattableCommand: ColorizedCommand {

    var formatOptions: FormattableCommandOptions { get }

    func getResult() throws -> [FormattableResult]

}

extension FormattableCommand {

    func run() throws {
        adjustColorization()
        let results = try getResult()
        print(results.map { formatted($0) }.joined(separator: "\n\n"))
    }

    func formatted(_ value: FormattableResult) -> String {
        var result: String
        switch formatOptions.format {
        case .text:
            var table = TextTable(columns: value.columns.map { TextTableColumn(header: $0.bold) })
            table.addRows(values: value.values.dropLast())
            if !value.values.isEmpty {
                table.addRow(values: value.lastRowIsFooter ? value.values.last!.map(\.bold) : value.values.last!)
            }
            table.columnFence = ""
            table.rowFence = ""
            table.cornerFence = ""
            result = value.title.bold.underline + "\n\n"
            result += table.render().split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
        case .table:
            var table = TextTable(columns: value.columns.map { TextTableColumn(header: $0) }, header: value.title.bold)
            table.addRows(values: value.values.dropLast())
            if !value.values.isEmpty {
                table.addRow(values: value.lastRowIsFooter ? value.values.last!.map(\.bold) : value.values.last!)
            }
            result = table.render()
        case .csv:
            result = value.columns.map { "\"\($0)\"" }.joined(separator: ", ") + "\n"
            result += value.values.map { $0.map { "\"\($0)\"" }.joined(separator: ", ") }.joined(separator: "\n")
        }
        if let footer = value.footer, !footer.isEmpty, formatOptions.format != .csv {
            result += "\n\n\(footer.lightBlack)"
        }
        return result
    }

}

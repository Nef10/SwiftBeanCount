import ArgumentParser
import Rainbow
@testable import SwiftBeanCountCLILibrary
import XCTest

struct TestFormattableCommand: FormattableCommand {
        @ArgumentParser.Option() var format: Format
        @ArgumentParser.Flag(help: Self.noColorHelp()) var noColor: Bool = false

        func getResult() throws -> FormattableResult {
            FormattableResult(title: "A", columns: ["B", "C"], values: [["D E", "F G"], ["H", "I"]], footer: "J")
        }
}

class FormattableCommandTests: XCTestCase {

    private let basicResult = FormattableResult(title: "Title",
                                                columns: ["Column A", "B", "C"],
                                                values: [["1", "Value 2", "Value3"], ["Row 2", "Value 2", ""]],
                                                footer: "Footer")
    private let oneColumnOneRowResult = FormattableResult(title: "Title", columns: ["Column A"], values: [["1"]], footer: nil)
    private let zeroRowResult = FormattableResult(title: "Title", columns: ["Column A", "B"], values: [], footer: nil)

    func testSupportedFormats() {
        for format in Format.allCases {
            XCTAssertTrue(TestFormattableCommand.supportedFormats().contains(format.rawValue))
        }
    }

    func testCSVColor() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = true
        var subject = TestFormattableCommand()
        subject.format = .csv
        let result = subject.formatted(basicResult)
        XCTAssertEqual(result, """
            "Column A", "B", "C"
            "1", "Value 2", "Value3"
            "Row 2", "Value 2", ""
            """)
        Rainbow.enabled = originalValue
    }

    func testCSV() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = false
        var subject = TestFormattableCommand()
        subject.format = .csv
        let result = subject.formatted(basicResult)
        XCTAssertEqual(result, """
            "Column A", "B", "C"
            "1", "Value 2", "Value3"
            "Row 2", "Value 2", ""
            """)
        Rainbow.enabled = originalValue
    }

    func testTableColor() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = true
        var subject = TestFormattableCommand()
        subject.format = .table
        let result = subject.formatted(basicResult)
        XCTAssertEqual(result, """
            +-----------------------------+
            | \("Title".bold)                       |
            +-----------------------------+
            | Column A | B       | C      |
            +----------+---------+--------+
            | 1        | Value 2 | Value3 |
            | Row 2    | Value 2 |        |
            +----------+---------+--------+

            \("Footer".lightBlack)
            """)
        Rainbow.enabled = originalValue
    }

    func testTable() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = false
        var subject = TestFormattableCommand()
        subject.format = .table
        let result = subject.formatted(basicResult)
        XCTAssertEqual(result, """
            +-----------------------------+
            | Title                       |
            +-----------------------------+
            | Column A | B       | C      |
            +----------+---------+--------+
            | 1        | Value 2 | Value3 |
            | Row 2    | Value 2 |        |
            +----------+---------+--------+

            Footer
            """)
        Rainbow.enabled = originalValue
    }

    func testTextColor() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = true
        var subject = TestFormattableCommand()
        subject.format = .text
        let result = subject.formatted(basicResult)
        XCTAssertEqual(result, """
            \("Title".bold.underline)

            \("Column A".bold)  \("B".bold)        \("C".bold)
            1         Value 2  Value3
            Row 2     Value 2

            \("Footer".lightBlack)
            """)
        Rainbow.enabled = originalValue
    }

    func testText() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = false
        var subject = TestFormattableCommand()
        subject.format = .text
        let result = subject.formatted(basicResult)
        XCTAssertEqual(result, """
            Title

            Column A  B        C
            1         Value 2  Value3
            Row 2     Value 2

            Footer
            """)
        Rainbow.enabled = originalValue
    }

    func testOneColumnOneRow() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = false
        var subject = TestFormattableCommand()
        subject.format = .text
        var result = subject.formatted(oneColumnOneRowResult)
        XCTAssertEqual(result, """
            Title

            Column A
            1
            """)

        subject.format = .csv
        result = subject.formatted(oneColumnOneRowResult)
        XCTAssertEqual(result, """
            "Column A"
            "1"
            """)

        subject.format = .table
        result = subject.formatted(oneColumnOneRowResult)
        XCTAssertEqual(result, """
            +----------+
            | Title    |
            +----------+
            | Column A |
            +----------+
            | 1        |
            +----------+
            """)

        Rainbow.enabled = originalValue
    }

    func testZeroRows() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = false
        var subject = TestFormattableCommand()
        subject.format = .text
        var result = subject.formatted(zeroRowResult)
        XCTAssertEqual(result, """
            Title

            Column A  B
            """)

        subject.format = .csv
        result = subject.formatted(zeroRowResult)
        XCTAssertEqual(result, """
            "Column A", "B"

            """)

        subject.format = .table
        result = subject.formatted(zeroRowResult)
        XCTAssertEqual(result, """
            +--------------+
            | Title        |
            +--------------+
            | Column A | B |
            +----------+---+

            +----------+---+
            """)

        Rainbow.enabled = originalValue
    }

}

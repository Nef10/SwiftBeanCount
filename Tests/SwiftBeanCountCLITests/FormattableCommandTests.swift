import ArgumentParser
import Foundation
import Rainbow
@testable import SwiftBeanCountCLI
import Testing

#if os(macOS)

struct TestFormattableCommand: FormattableCommand {
    var formatOptions = FormattableCommandOptions()
    var colorOptions = ColorizedCommandOptions()

   @Test
   func getResult() throws -> [FormattableResult] {
        [FormattableResult(title: "A", columns: ["B", "C"], values: [["D E", "F G"], ["H", "I"]], footer: "J")]
    }
}

@Suite
struct FormattableCommandTests {

    private let basicResult = FormattableResult(title: "Title",
                                                columns: ["Column A", "B", "C"],
                                                values: [["1", "Value 2", "Value3"], ["Row 2", "Value 2", ""]],
                                                footer: "Footer")
    private let lastRowHighlightResult = FormattableResult(title: "Title",
                                                           columns: ["Column A", "B", "C"],
                                                           values: [["1", "Value 2", "Value3"], ["Row 2", "Value 2", ""]],
                                                           lastRowIsFooter: true,
                                                           footer: "Footer")
    private let oneColumnOneRowResult = FormattableResult(title: "Title", columns: ["Column A"], values: [["1"]], footer: nil)
    private let zeroRowResult = FormattableResult(title: "Title", columns: ["Column A", "B"], values: [], footer: nil)

   @Test
   func testCSVColor() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = true
        var subject = TestFormattableCommand()
        subject.formatOptions.format = .csv
        let result = subject.formatted(basicResult)
        XCTAssertEqual(result, """
            "Column A", "B", "C"
            "1", "Value 2", "Value3"
            "Row 2", "Value 2", ""
            """)
        Rainbow.enabled = originalValue
    }

   @Test
   func testCSV() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = false
        var subject = TestFormattableCommand()
        subject.formatOptions.format = .csv
        let result = subject.formatted(basicResult)
        XCTAssertEqual(result, """
            "Column A", "B", "C"
            "1", "Value 2", "Value3"
            "Row 2", "Value 2", ""
            """)
        Rainbow.enabled = originalValue
    }

   @Test
   func testTableColor() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = true
        var subject = TestFormattableCommand()
        subject.formatOptions.format = .table
        let result = subject.formatted(lastRowHighlightResult)
        XCTAssertEqual(result, """
            +-----------------------------+
            | \("Title".bold)                       |
            +-----------------------------+
            | Column A | B       | C      |
            +----------+---------+--------+
            | 1        | Value 2 | Value3 |
            | \("Row 2".bold)    | \("Value 2".bold) |        |
            +----------+---------+--------+

            \("Footer".lightBlack)
            """)
        Rainbow.enabled = originalValue
    }

   @Test
   func testTable() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = false
        var subject = TestFormattableCommand()
        subject.formatOptions.format = .table
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

   @Test
   func testTextColor() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = true
        var subject = TestFormattableCommand()
        subject.formatOptions.format = .text
        let result = subject.formatted(lastRowHighlightResult)
        XCTAssertEqual(result, """
            \("Title".bold.underline)

            \("Column A".bold)  \("B".bold)        \("C".bold)
            1         Value 2  Value3
            \("Row 2".bold)     \("Value 2".bold)

            \("Footer".lightBlack)
            """)
        Rainbow.enabled = originalValue
    }

   @Test
   func testText() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = false
        var subject = TestFormattableCommand()
        subject.formatOptions.format = .text
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

   @Test
   func testOneColumnOneRow() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = false
        var subject = TestFormattableCommand()
        subject.formatOptions.format = .text
        var result = subject.formatted(oneColumnOneRowResult)
        XCTAssertEqual(result, """
            Title

            Column A
            1
            """)

        subject.formatOptions.format = .csv
        result = subject.formatted(oneColumnOneRowResult)
        XCTAssertEqual(result, """
            "Column A"
            "1"
            """)

        subject.formatOptions.format = .table
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

   @Test
   func testZeroRows() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = false
        var subject = TestFormattableCommand()
        subject.formatOptions.format = .text
        var result = subject.formatted(zeroRowResult)
        XCTAssertEqual(result, """
            Title

            Column A  B
            """)

        subject.formatOptions.format = .csv
        result = subject.formatted(zeroRowResult)
        XCTAssertEqual(result, """
            "Column A", "B"

            """)

        subject.formatOptions.format = .table
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

#endif // os(macOS)

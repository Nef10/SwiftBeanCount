import ArgumentParser
import Rainbow
@testable import SwiftBeanCountCLILibrary
import XCTest

struct TestFormattableCommand: FormattableCommand {
        @ArgumentParser.Option() var format: Format

        func getResult() throws -> FormattableResult {
            return FormattableResult(title: "A", columns: ["B", "C"], values: [["D E", "F G"], ["H", "I"]], footer: "J")
        }
}

class FormattableCommandTests: XCTestCase {

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
        let result = subject.formatted(FormattableResult(title: "Title is ignored", columns: ["Column A", "B", "C"], values: [["1", "Value 2", "Value3"], ["Row 2", "Value 2", ""]], footer: nil))
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
        let result = subject.formatted(FormattableResult(title: "Title is ignored", columns: ["Column A", "B", "C"], values: [["1", "Value 2", "Value3"], ["Row 2", "Value 2", ""]], footer: nil))
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
        let result = subject.formatted(FormattableResult(title: "Title", columns: ["Column A", "B", "C"], values: [["1", "Value 2", "Value3"], ["Row 2", "Value 2", ""]], footer: nil))
        XCTAssertEqual(result, """
            +-----------------------------+
            | \("Title".bold)                       |
            +-----------------------------+
            | Column A | B       | C      |
            +----------+---------+--------+
            | 1        | Value 2 | Value3 |
            | Row 2    | Value 2 |        |
            +----------+---------+--------+
            """)
        Rainbow.enabled = originalValue
    }

    func testTable() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = false
        var subject = TestFormattableCommand()
        subject.format = .table
        let result = subject.formatted(FormattableResult(title: "Title", columns: ["Column A", "B", "C"], values: [["1", "Value 2", "Value3"], ["Row 2", "Value 2", ""]], footer: nil))
        XCTAssertEqual(result, """
            +-----------------------------+
            | Title                       |
            +-----------------------------+
            | Column A | B       | C      |
            +----------+---------+--------+
            | 1        | Value 2 | Value3 |
            | Row 2    | Value 2 |        |
            +----------+---------+--------+
            """)
        Rainbow.enabled = originalValue
    }

    func testTextColor() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = true
        var subject = TestFormattableCommand()
        subject.format = .text
        let result = subject.formatted(FormattableResult(title: "Title", columns: ["Column A", "B", "C"], values: [["1", "Value 2", "Value3"], ["Row 2", "Value 2", ""]], footer: nil))
        XCTAssertEqual(result, """
            \("Title".bold.underline)

            \("Column A".bold)  \("B".bold)        \("C".bold)
            1         Value 2  Value3
            Row 2     Value 2
            """)
        Rainbow.enabled = originalValue
    }

    func testText() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = false
        var subject = TestFormattableCommand()
        subject.format = .text
        let result = subject.formatted(FormattableResult(title: "Title", columns: ["Column A", "B", "C"], values: [["1", "Value 2", "Value3"], ["Row 2", "Value 2", ""]], footer: nil))
        XCTAssertEqual(result, """
            Title

            Column A  B        C
            1         Value 2  Value3
            Row 2     Value 2
            """)
        Rainbow.enabled = originalValue
    }

    func testOneColumnOneRow() {
        let originalValue = Rainbow.enabled
        Rainbow.enabled = false
        var subject = TestFormattableCommand()
        subject.format = .text
        var result = subject.formatted(FormattableResult(title: "Title", columns: ["Column A"], values: [["1"]], footer: nil))
        XCTAssertEqual(result, """
            Title

            Column A
            1
            """)

        subject.format = .csv
        result = subject.formatted(FormattableResult(title: "Title", columns: ["Column A"], values: [["1"]], footer: nil))
        XCTAssertEqual(result, """
            "Column A"
            "1"
            """)

        subject.format = .table
        result = subject.formatted(FormattableResult(title: "Title", columns: ["Column A"], values: [["1"]], footer: nil))
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
        var result = subject.formatted(FormattableResult(title: "Title", columns: ["Column A", "B"], values: [], footer: nil))
        XCTAssertEqual(result, """
            Title

            Column A  B
            """)

        subject.format = .csv
        result = subject.formatted(FormattableResult(title: "Title", columns: ["Column A", "B"], values: [], footer: nil))
        XCTAssertEqual(result, """
            "Column A", "B"

            """)

        subject.format = .table
        result = subject.formatted(FormattableResult(title: "Title", columns: ["Column A", "B"], values: [], footer: nil))
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

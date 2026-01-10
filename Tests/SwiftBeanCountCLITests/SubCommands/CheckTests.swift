import Foundation
@testable import SwiftBeanCountCLI
import Testing

#if os(macOS)

@Suite

struct CheckTests {

    func testFileDoesNotExist() {
        let url = temporaryFileURL()
        let result = outputFromExecutionWith(arguments: ["check", url.path])
        #expect(result.exitCode == 1)
        #expect(result.errorOutput.isEmpty)
        #if os(Linux)
        #expect(result.output == "The operation could not be completed. The file doesn’t exist.")
        #else
        #expect(result.output == "The file “\(url.lastPathComponent)” couldn’t be opened because there is no such file.")
        #endif
    }

    func testEmptyFile() {
        let url = emptyFileURL()
        assertSuccessfulExecutionResult(arguments: ["check", url.path], output: "No errors found.")
    }

    func testSuccessful() {
        let url = temporaryFileURL()
        createFile(at: url, content: """
                                     2020-06-13 commodity CAD
                                     2020-06-13 open Assets:CAD
                                     2020-06-13 open Income:Job
                                     2020-06-13 * "" ""
                                       Assets:CAD 10.00 CAD
                                       Income:Job -10.00 CAD
                                     """)
        assertSuccessfulExecutionResult(arguments: ["check", url.path], output: "No errors found.")
    }

    func testError() {
        let url = temporaryFileURL()
        createFile(at: url, content: "plugin \"beancount.plugins.check_commodity\"\n\n2020-06-13 * \"\" \"\"\n  Assets:CAD 10.00 CAD\n  Income:Job -15.00 CAD")
        let result = outputFromExecutionWith(arguments: ["check", url.path])
        #expect(result.exitCode == 65)
        #expect(result.errorOutput.isEmpty)
        XCTAssertEqual(result.output, """
                                        Found 2 errors:

                                        2020-06-13 * "" ""
                                          Assets:CAD 10.00 CAD
                                          Income:Job -15.00 CAD is not balanced - -5 CAD too much (0.005 tolerance)
                                        Commodity CAD does not have an opening date
                                        """)
    }

    func testQuietSuccessful() {
        let url = temporaryFileURL()
        createFile(at: url, content: "\n")
        assertSuccessfulExecutionResult(arguments: ["check", url.path, "-q"], output: "")
        assertSuccessfulExecutionResult(arguments: ["check", url.path, "--quiet"], output: "")
    }

    func testQuietError() {
        let url = temporaryFileURL()
        createFile(at: url, content: "2020-06-13 * \"\" \"\"\n  Assets:CAD 10.00 CAD\n  Income:Job -15.00 CAD")
        var result = outputFromExecutionWith(arguments: ["check", url.path, "-q"])
        #expect(result.exitCode == 65)
        #expect(result.errorOutput.isEmpty)
        #expect(result.output.isEmpty)
        result = outputFromExecutionWith(arguments: ["check", url.path, "--quiet"])
        #expect(result.exitCode == 65)
        #expect(result.errorOutput.isEmpty)
        #expect(result.output.isEmpty)
    }

}

#endif // os(macOS)

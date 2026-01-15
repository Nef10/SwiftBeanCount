#if os(macOS)

import Foundation
@testable import SwiftBeanCountCLI
import Testing

@Suite
struct CheckTests {

    @Test
    func fileDoesNotExist() {
        let (url, cleanup) = TestUtils.temporaryFileURL()
        defer { cleanup() }
        let result = TestUtils.outputFromExecutionWith(arguments: ["check", url.path])
        #expect(result.exitCode == 1)
        #expect(result.errorOutput.isEmpty)
        #if os(Linux)
        #expect(result.output == "The operation could not be completed. The file doesn’t exist.")
        #else
        #expect(result.output == "The file “\(url.lastPathComponent)” couldn’t be opened because there is no such file.")
        #endif
    }

    @Test
    func emptyFile() {
        let (url, cleanup) = TestUtils.temporaryFileURL()
        TestUtils.createFile(at: url, content: "\n")
        defer { cleanup() }
        TestUtils.assertSuccessfulExecutionResult(arguments: ["check", url.path], output: "No errors found.")
    }

    @Test
    func successful() {
        let (url, cleanup) = TestUtils.temporaryFileURL()
        defer { cleanup() }
        TestUtils.createFile(at: url, content: """
                                     2020-06-13 commodity CAD
                                     2020-06-13 open Assets:CAD
                                     2020-06-13 open Income:Job
                                     2020-06-13 * "" ""
                                       Assets:CAD 10.00 CAD
                                       Income:Job -10.00 CAD
                                     """)
        TestUtils.assertSuccessfulExecutionResult(arguments: ["check", url.path], output: "No errors found.")
    }

    @Test
    func error() {
        let (url, cleanup) = TestUtils.temporaryFileURL()
        defer { cleanup() }
        TestUtils.createFile(at: url, content: "plugin \"beancount.plugins.check_commodity\"\n\n2020-06-13 * \"\" \"\"\n  Assets:CAD 10.00 CAD\n  Income:Job -15.00 CAD")
        let result = TestUtils.outputFromExecutionWith(arguments: ["check", url.path])
        #expect(result.exitCode == 65)
        #expect(result.errorOutput.isEmpty)
        #expect(result.output == """
                                 Found 2 errors:

                                 2020-06-13 * "" ""
                                   Assets:CAD 10.00 CAD
                                   Income:Job -15.00 CAD is not balanced - -5 CAD too much (0.005 tolerance)
                                 Commodity CAD does not have an opening date
                                 """)
    }

    @Test
    func quietSuccessful() {
        let (url, cleanup) = TestUtils.temporaryFileURL()
        defer { cleanup() }
        TestUtils.createFile(at: url, content: "\n")
        TestUtils.assertSuccessfulExecutionResult(arguments: ["check", url.path, "-q"], output: "")
        TestUtils.assertSuccessfulExecutionResult(arguments: ["check", url.path, "--quiet"], output: "")
    }

    @Test
    func quietError() {
        let (url, cleanup) = TestUtils.temporaryFileURL()
        defer { cleanup() }
        TestUtils.createFile(at: url, content: "2020-06-13 * \"\" \"\"\n  Assets:CAD 10.00 CAD\n  Income:Job -15.00 CAD")
        var result = TestUtils.outputFromExecutionWith(arguments: ["check", url.path, "-q"])
        #expect(result.exitCode == 65)
        #expect(result.errorOutput.isEmpty)
        #expect(result.output.isEmpty)
        result = TestUtils.outputFromExecutionWith(arguments: ["check", url.path, "--quiet"])
        #expect(result.exitCode == 65)
        #expect(result.errorOutput.isEmpty)
        #expect(result.output.isEmpty)
    }

}

#endif // os(macOS)

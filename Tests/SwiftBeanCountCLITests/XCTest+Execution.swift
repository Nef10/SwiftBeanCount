import Foundation
import XCTest

extension XCTest {

    struct ExecutionResult {
        let output: String
        let errorOutput: String
        let exitCode: Int32
    }

    private var executableURL: URL {
        var url = Bundle(for: type(of: self)).bundleURL
        if url.lastPathComponent.hasSuffix("xctest") {
            url = url.deletingLastPathComponent()
        }
        return url.appendingPathComponent("swiftbeancount")
    }

    func outputFromExecutionWith(arguments: [String]) -> ExecutionResult {
        let output = Pipe()
        let error = Pipe()
        let process = Process()
        if #available(macOS 10.13, *) {
            process.executableURL = executableURL
        } else {
            process.launchPath = executableURL.path
        }
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = error

        if #available(macOS 10.13, *) {
            do {
                try process.run()
            } catch {
                XCTFail(error.localizedDescription)
            }
        } else {
            process.launch()
        }
        process.waitUntilExit()

        let data = output.fileHandleForReading.readDataToEndOfFile()
        let result = String(data: data, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(data: errorData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)

        return ExecutionResult(output: result, errorOutput: errorOutput, exitCode: process.terminationStatus)
    }

    func assertSuccessfulExecutionResult(arguments: [String], outputPrefix prefix: String) {
        let result = outputFromExecutionWith(arguments: arguments)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssert(result.errorOutput.isEmpty)
        XCTAssert(result.output.hasPrefix(prefix))
    }

    func assertSuccessfulExecutionResult(arguments: [String], output: String) {
        let result = outputFromExecutionWith(arguments: arguments)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssert(result.errorOutput.isEmpty)
        XCTAssertEqual(result.output, output)
    }

}

//
//  TestUtils.swift
//  SwiftBeanCountCLITests
//
//  Created by Steffen Kötte on 2026-01-10.
//  Copyright © 2026 Steffen Kötte. All rights reserved.
//

import Foundation
import Testing

struct ExecutionResult {
    let output: String
    let errorOutput: String
    let exitCode: Int32
}

enum TestUtils {

    private static var executableURL: URL {
        var url = Bundle.main.executableURL!
        if url.lastPathComponent.hasSuffix("xctest") {
            url = url.deletingLastPathComponent()
        }
        return url.appendingPathComponent("swiftbeancount")
    }

#if os(macOS)

    static func outputFromExecutionWith(arguments: [String]) -> ExecutionResult {
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
                Issue.record(error)
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

    static func assertSuccessfulExecutionResult(arguments: [String], outputPrefix prefix: String) {
        let result = outputFromExecutionWith(arguments: arguments)
        #expect(result.exitCode == 0)
        #expect(result.errorOutput.isEmpty)
        #expect(result.output.hasPrefix(prefix))
    }

    static func assertSuccessfulExecutionResult(arguments: [String], output: String) {
        let result = outputFromExecutionWith(arguments: arguments)
        #expect(result.exitCode == 0)
        #expect(result.errorOutput.isEmpty)
        #expect(result.output == output)
    }

#endif // os(macOS)

   static func temporaryFileURL() -> URL {
        let directory = NSTemporaryDirectory()
        let url = URL(fileURLWithPath: directory).appendingPathComponent(UUID().uuidString)
/*
        addTeardownBlock {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                } catch {
                    Issue.record("Error deleting temporary file: \(error)")
                }
            }
            #expect(!(fileManager.fileExists(atPath: url.path)))
        }
*/
        return url
    }

   static func createFile(at url: URL, content: String) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            Issue.record("Error writing temporary file: \(error)")
        }
    }

    static func emptyFileURL() -> URL {
        let url = temporaryFileURL()
        createFile(at: url, content: "\n")
        return url
    }

}

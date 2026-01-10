//
//  StatementFileValidator.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-10-14.
//

import Foundation

/// Helps validate if all statements are present based on the files
public enum StatementFileValidator {

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd"
        return dateFormatter
    }()

    /// Function to check if all statements are present in a specific folder
    /// 
    /// It will first detect the filenames used and then the frequency they occur.
    /// It can identify different yearly and monthly statements in the same folder.
    /// Lastly it will check if any statements are missing in between.
    /// - Parameters:
    ///   - folder: folder to check
    ///   - statementNames: part of file names to recognize
    /// - Returns: Array of StatementResult for identified statement filename in the folder.
    public static func checkStatementsFrom(folder: URL, statementNames: [String]) async throws -> [StatementResult] {
        let dateLength = 6

        let fileManager = FileManager()
        let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey])

        var nameCount = [String: Int]()
        var files = [String: [Date]]()

        let fileURLs = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(resourceKeys), options: .skipsHiddenFiles)
        for fileURL in fileURLs {
            let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
            guard let isDirectory = resourceValues.isDirectory, let fileName = resourceValues.name else {
                throw StatementValidatorError.resourceValuesMissing
            }
            guard !isDirectory,
                  let date = dateFormatter.date(from: String(fileName.prefix(dateLength))),
                  statementNames.contains(where: { fileName.range(of: $0, options: .caseInsensitive) != nil }) else {
                continue
            }
            // Remove date at the front, remove file type at the end and trim
            var names = [String(fileName.prefix(upTo: fileName.lastIndex(of: ".") ?? fileName.endIndex).dropFirst(dateLength)).trimmingCharacters(in: .whitespacesAndNewlines)]
            if names.first!.contains(":") { // A file can have two parts, like a statement and a quarterly end. If the file has a "/" (represented as ":") treat as two
                names = names.first!.split(separator: ":").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            for name in names {
                nameCount[name] = (nameCount[name] ?? 0) + 1
                files[name] = (files[name] ?? []) + [date]
            }
        }
        let fileNamesToCheck = getFileNamesToCheck(names: nameCount)
        guard !fileNamesToCheck.isEmpty else {
            return [StatementResult(name: "Unknown", frequency: .unkown, errors: ["Could not find statement files"])]
        }
        return fileNamesToCheck.map { StatementDatesValidator.checkDates(files[$0]!, for: $0) }
    }

    private static func getFileNamesToCheck(names: [String: Int]) -> [String] {
        guard !names.isEmpty else {
            return []
        }

        var names = names
        let fileNamesToCheck: [String]

        if names.count == 1 {
            fileNamesToCheck = [names.keys.first!]
        } else {
            let max = names.max { $0.value < $1.value }
            names.removeValue(forKey: max!.key)
            let second = names.max { $0.value < $1.value }
            if second!.value > 3 {
                fileNamesToCheck = [max!.key, second!.key]
            } else {
                fileNamesToCheck = [max!.key]
            }
        }
        return fileNamesToCheck
    }

}

//
//  Parser.swift
//  SwiftBeanCountParser
//
//  Public parser facade. Backend selection is compile-time so callers keep
//  using the same API in either configuration.
//

import Foundation
import SwiftBeanCountModel
#if RustLedger
import SwiftBeanCountRustLedger
#endif

/// Parser to parse a string of a file into a Ledger.
public enum Parser {

    /// Parses a given file into a Ledger.
    ///
    /// - Parameter contentOf: URL to parse. Encoding has to be UTF-8.
    /// - Returns: Ledger with parsed content.
    /// - Throws: Exceptions from opening the file.
    public static func parse(contentOf path: URL) throws -> Ledger {
        #if RustLedger
        return try RustParser.parse(contentOf: path)
        #else
        return try SwiftParser.parse(contentOf: path)
        #endif
    }

    /// Parses a given String into a Ledger.
    ///
    /// - Parameter string: String to parse.
    /// - Returns: Ledger with parsed content.
    public static func parse(string: String) -> Ledger {
        #if RustLedger
        return RustParser.parse(string: string)
        #else
        return SwiftParser.parse(string: string)
        #endif
    }
}

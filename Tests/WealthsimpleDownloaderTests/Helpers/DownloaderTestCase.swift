//
//  DownloaderTestCase.swift
//
//
//  Created by Steffen Kötte on 2025-09-03.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import WealthsimpleDownloader

class DownloaderTestCase { // swiftlint:disable:this file_types_order

    var mockCredentialStorage: MockCredentialStorage!

    init() {
        mockCredentialStorage = MockCredentialStorage()
        MockURLProtocol.setup()
    }

    deinit {
        MockURLProtocol.reset()
    }
}

final class TestExpectation: @unchecked Sendable {

    let description: String
    private let semaphore = DispatchSemaphore(value: 0)

    init(description: String) {
        self.description = description
    }

    func fulfill() {
        semaphore.signal()
    }

    @discardableResult
    func wait(timeout: TimeInterval) -> Bool {
        semaphore.wait(timeout: .now() + timeout) == .success
    }
}

private func toSourceLocation(file: StaticString, line: UInt) -> SourceLocation {
    .init(fileID: String(describing: file), filePath: String(describing: file), line: Int(line), column: 1)
}

func wait(for expectations: [TestExpectation], timeout: TimeInterval, file: StaticString = #file, line: UInt = #line) {
    for expectation in expectations where !expectation.wait(timeout: timeout) {
        Issue.record(Comment(rawValue: "Timed out waiting for expectation: \(expectation.description)"), sourceLocation: toSourceLocation(file: file, line: line))
    }
}

func recordFailure(_ message: @autoclosure () -> String = "", file: StaticString = #file, line: UInt = #line) {
    Issue.record(Comment(rawValue: message()), sourceLocation: toSourceLocation(file: file, line: line))
}

func expect(_ expression: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) {
    #expect(expression(), sourceLocation: toSourceLocation(file: file, line: line))
}

func expectTrue(_ expression: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) {
    #expect(expression(), sourceLocation: toSourceLocation(file: file, line: line))
}

func expectFalse(_ expression: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) {
    #expect(!expression(), sourceLocation: toSourceLocation(file: file, line: line))
}

func expectEqual<T: Equatable>(_ expression1: @autoclosure () -> T, _ expression2: @autoclosure () -> T, file: StaticString = #file, line: UInt = #line) {
    #expect(expression1() == expression2(), sourceLocation: toSourceLocation(file: file, line: line))
}

func expectNotEqual<T: Equatable>(_ expression1: @autoclosure () -> T, _ expression2: @autoclosure () -> T, file: StaticString = #file, line: UInt = #line) {
    #expect(expression1() != expression2(), sourceLocation: toSourceLocation(file: file, line: line))
}

func expectNil<T>(_ expression: @autoclosure () -> T?, file: StaticString = #file, line: UInt = #line) {
    #expect(expression() == nil, sourceLocation: toSourceLocation(file: file, line: line))
}

func expectNotNil<T>(_ expression: @autoclosure () -> T?, file: StaticString = #file, line: UInt = #line) {
    #expect(expression() != nil, sourceLocation: toSourceLocation(file: file, line: line))
}

func expectIdentical(_ expression1: @autoclosure () -> AnyObject?, _ expression2: @autoclosure () -> AnyObject?, file: StaticString = #file, line: UInt = #line) {
    #expect(expression1() === expression2(), sourceLocation: toSourceLocation(file: file, line: line))
}

@discardableResult
func expectNoThrow<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #file, line: UInt = #line) -> T? {
    do {
        return try expression()
    } catch {
        Issue.record(Comment(rawValue: "Expected no throw, but received: \(error)"), sourceLocation: toSourceLocation(file: file, line: line))
        return nil
    }
}

func expectThrows<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #file, line: UInt = #line, _ handler: ((Error) -> Void)? = nil) {
    do {
        _ = try expression()
        Issue.record(Comment(rawValue: "Expected expression to throw an error"), sourceLocation: toSourceLocation(file: file, line: line))
    } catch {
        handler?(error)
    }
}

enum UnwrapError: Error {
    case nilValue
}

func requireUnwrap<T>(_ expression: @autoclosure () -> T?, file: StaticString = #file, line: UInt = #line) throws -> T {
    guard let value = expression() else {
        Issue.record(Comment(rawValue: "Expected non-nil value"), sourceLocation: toSourceLocation(file: file, line: line))
        throw UnwrapError.nilValue
    }
    return value
}

func assert<T, E: Error & Equatable>(
    _ expression: @autoclosure () throws -> T,
    throws expectedError: E,
    file: StaticString = #file,
    line: UInt = #line
) {
    var caughtError: Error?
    expectThrows(try expression(), file: file, line: line) {
        caughtError = $0
    }

    guard let error = caughtError as? E else {
        let errorType = caughtError.map { String(describing: type(of: $0)) } ?? "nil"
        Issue.record(Comment(rawValue: "Unexpected error type, got \(errorType) instead of \(E.self)"), sourceLocation: toSourceLocation(file: file, line: line))
        return
    }

    #expect(error == expectedError, sourceLocation: toSourceLocation(file: file, line: line))
}

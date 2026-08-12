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

private actor DownloaderTestLock {
    static let shared = DownloaderTestLock()

    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func lock() async {
        guard !isLocked else {
            await withCheckedContinuation { waiters.append($0) }
            return
        }
        isLocked = true
    }

    func unlock() {
        guard let waiter = waiters.first else {
            isLocked = false
            return
        }
        waiters.removeFirst()
        waiter.resume()
    }
}

struct MockURLProtocolSerialTrait: SuiteTrait, TestTrait, TestScoping {
    var isRecursive: Bool { false }

    func provideScope(
        for _: Test,
        testCase _: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        await DownloaderTestLock.shared.lock()
        MockURLProtocol.setup()
        do {
            try await function()
            MockURLProtocol.reset()
            await DownloaderTestLock.shared.unlock()
        } catch {
            MockURLProtocol.reset()
            await DownloaderTestLock.shared.unlock()
            throw error
        }
    }
}

struct URLConfigurationSerialTrait: SuiteTrait, TestTrait, TestScoping {
    var isRecursive: Bool { false }

    func provideScope(
        for _: Test,
        testCase _: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        await DownloaderTestLock.shared.lock()
        do {
            try await function()
            await DownloaderTestLock.shared.unlock()
        } catch {
            await DownloaderTestLock.shared.unlock()
            throw error
        }
    }
}

class DownloaderTestCase {
   var mockCredentialStorage = MockCredentialStorage()
}

extension Trait where Self == URLConfigurationSerialTrait {
    static var urlConfigurationSerialized: Self { Self() }
}

extension Trait where Self == MockURLProtocolSerialTrait {
    static var mockURLProtocolSerialized: Self { Self() }
}

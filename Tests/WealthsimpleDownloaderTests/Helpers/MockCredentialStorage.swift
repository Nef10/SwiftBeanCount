//
//  MockCredentialStorage.swift
//
//
//  Created by Steffen Kötte on 2025-08-31.
//
import Foundation
@testable import WealthsimpleDownloader

/// A mock implementation of CredentialStorage for testing purposes.
class MockCredentialStorage: CredentialStorage {
    var storage: [String: String] = [:]

    func save(_ value: String, for key: String) {
        storage[key] = value
    }

    func read(_ key: String) -> String? {
        storage[key]
    }
}

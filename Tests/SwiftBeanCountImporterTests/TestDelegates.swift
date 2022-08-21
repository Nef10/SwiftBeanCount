// swiftlint:disable:this file_name
//
//  TestDelegates.swift
//  SwiftBeanCountImporterTests
//
//  Created by Steffen Kötte on 2022-08-20.
//  Copyright © 2022 Steffen Kötte. All rights reserved.
//

import Foundation
@testable import SwiftBeanCountImporter
import SwiftBeanCountModel
import XCTest

class BaseTestImporterDelegate: ImporterDelegate {

    func requestInput(name: String, suggestions: [String], isSecret: Bool, completion: (String) -> Bool) {
        XCTFail("requestInput should not be called")
    }

    func saveCredential(_ value: String, for key: String) {
        XCTFail("saveCredential should not be called")
    }

    func readCredential(_ key: String) -> String? {
        XCTFail("readCredential should not be called")
        return nil
    }

    func error(_ error: Error) {
        XCTFail("error should not be called, received \(error)")
    }

    #if canImport(UIKit)

    func view() -> UIView? {
        XCTFail("view should not be called")
        return nil
    }

    #elseif canImport(AppKit)

    func view() -> NSView? {
        XCTFail("view should not be called")
        return nil
    }

    #endif

    #if canImport(UIKit) || canImport(AppKit)

    func removeView() {
        XCTFail("removeView should not be called")
    }

    #endif

}

class AccountNameSuggestionVerifier: BaseTestImporterDelegate {
    let expectedValues: [String]
    var verified = false

    init (expectedValues: [AccountName]) {
        self.expectedValues = expectedValues.map { $0.fullName }
    }

    override func requestInput(name: String, suggestions: [String], isSecret: Bool, completion: (String) -> Bool) {
        XCTAssertEqual(name, "Account")
        XCTAssertEqual(suggestions.count, expectedValues.count)
        for suggestion in suggestions {
            XCTAssert(expectedValues.contains(suggestion))
        }
        XCTAssertFalse(isSecret)
        verified = true
        _ = completion(TestUtils.cash.fullName)
    }
}

class InputProviderDelegate: BaseTestImporterDelegate {
    private let names: [String]
    private let secrets: [Bool]
    private let returnValues: [String]

    private var verifiedInput = false
    private var index = 0

    var verified: Bool {
        verifiedInput
    }

    init(names: [String] = ["Username", "Password", "OTP"], secrets: [Bool] = [false, true, false], returnValues: [String] = ["testUserName", "testPassword", "testOTP"]) {
        self.names = names
        self.secrets = secrets
        self.returnValues = returnValues
        if names.count != secrets.count || names.count != returnValues.count {
            XCTFail("Invalid parameters")
        }
        if names.isEmpty {
            verifiedInput = true
        }
    }

    override func requestInput(name: String, suggestions: [String], isSecret: Bool, completion: (String) -> Bool) {
        guard index < names.count else {
            XCTFail("Called requestInput too often")
            return
        }
        XCTAssertEqual(name, names[index])
        XCTAssert(suggestions.isEmpty)
        XCTAssertEqual(isSecret, secrets[index])
        XCTAssert(completion(returnValues[index]))
        index += 1
        if index == names.count {
            verifiedInput = true
        }
    }
}

class CredentialInputDelegate: InputProviderDelegate { // swiftlint:disable:this file_types_order
    private let saveKeys: [String]
    private let saveValues: [String]
    private let readKeys: [String]
    private let readReturnValues: [String?]

    private var verifiedSave = false
    private var verifiedRead = false
    private var saveIndex = 0
    private var readIndex = 0
    override var verified: Bool {
        super.verified && verifiedSave && verifiedRead
    }

    convenience init() {
        self.init(inputNames: [], inputSecrets: [], inputReturnValues: [], saveKeys: [], saveValues: [], readKeys: [], readReturnValues: [])
    }

    convenience init(saveKeys: [String], saveValues: [String], readKeys: [String], readReturnValues: [String?]) {
        self.init(inputNames: [], inputSecrets: [], inputReturnValues: [], saveKeys: saveKeys, saveValues: saveValues, readKeys: readKeys, readReturnValues: readReturnValues)
    }

    init(inputNames: [String], inputSecrets: [Bool], inputReturnValues: [String], saveKeys: [String], saveValues: [String], readKeys: [String], readReturnValues: [String?]) {
        self.saveKeys = saveKeys
        self.saveValues = saveValues
        self.readKeys = readKeys
        self.readReturnValues = readReturnValues
        if saveKeys.count != saveValues.count || readKeys.count != readReturnValues.count {
            XCTFail("Invalid parameters")
        }
        if saveKeys.isEmpty {
            verifiedSave = true
        }
        if readKeys.isEmpty {
            verifiedRead = true
        }
        super.init(names: inputNames, secrets: inputSecrets, returnValues: inputReturnValues)
    }

    override func saveCredential(_ value: String, for key: String) {
        guard saveIndex < saveKeys.count else {
            XCTFail("Called saveCredential too often")
            return
        }
        XCTAssertEqual(value, saveValues[saveIndex])
        XCTAssertEqual(key, saveKeys[saveIndex])
        saveIndex += 1
        if saveIndex == saveKeys.count {
            verifiedSave = true
        }
    }

    override func readCredential(_ key: String) -> String? {
        guard readIndex < readKeys.count else {
            XCTFail("Called readCredential too often")
            return nil
        }
        XCTAssertEqual(key, readKeys[readIndex])
        readIndex += 1
        if readIndex == readKeys.count {
            verifiedRead = true
        }
        return readReturnValues[readIndex - 1]
    }
}

class ErrorDelegate<T: EquatableError>: CredentialInputDelegate {
    private let error: T?
    private var errorVerified = false
    override var verified: Bool {
        super.verified && (errorVerified || error == nil)
    }

    convenience init(error: T?) {
        self.init(inputNames: [], inputSecrets: [], inputReturnValues: [], saveKeys: [], saveValues: [], readKeys: [], readReturnValues: [], error: error)
    }

    init(
        inputNames: [String],
        inputSecrets: [Bool],
        inputReturnValues: [String],
        saveKeys: [String],
        saveValues: [String],
        readKeys: [String],
        readReturnValues: [String?],
        error: T? = nil
    ) {
        self.error = error
        super.init(inputNames: inputNames,
                   inputSecrets: inputSecrets,
                   inputReturnValues: inputReturnValues,
                   saveKeys: saveKeys,
                   saveValues: saveValues,
                   readKeys: readKeys,
                   readReturnValues: readReturnValues)
    }

    override func error(_ error: Error) {
        if self.error == nil {
            XCTFail("Received unexpected error: \(error)")
        }
        XCTAssertEqual(error as? T, self.error)
        errorVerified = true
    }
}

class CredentialInputAndViewDelegate: ErrorDelegate<TestError> {

    private var removeViewCalled = false
    private var getViewCalled = false

    override var verified: Bool {
        #if canImport(UIKit) || canImport(AppKit)
        super.verified && removeViewCalled && getViewCalled
        #else
        super.verified
        #endif
    }

    #if canImport(UIKit)

    override func view() -> UIView? {
        XCTAssertFalse(getViewCalled, "view called too often")
        getViewCalled = true
        return nil
    }

    #elseif canImport(AppKit)

    override func view() -> NSView? {
        XCTAssertFalse(getViewCalled, "view called too often")
        getViewCalled = true
        return nil
    }

    #endif

    #if canImport(UIKit) || canImport(AppKit)

    override func removeView() {
        XCTAssertFalse(removeViewCalled, "removeView called too often")
        removeViewCalled = true
    }

    #endif

}

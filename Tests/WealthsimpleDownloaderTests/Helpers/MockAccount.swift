//
//  MockAccount.swift
//
//
//  Created by Steffen Kötte on 2025-09-03.
//
import Foundation
@testable import WealthsimpleDownloader

struct MockAccount: Account {
    let id: String
    let accountType: AccountType
    let currency: String
    let number: String
}

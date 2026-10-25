//
//  DuplicateViewModel.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-12-18.
//

import Foundation
import SwiftBeanCountModel

struct DuplicateViewModel: Identifiable {
    let id = UUID()
    let importedTransaction: Transaction
    let possibleDuplicate: Transaction
    let importerName: String
    let onImport: (() -> Void)?
    let onSkip: (() -> Void)?
}

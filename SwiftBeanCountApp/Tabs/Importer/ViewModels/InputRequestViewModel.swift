//
//  InputRequestViewModel.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-12-12.
//

import Foundation
import SwiftBeanCountImporter

struct InputRequestViewModel: Identifiable {
    let id = UUID()
    let importerName: String
    let inputName: String
    let inputType: ImporterInputRequestType
    let onSubmit: ((String) -> Void)?
    let onCancel: (() -> Void)?
}

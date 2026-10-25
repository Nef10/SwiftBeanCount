//
//  ExportInputRequestViewModel.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2026-05-23.
//

import Foundation

struct ExportInputRequestViewModel: Identifiable {
    let id = UUID()
    let exporterName: String
    let inputName: String
    let inputType: ExporterInputRequestType
    let onSubmit: ((String) -> Void)?
    let onCancel: (() -> Void)?
}

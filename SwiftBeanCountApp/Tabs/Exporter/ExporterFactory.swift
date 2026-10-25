//
//  ExporterFactory.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2026-05-23.
//

import Foundation
import SwiftBeanCountModel

enum ExporterWorkflowError: LocalizedError {
    case canceled

    var errorDescription: String? {
        switch self {
        case .canceled:
            "Export cancelled."
        }
    }
}

enum ExporterInputRequestType: Equatable {
    case bool
    case choice([String])
    case secret
    case text([String])
}

protocol LedgerExporterDelegate: AnyObject {
    func requestInput(
        name: String,
        type: ExporterInputRequestType,
        onSubmit: @escaping (String) -> Bool,
        onCancel: @escaping () -> Void
    )
}

protocol LedgerExporter: AnyObject {
    static var exporterName: String { get }

    var exportName: String { get }
    var delegate: LedgerExporterDelegate? { get set }

    init(ledger: Ledger)

    func export(completion: @escaping (Result<String, Error>) -> Void)
}

enum ExportType: String, CaseIterable, Equatable, Hashable, Identifiable {

    case googleSheets = "Google Sheets"

    var id: Self { self }
    var displayName: String { rawValue }

}

enum ExporterFactory {
    static var exporters: [ExportType] {
        ExportType.allCases
    }

    static func new(type: ExportType, ledger: Ledger) -> any LedgerExporter {
        switch type {
        case .googleSheets:
            GoogleSheetsExporter(ledger: ledger)
        }
    }
}

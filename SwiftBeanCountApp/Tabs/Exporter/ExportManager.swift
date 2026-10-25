//
//  ExportManager.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2026-05-23.
//

import Foundation
import SwiftBeanCountModel

class ExportManager: ObservableObject {

    @Published var resultText = ""
    @Published var showLoadingIndicator = true
    @Published var loadingMessage: String? = "Preparing export"
    @Published var showErrorAlert = false
    @Published var errorMessage = ""
    @Published var inputRequestVM: ExportInputRequestViewModel?

    private var currentExporter: (any LedgerExporter)?
    private var inputRequestCompletion: ((String) -> Bool)?
    private var inputRequestCancel: (() -> Void)?

    func startExport(_ exportType: ExportType, from ledgerManager: LedgerManager) async {
        await prepareForExport()

        do {
            let exporter = try await beginExport(exportType, from: ledgerManager)
            let output = try await runExport(using: exporter)
            currentExporter = nil
            await finishWithResult(output)
        } catch ExporterWorkflowError.canceled {
            currentExporter = nil
            await showCanceledResult()
        } catch {
            currentExporter = nil
            await showErrorMessage(error.localizedDescription)
        }
    }

    func dismissError() {
        showErrorAlert = false
    }

    func handleInputSubmit(_ result: String) {
        Task { @MainActor in
            let completion = inputRequestCompletion
            let currentInputVM = inputRequestVM
            inputRequestVM = nil

            guard let completion else {
                return
            }

            if completion(result) {
                loadingMessage = "Continuing export"
                inputRequestCompletion = nil
                inputRequestCancel = nil
            } else if let currentInputVM {
                presentInputRequest(exporterName: currentInputVM.exporterName,
                                    inputName: currentInputVM.inputName,
                                    inputType: currentInputVM.inputType)
            }
        }
    }

    @MainActor
    func cancelInput() {
        let cancel = inputRequestCancel
        inputRequestVM = nil
        inputRequestCompletion = nil
        inputRequestCancel = nil
        cancel?()
    }

    private func getExporter(for exportType: ExportType, ledger: Ledger) -> any LedgerExporter {
        ExporterFactory.new(type: exportType, ledger: ledger)
    }

    private func runExport(using exporter: any LedgerExporter) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            exporter.export { result in
                continuation.resume(with: result)
            }
        }
    }

    @MainActor
    private func prepareForExport() {
        showLoadingIndicator = true
        loadingMessage = "Reading ledger"
        resultText = ""
    }

    private func beginExport(_ exportType: ExportType, from ledgerManager: LedgerManager) async throws -> any LedgerExporter {
        let ledger = try await ledgerManager.getLedgerContent()
        let exporter = getExporter(for: exportType, ledger: ledger)
        currentExporter = exporter
        exporter.delegate = self
        await MainActor.run {
            loadingMessage = "Exporting: \(exporter.exportName)"
        }
        return exporter
    }

    @MainActor
    private func finishWithResult(_ output: String) {
        resultText = output
        showLoadingIndicator = false
        loadingMessage = nil
    }

    @MainActor
    private func showCanceledResult() {
        resultText = "Export cancelled."
        showLoadingIndicator = false
        loadingMessage = nil
    }

    @MainActor
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showErrorAlert = true
        showLoadingIndicator = false
        loadingMessage = nil
    }

    @MainActor
    private func presentInputRequest(exporterName: String, inputName: String, inputType: ExporterInputRequestType) {
        inputRequestVM = ExportInputRequestViewModel(exporterName: exporterName, inputName: inputName, inputType: inputType) { [weak self] result in
            self?.handleInputSubmit(result)
        } onCancel: { [weak self] in
            self?.cancelInput()
        }
    }

}

extension ExportManager: LedgerExporterDelegate {

    func requestInput(
        name: String,
        type: ExporterInputRequestType,
        onSubmit: @escaping (String) -> Bool,
        onCancel: @escaping () -> Void
    ) {
        inputRequestCompletion = onSubmit
        inputRequestCancel = onCancel
        Task { @MainActor in
            loadingMessage = "Waiting for input"
            presentInputRequest(exporterName: currentExporter?.exportName ?? "Exporter",
                                inputName: name,
                                inputType: type)
        }
    }

}

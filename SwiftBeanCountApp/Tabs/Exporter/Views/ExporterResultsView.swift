//
//  ExporterResultsView.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2026-05-23.
//

import SwiftUI

struct ExporterResultsView: View {

    @EnvironmentObject var ledger: LedgerManager

    @Binding private var export: ExportType?

    @StateObject private var exportManager = ExportManager()

    var body: some View {
        VStack(alignment: .leading) {
            Text("Export Result").font(.headline)
            ZStack {
                ScrollView {
                    Text(exportManager.resultText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .lineLimit(nil)
                        .padding(7)
                        .textSelection(.enabled)
                        .background(.gray.opacity(0.1))
                        .cornerRadius(5)
                        .blur(radius: exportManager.showLoadingIndicator ? 5 : 0)
                }
                if exportManager.showLoadingIndicator {
                    HStack { LoadingView(message: $exportManager.loadingMessage) }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .background(.gray.opacity(0.1))
                        .cornerRadius(5)
                }
            }
            HStack {
                Spacer()
                Button("Done") { export = nil }
                    .buttonStyle(.borderedProminent)
                    .disabled(exportManager.showLoadingIndicator)
            }
        }
        .padding()
        .alert("Error", isPresented: $exportManager.showErrorAlert) {
            Button("OK") { exportManager.dismissError() }
        } message: {
            Text(exportManager.errorMessage)
        }
        .sheet(item: $exportManager.inputRequestVM) { viewModel in
            ExporterInputRequestView(viewModel: viewModel)
        }
        .task {
            guard let export else {
                return
            }
            await exportManager.startExport(export, from: ledger)
        }
    }

    init(_ export: Binding<ExportType?>) {
        _export = export
    }

}

#Preview {
    ExporterResultsView(.constant(.googleSheets))
        .environmentObject(LedgerManager(URL(fileURLWithPath: "/Users/User/Download/Test.beancount")))
}

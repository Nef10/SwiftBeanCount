//
//  ImporterResultsView.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-12-03.
//

import SwiftBeanCountImporter
import SwiftBeanCountModel
import SwiftUI

struct ImporterResultsView: View {

    @EnvironmentObject var ledger: LedgerManager

    @Binding private var imports: [ImportType]

    @StateObject private var importManager = ImportManager()

    var resultText: String {
        """
            \(importManager.resultLedger.transactions.sorted { $0.metaData.date < $1.metaData.date }.map { "\($0)" }.joined(separator: "\n\n"))

            \(importManager.resultLedger.accounts.flatMap(\.balances)
                .sorted { (balance1: Balance, balance2: Balance) in
                    balance1.date == balance2.date ? balance1.accountName.fullName < balance2.accountName.fullName : balance1.date < balance2.date
                }
                .map { "\($0)" }
                .joined(separator: "\n"))

            \(importManager.resultLedger.prices
                .sorted { $0.date == $1.date ? $0.commoditySymbol < $1.commoditySymbol : $0.date < $1.date }
                .map { "\($0)" }
                .joined(separator: "\n"))
            """.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading) {
#if os(macOS)
            Text("Imported Transactions:").font(.headline)
#endif
            ZStack {
                VStack {
                    ScrollView {
#if !os(macOS)
                        Text("Imported Transactions:").font(.headline)
#endif
                        Text(resultText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .lineLimit(nil)
                            .padding(7)
                            .textSelection(.enabled)
                            .background(.gray.opacity(0.1))
                            .cornerRadius(5)
                            .blur(radius: importManager.showLoadingIndicator ? 5 : 0)
                    }
                }
                if importManager.showLoadingIndicator {
                    HStack { LoadingView(message: $importManager.loadingMessage) }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .background(.gray.opacity(0.1))
                        .cornerRadius(5)
                }
            }
            HStack {
                Spacer()
                Button("Done") { imports = [] }.disabled(importManager.showLoadingIndicator).buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .alert("Error", isPresented: $importManager.showErrorAlert) { Button("OK") { importManager.dismissError() } } message: { Text(importManager.errorMessage) }
        .sheet(item: $importManager.duplicateVM) { viewModel in
            ImporterDuplicateView(viewModel: viewModel)
        }
        .sheet(item: $importManager.inputRequestVM) { viewModel in
            ImporterInputRequestView(viewModel: viewModel)
        }
        .sheet(item: $importManager.dataEntryVM) { viewModel in
            ImporterDataEntryView(viewModel: viewModel)
        }
        .task {
            await importManager.startImporting(imports, from: ledger)
        }
    }

    init(_ imports: Binding<[ImportType]>) {
        self._imports = imports
    }

}

#Preview {
    ImporterResultsView(.constant([])).environmentObject(LedgerManager(URL(fileURLWithPath: "/Users/User/Download/Test.beancount")))
}

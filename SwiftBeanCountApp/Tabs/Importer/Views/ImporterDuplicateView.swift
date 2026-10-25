//
//  ImporterDuplicateView.swift
//  SwiftBeanCountApp
//
//  Created by Copilot on 2026-04-12.
//

import SwiftBeanCountImporter
import SwiftBeanCountModel
import SwiftUI

struct ImporterDuplicateView: View {

    let viewModel: DuplicateViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("The transaction found in the import data of \(viewModel.importerName):")
                .font(.headline)
            Text(String(describing: viewModel.importedTransaction))
                .font(.body)
                .padding(.bottom, 8)
            Text("seems to be already present in your ledger:")
                .font(.headline)
            Text(String(describing: viewModel.possibleDuplicate))
                .font(.body)
                .padding(.bottom, 8)
            Text("How do you want to proceed?")
                .font(.headline)
            HStack {
                Button("Import Anyways") { viewModel.onImport?() }
                    .buttonStyle(.borderedProminent)
                Button("Skip") { viewModel.onSkip?() }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(minWidth: 350)
    }
}

#Preview("Default") {
    let transaction = Transaction(metaData: TransactionMetaData(date: Date(), narration: "Test"), postings: [])
    let possibleDuplicate = Transaction(metaData: TransactionMetaData(date: Date(), narration: "Duplicate", metaData: [:]), postings: [])
    let viewModel = DuplicateViewModel(importedTransaction: transaction, possibleDuplicate: possibleDuplicate, importerName: "Import A", onImport: nil, onSkip: nil)
    ImporterDuplicateView(viewModel: viewModel)
}

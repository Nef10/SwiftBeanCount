//
//  ImporterDataEntryView.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-12-18.
//

import SwiftBeanCountImporter
import SwiftBeanCountModel
import SwiftUI

struct ImporterDataEntryView: View {

    @State private var viewModel: DataEntryViewModel
    @State private var showAccountValidationError = false
    @State private var payees = [String]()
    @State private var accounts = [String]()
    @State private var tags = [String]()

    @EnvironmentObject var ledger: LedgerManager

    var body: some View {
        Form {
            TextField("Date:", text: .constant(viewModel.dateString)).disabled(true)
            TextField("Amount:", text: .constant(viewModel.amount)).disabled(true).padding(.bottom)

            TextField("Payee:", text: $viewModel.payee)
#if os(macOS)
                .textInputSuggestions { payeeCompletions }
#endif
            TextField("Description:", text: $viewModel.description)
            Toggle(isOn: $viewModel.saveDescriptionPayeeMapping) { Text("Save this description / payee mapping") }.padding(.bottom)

            TextField("Tags:", text: $viewModel.tags)
#if os(macOS)
                .textInputSuggestions { tagCompletions }
#endif
            Picker("Flag:", selection: $viewModel.flag) {
                Text("Complete").tag("*")
                Text("Incomplete").tag("!")
            }.padding(.bottom)
#if os(macOS)
                .pickerStyle(.radioGroup)
                .horizontalRadioGroupLayout()
#endif
            TextField("Account:", text: $viewModel.account)
#if os(macOS)
                .textInputSuggestions { accountCompletions }
#endif
            Toggle(isOn: $viewModel.saveAccountMapping) { Text("Save this account for the payee") }.disabled(!viewModel.saveDescriptionPayeeMapping).padding(.bottom)
            buttons
        }
        .padding()
        .alert("Error", isPresented: $showAccountValidationError) { Button("OK") { /* nothing */ } } message: { Text("Please enter a valid account.") }
        .onChange(of: ledger.loadingLedger, initial: true) {
            Task { await calculateAccountsAndPayees() }
        }
    }

    private var buttons: some View {
        HStack {
            Spacer()
            Button("Abort Import") { viewModel.onAbort?() }
            Button("Skip") { viewModel.onSkip?() }
            Button("Save") { saveTransaction() }
        }
    }

    private var payeeCompletions: some View {
        ForEach(payees.filter { $0.lowercased().contains(viewModel.payee.lowercased()) && $0.lowercased() != viewModel.payee.lowercased() }, id: \.self) {
            Text($0)
#if os(macOS)
                .textInputCompletion($0)
#endif
        }
    }

    private var accountCompletions: some View {
        ForEach(AccountType.allValues(), id: \.self) { accountType in
            let accounts = accounts.filter {
                $0.hasPrefix(accountType.rawValue) && $0.lowercased().contains(viewModel.account.lowercased()) && $0.lowercased() != viewModel.account.lowercased()
            }
            if !accounts.isEmpty {
                Section(content: {
                    ForEach(accounts, id: \.self) {
                        Text($0)
#if os(macOS)
                            .textInputCompletion($0)
#endif
                    }
                }, header: {
                    Text(accountType.rawValue)
                })
            }
        }
    }

    private var tagCompletions: some View {
        let currentTag = currentTagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCurrentTag = currentTag.starts(with: "#") ? String(currentTag.dropFirst()) : currentTag

        return ForEach(tags.filter {
            $0.dropFirst().lowercased().contains(normalizedCurrentTag.lowercased()) && $0.dropFirst().lowercased() != normalizedCurrentTag.lowercased()
        }, id: \.self) {
            Text($0)
#if os(macOS)
                .textInputCompletion(completedTags(for: $0))
#endif
        }
    }

    private var currentTagInput: String {
        viewModel.tags.components(separatedBy: CharacterSet.whitespacesAndNewlines).last ?? ""
    }

    init(viewModel: DataEntryViewModel) {
        self.viewModel = viewModel
    }

    private func calculateAccountsAndPayees() async {
        guard let ledger = try? await ledger.getLedgerContent() else {
            return
        }
        payees = Array(Set(ledger.transactions.map(\.metaData.payee))).filter { !$0.isEmpty }.sorted { $0.lowercased() < $1.lowercased() }
        accounts = Array(Set(ledger.transactions.flatMap { $0.postings.map(\.accountName.fullName) })).filter { !$0.isEmpty }.sorted { $0.lowercased() < $1.lowercased() }
        tags = Array(Set(ledger.transactions.flatMap { $0.metaData.tags.map(\.description) })).filter { !$0.isEmpty }.sorted { $0.lowercased() < $1.lowercased() }
    }

    private func completedTags(for tag: String) -> String {
        guard !currentTagInput.isEmpty else {
            return viewModel.tags + tag
        }
        return String(viewModel.tags.dropLast(currentTagInput.count)) + tag
    }

    private func saveTransaction() {
        guard let accountName = try? AccountName(viewModel.account) else {
            showAccountValidationError = true
            return
        }
        guard let transaction = viewModel.buildTransaction(accountName: accountName) else {
            showAccountValidationError = true
            return
        }
        if viewModel.saveDescriptionPayeeMapping {
            viewModel.importedTransaction.saveMapped(description: transaction.metaData.narration,
                                                     payee: transaction.metaData.payee,
                                                     accountName: viewModel.saveAccountMapping ? accountName : nil)
        }
        viewModel.onImport?(transaction)
    }

}

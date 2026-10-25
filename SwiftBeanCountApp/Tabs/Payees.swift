//
//  Payees.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-12-20.
//

import Foundation
import OSLog
import SwiftBeanCountModel
import SwiftUI

/// Displays all payees from the ledger with their transaction counts
/// and shows potential duplicate payees with confidence scores.
struct Payees: View {

    private struct PayeeCount: Identifiable {
        let name: String
        let count: Int

        var id: String { name }
    }

    @EnvironmentObject var ledger: LedgerManager

    @State private var loading = false
    @State private var payeeCounts = [PayeeCount]()
    @State private var duplicates = [PayeeDuplicate]()
    @State private var searchText = ""
    @State private var sortOrder = [KeyPathComparator(\PayeeCount.name)]

    private var filteredPayees: [PayeeCount] {
        let filtered = searchText.isEmpty
            ? payeeCounts
            : payeeCounts.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        return filtered.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(alignment: .leading) {
            if loading {
                LoadingView()
            } else {
                content
            }
        }
        .padding()
        .onAppear {
            if !loading {
                loadPayees()
            }
        }
        .onChange(of: ledger.loadingLedger) {
            if ledger.loadingLedger {
                loadPayees()
            }
        }
    }

    private var content: some View {
#if os(macOS)
        HSplitView {
            payeeListSection.padding(.trailing)
            duplicateSection.padding(.leading)
        }
#else
        VStack {
            payeeListSection
            Divider()
            duplicateSection
        }
#endif
    }

    private var payeeListSection: some View {
        VStack(alignment: .leading) {
            Text("Payees (\(payeeCounts.count))")
                .font(.headline)
            TextField("Search payees...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .overlay(alignment: .trailing) {
                   if !searchText.isEmpty {
                       Button {
                           searchText = ""
                       } label: {
                           Image(systemName: "xmark.circle.fill")
                               .foregroundColor(.gray)
                               .padding(.trailing, 8)
                               .accessibilityLabel("Clear text field")
                       }.buttonStyle(.plain)
                   }
                }
            Table(of: PayeeCount.self, sortOrder: $sortOrder) {
                TableColumn("Payee", value: \.name)
                TableColumn("Count", value: \.count) { payee in
                    Text("\(payee.count)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            } rows: {
                ForEach(filteredPayees) { payee in
                    TableRow(payee)
                }
            }
        }
        .frame(minWidth: 200)
    }

    private var duplicateSection: some View {
        VStack(alignment: .leading) {
            Text("Potential Duplicates (\(duplicates.count))")
                .font(.headline)
                .padding(.bottom, 4)
            if duplicates.isEmpty {
                emptyDuplicatesView
            } else {
                duplicateList
            }
        }
        .frame(minWidth: 300)
    }

    private var emptyDuplicatesView: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("No potential duplicates found.")
                    .foregroundColor(.secondary)
                Spacer()
            }
            Spacer()
        }
    }

    private var duplicateList: some View {
        List(duplicates) { duplicate in
            duplicateView(duplicate)
        }
    }

    func duplicateView(_ duplicate: PayeeDuplicate) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(duplicate.payee1).bold()
                Text("(\(duplicate.countPayee1))")
                Text("↔").foregroundColor(.secondary)
                Text(duplicate.payee2).bold()
                Text("(\(duplicate.countPayee2))")
                Spacer()
                Button("Not a Duplicate") {
                    markAsNotDuplicate(duplicate)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            HStack {
                Text(duplicate.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Confidence: \(Int(duplicate.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(confidenceColor(duplicate.confidence))
                    .padding(.trailing, 8)
            }
        }
        .padding(.vertical, 2)
    }

    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.9 {
            return .red
        }
        if confidence >= 0.7 {
            return .orange
        }
        return .yellow
    }

    private func loadPayees() {
        guard !loading else {
            return
        }

        loading = true
        let ledgerManager = ledger

        Task.detached(priority: .userInitiated) {
            do {
                Logger.payees.info("Payees - Start")
                let ledgerContent = try await ledgerManager.getLedgerContent()
                Logger.payees.info("Payees - Got Ledger")
                let (sortedCounts, foundDuplicates) = PayeeDuplicateDetector.processPayees(from: ledgerContent)
                Logger.payees.info("Payees - Found \(foundDuplicates.count) potential duplicates")
                let counts = sortedCounts.map { PayeeCount(name: $0.0, count: $0.1) }
                await MainActor.run {
                    payeeCounts = counts
                    duplicates = foundDuplicates
                    loading = false
                }
                Logger.payees.info("Payees - Done")
            } catch {
                await MainActor.run {
                    loading = false
                }
                Logger.payees.error("\(error.localizedDescription)")
            }
        }
    }

    private func markAsNotDuplicate(_ duplicate: PayeeDuplicate) {
        let ignoredPair = IgnoredPayeeDuplicatePair(payee1: duplicate.payee1, payee2: duplicate.payee2)
        IgnoredPayeeDuplicateSettings.add(ignoredPair)
        duplicates.removeAll {
            IgnoredPayeeDuplicatePair(payee1: $0.payee1, payee2: $0.payee2) == ignoredPair
        }
    }

}

#Preview {
    Payees().environmentObject(LedgerManager(URL(fileURLWithPath: "/Users/User/Download/Test.beancount")))
}

#Preview {
    Payees().duplicateView(PayeeDuplicate(payee1: "Test Sushi", countPayee1: 4, payee2: "Tes Sushi", countPayee2: 3, confidence: 0.4, reason: "1 character difference"))
        .padding()
}

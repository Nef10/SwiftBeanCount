//
//  Taxes.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-02-19.
//

import OSLog
@preconcurrency import SwiftBeanCountTax
import SwiftUI

struct Slip: View {

    let slip: TaxSlip

    var body: some View {
        VStack {
            Text("**\(slip.header)**")
            ScrollView {
                boxesWithNumbers
                if !slip.boxesWithoutNumbers.isEmpty {
                    boxesWithoutNumbers
                }
            }
        }
    }

    private var boxesWithNumbers: some View {
        VStack {
            let columns = Array(repeating: GridItem(.flexible(), alignment: .leading), count: slip.boxesWithNumbers.count + (slip.symbols.isEmpty ? 0 : 2))
            LazyVGrid(columns: columns) {
                if !slip.symbols.isEmpty {
                    Text("**Symbol**")
                    Text("**Name**")
                }
                ForEach(slip.boxesWithNumbers, id: \.self) {
                    Text("**\($0)**")
                }
                ForEach(slip.rowsWithBoxNumbers) { row in
                    if !slip.symbols.isEmpty {
                        Text(row.symbol ?? "").lineLimit(1)
                        Text(row.name ?? "").lineLimit(1)
                    }
                    ForEach(row.values) { value in
                        Text(value.displayValue)
                    }
                }
                if !slip.symbols.isEmpty {
                    Text("")
                    Text("**Totals**")
                    ForEach(slip.sumRowWithBoxNumbers.values) { value in
                        Text("**\(value.displayValue)**")
                    }
                }
            }
        }
    }

    private var boxesWithoutNumbers: some View {
        VStack {
            Divider()
            let columns = Array(repeating: GridItem(.flexible(), alignment: .leading), count: slip.boxesWithoutNumbers.count + (slip.symbols.isEmpty ? 0 : 2))
            LazyVGrid(columns: columns) {
                if !slip.symbols.isEmpty {
                    Text("**Symbol**")
                    Text("**Name**")
                }
                ForEach(slip.boxesWithoutNumbers, id: \.self) {
                    Text("**\($0)**")
                }
                ForEach(slip.rowsWithoutBoxNumbers) { row in
                    if !slip.symbols.isEmpty {
                        Text(row.symbol ?? "").lineLimit(1)
                        Text(row.name ?? "").lineLimit(1)
                    }
                    ForEach(row.values) { value in
                        Text(value.displayValue)
                    }
                }
                if !slip.symbols.isEmpty {
                    Text("")
                    Text("**Totals**")
                    ForEach(slip.sumRowWithoutBoxNumbers.values) { value in
                        Text("**\(value.displayValue)**")
                    }
                }
            }
            Spacer()
        }
    }
}

struct TaxSlips: View {

    @EnvironmentObject var ledger: LedgerManager

    @State private var year: Int = Calendar.current.dateComponents([.year], from: Date()).year! - 1
    @State private var generating = false
    @State private var slips = [TaxSlip]()

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Tax Year:")
                TextField("", value: $year, format: .number.grouping(.never))
                    .fixedSize()
                    .padding(.horizontal, -5)
                Stepper("", value: $year)
                Spacer()
            }.padding(.bottom)
            if generating {
                LoadingView()
            } else {
                TabView {
                    ForEach(slips, id: \.id) { slip in
                        Slip(slip: slip).tabItem { Text(slip.title) }.padding()
                    }
                }
            }
        }
        .padding()
        .onAppear {
            if !generating {
                generateSlips()
            }
        }
        .onChange(of: year) {
            generateSlips()
        }
        .onChange(of: ledger.loadingLedger) {
            if ledger.loadingLedger {
                generateSlips()
            }
        }
    }

    private func generateSlips() {
        generating = true
        Task.detached {
            do {
                Logger.tax.info("Tax Slips - Start")
                let ledger = try await ledger.getLedgerContent()
                Logger.tax.info("Tax Slips - Got Ledger")
                let slips = try await TaxCalculator.generateTaxSlips(from: ledger, for: year)
                Logger.tax.info("Tax Slips - Generated Slips")
                DispatchQueue.main.async {
                    self.slips = slips
                    generating = false
                }
                Logger.tax.info("Tax Slips - Done")
            } catch {
                DispatchQueue.main.async {
                    generating = false
                }
                Logger.tax.error("\(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    TaxSlips().environmentObject(LedgerManager(URL(fileURLWithPath: "/Users/User/Download/Test.beancount")))
}

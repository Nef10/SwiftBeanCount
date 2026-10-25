//
//  TaxSales.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-02-19.
//

import OSLog
@preconcurrency import SwiftBeanCountTax
import SwiftUI

struct Sales: View {

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    let sales: [Sale]

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), alignment: .leading), count: 6)
        ScrollView {
            LazyVGrid(columns: columns) {
                Text("Date").bold()
                Text("Symbol").bold()
                Text("Quanity").bold()
                Text("Name").bold()
                Text("Proceeds").bold()
                Text("Gain").bold()
                ForEach(sales, id: \.description) { sale in
                    Group {
                        Text(Self.dateFormatter.string(from: sale.date))
                        Text(sale.symbol)
                        Text(sale.quantity.formatted())
                        Text(sale.name ?? "").lineLimit(1)
                        Text(sale.proceeds.fullString)
                        Text(sale.gain.fullString)
                    }
                }
            }
        }
    }
}

struct TaxSales: View {
    @EnvironmentObject var ledger: LedgerManager

    @State private var year: Int = Calendar.current.dateComponents([.year], from: Date()).year! - 1
    @State private var generating = false
    @State private var groupedSales = [String: [Sale]]()

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
                    ForEach(groupedSales.sorted { $0.key < $1.key }, id: \.key) { key, value in
                        Sales(sales: value).tabItem { Text(key) }.padding()
                    }
                }
            }
        }
        .padding()
        .onAppear {
            if !generating {
                generateSales()
            }
        }
        .onChange(of: year) {
            generateSales()
        }
        .onChange(of: ledger.loadingLedger) {
            if ledger.loadingLedger {
                generateSales()
            }
        }
    }

    private func generateSales() {
        generating = true
        Task.detached {
            do {
                Logger.tax.info("Sales Calculation - Start")
                let ledger = try await ledger.getLedgerContent()
                Logger.tax.info("Sales Calculation - Got Ledger")
                let sales = await TaxCalculator.getTaxableSales(from: ledger, for: year)
                Logger.tax.info("Sales Calculation - Got Sales")
                let groupedSales = Dictionary(grouping: sales) { $0.provider }
                DispatchQueue.main.async {
                    self.groupedSales = groupedSales
                    generating = false
                }
                Logger.tax.info("Sales Calculation - Done")
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
    TaxSales().environmentObject(LedgerManager(URL(fileURLWithPath: "/Users/User/Download/Test.beancount")))
}

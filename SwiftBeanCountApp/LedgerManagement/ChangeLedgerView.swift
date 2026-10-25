//
//  ChangeLedger.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-02-17.
//

import SwiftUI

/// Simple view displaying the current ledger name and a button to change it.
/// Only used on compact screens, where there is no sidebar navigation with the ledger info & change button
struct ChangeLedgerView: View {

    @EnvironmentObject var ledger: LedgerManager

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text("Current Ledger:").font(.title3).bold().padding(.bottom)
                    Text(ledger.url?.lastPathComponent ?? "")
                }.padding()
                Spacer()
            }.padding(.horizontal)
            Button(action: {
                ledger.displayLedgerSelector = true
            }, label: {
                Spacer()
                Text("Change")
                Spacer()
            }).padding().buttonStyle(.bordered)
            Spacer()
        }
        .navigationTitle("Ledger")
    }
}

#Preview {
    ChangeLedgerView()
        .environmentObject(LedgerManager(URL(fileURLWithPath: "/Users/User/Download/Test.beancount")))
}

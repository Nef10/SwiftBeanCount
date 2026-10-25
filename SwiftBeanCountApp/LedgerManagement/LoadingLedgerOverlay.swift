//
//  LoadingLedgerOverlay.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-02-19.
//

import SwiftUI

struct LoadingLedgerOverlay: View {

    @EnvironmentObject var ledger: LedgerManager

    var body: some View {
        if ledger.waitingForLedgerLoad {
            GeometryReader { geometry in
                VStack {
                    ProgressView {
                        Text("Loading Ledger").bold().padding(.top)
                    }
                }
                .frame(width: geometry.size.width / 2, height: geometry.size.height / 5)
                .background(Color.secondary.colorInvert())
                .foregroundColor(Color.primary)
                .cornerRadius(20)
                .position(x: geometry.frame(in: .local).midX, y: geometry.frame(in: .local).midY)
            }
        }
    }

}

#Preview {
    LoadingLedgerOverlay()
}

//
//  Exporter.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2026-05-23.
//

import SwiftUI

struct Exporter: View {

    @State private var export: ExportType?

    var body: some View {
        if export == nil {
            ExporterSelectionView(export: $export)
        } else {
            ExporterResultsView($export)
        }
    }

}

#Preview {
    Exporter().environmentObject(LedgerManager(URL(fileURLWithPath: "/Users/User/Download/Test.beancount")))
}

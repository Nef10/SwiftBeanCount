//
//  ExporterSelectionView.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2026-05-23.
//

import SwiftUI

struct ExporterSelectionView: View {

    @Binding var export: ExportType?
    @State private var selectedExporter = ExporterFactory.exporters.first ?? .googleSheets

    var body: some View {
        VStack(alignment: .leading) {
            Text("Select Exporter").font(.headline)
            exporterPicker.padding(.leading).padding(.bottom)
            Spacer()
            actions
        }
        .buttonStyle(.bordered)
        .padding()
    }

    @ViewBuilder private var exporterPicker: some View {
        Picker("Exporter", selection: $selectedExporter) {
            ForEach(ExporterFactory.exporters) { exporter in
                Text(exporter.displayName).tag(exporter)
            }
        }
#if os(macOS)
        .labelsHidden()
        .pickerStyle(.radioGroup)
#else
        .pickerStyle(.inline)
#endif
    }

    private var actions: some View {
        HStack {
            Spacer()
            Button("Start Export") { startExport() }
                .buttonStyle(.borderedProminent)
        }
    }

    private func startExport() {
        export = selectedExporter
    }

}

#Preview {
    ExporterSelectionView(export: .constant(nil)).environmentObject(LedgerManager(URL(fileURLWithPath: "/Users/User/Download/Test.beancount")))
}

//
//  ExporterInputRequestView.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2026-05-23.
//

import SwiftUI

struct ExporterInputRequestView: View {

    let viewModel: ExportInputRequestViewModel

    @State private var input = ""

    private var disableOkButton: Bool {
        if case .choice = viewModel.inputType, input.isEmpty {
            return true
        }
        return false
    }

    var body: some View {
        let prompt = viewModel.inputType == .bool ? viewModel.inputName : "Please provide the requested information"
        let text = "\(prompt) for the following export: \(viewModel.exporterName)"
        VStack(alignment: .leading) {
#if !os(macOS)
            Text("Exporter Input").font(.largeTitle).bold().padding(.vertical)
#endif
            Text(text).padding(.bottom).padding(.trailing)
            if .bool != viewModel.inputType {
                Text(viewModel.inputName).font(.headline)
            }
            switch viewModel.inputType {
            case .bool:
                EmptyView()
            case .secret:
                SecureField(viewModel.inputName, text: $input).textContentType(.password)
            case let .text(suggestions):
                textInputView(suggestions)
            case let .choice(choices):
                Picker(viewModel.inputName, selection: $input) { ForEach(choices, id: \.self) { Text($0).tag($0) } }
#if os(macOS)
                    .labelsHidden()
                    .pickerStyle(.radioGroup)
#else
                    .pickerStyle(.inline)
#endif
            }
            buttons
            Spacer()
        }
        .padding()
        .interactiveDismissDisabled()
    }

    private var buttons: some View {
        HStack {
            Spacer()
            if viewModel.inputType == .bool {
                Button("No") { viewModel.onSubmit?("false") }
                Button("Yes") { viewModel.onSubmit?("true") }
            } else {
                Button("Cancel") { viewModel.onCancel?() }
                Button("OK") { viewModel.onSubmit?(input) }.disabled(disableOkButton).buttonStyle(.borderedProminent)
            }
        }.padding(.top).buttonStyle(.bordered)
    }

    func textInputView(_ suggestions: [String]) -> some View {
        TextField(viewModel.inputName, text: $input)
#if os(macOS)
            .textInputSuggestions {
                if !suggestions.contains(where: { $0.lowercased() == input.lowercased() }) {
                    ForEach(suggestions, id: \.self) { Text($0).textInputCompletion($0) }
                }
            }
#endif
    }

}

#Preview("Secret") {
    ExporterInputRequestView(viewModel:
        ExportInputRequestViewModel(exporterName: "Exporter Name", inputName: "Input text", inputType: .secret, onSubmit: nil, onCancel: nil)
    )
}
#Preview("Text") {
    ExporterInputRequestView(viewModel:
        ExportInputRequestViewModel(exporterName: "Exporter Name",
                                    inputName: "Input text",
                                    inputType: .text(["suggestion1 a little bit longer", "suggestion2"]),
                                    onSubmit: nil,
                                    onCancel: nil)
    )
}
#Preview("Choice") {
    ExporterInputRequestView(viewModel:
        ExportInputRequestViewModel(exporterName: "Exporter Name", inputName: "Input text", inputType: .choice(["choice1", "choice2"]), onSubmit: nil, onCancel: nil)
    )
}
#Preview("Bool") {
    ExporterInputRequestView(viewModel:
        ExportInputRequestViewModel(exporterName: "Exporter Name", inputName: "Input choice", inputType: .bool, onSubmit: nil, onCancel: nil)
    )
}

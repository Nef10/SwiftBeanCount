//
//  ImporterInputRequestView.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-12-12.
//

import SwiftBeanCountImporter
import SwiftUI

struct ImporterInputRequestView: View {

    let viewModel: InputRequestViewModel

    @State private var input = ""

    private var disableOkButton: Bool {
        if case .choice = viewModel.inputType, input.isEmpty {
            return true
        }
        return false
    }

    var body: some View {
        let type = viewModel.inputType
        let text = "\(type == .bool ? viewModel.inputName : "Please provide the requested information") for the following import: \(viewModel.importerName)"
        VStack(alignment: .leading) {
#if !os(macOS)
            Text("Importer Input").font(.largeTitle).bold().padding(.vertical)
#endif
            Text(text).padding(.bottom).padding(.trailing)
            if .bool != type {
                Text(viewModel.inputName).font(.headline)
            }
            switch type {
            case .bool:
                EmptyView() // No other UI, just the buttons
            case .otp:
                TextField(viewModel.inputName, text: $input).textContentType(.oneTimeCode)
            case .secret:
                SecureField(viewModel.inputName, text: $input).textContentType(.password)
            case let .text(suggestions):
                textInputView(suggestions)
            case let .choice(choices):
                Picker(viewModel.inputName, selection: $input) { ForEach(choices, id: \.self) { Text($0).tag($0) } }
            }
            HStack {
                Spacer()
                if type == .bool {
                    Button("No") { viewModel.onSubmit?("false") }
                    Button("Yes") { viewModel.onSubmit?("true") }
                } else {
                    Button("Cancel") { viewModel.onCancel?() }
                    Button("OK") { viewModel.onSubmit?(input) }.disabled(disableOkButton).buttonStyle(.borderedProminent)
                }
            }.padding(.top).buttonStyle(.bordered)
            Spacer()
        }
            .padding()
            .interactiveDismissDisabled()
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
    ImporterInputRequestView(viewModel:
        InputRequestViewModel(importerName: "Importer Name", inputName: "Input text", inputType: .secret, onSubmit: nil, onCancel: nil)
    )
}
#Preview("Text") {
    ImporterInputRequestView(viewModel:
        InputRequestViewModel(importerName: "Importer Name",
                              inputName: "Input text",
                              inputType: .text(["suggestion1 a little bit longer", "suggestion2"]),
                              onSubmit: nil,
                              onCancel: nil)
    )
}
#Preview("Choice") {
    ImporterInputRequestView(viewModel:
        InputRequestViewModel(importerName: "Importer Name", inputName: "Input text", inputType: .choice(["choice1", "choice2"]), onSubmit: nil, onCancel: nil)
    )
}
#Preview("Bool") {
    ImporterInputRequestView(viewModel:
        InputRequestViewModel(importerName: "Importer Name", inputName: "Input choice", inputType: .bool, onSubmit: nil, onCancel: nil)
    )
}
#Preview("OTP") {
    ImporterInputRequestView(viewModel:
        InputRequestViewModel(importerName: "Importer Name", inputName: "Input text", inputType: .otp, onSubmit: nil, onCancel: nil)
    )
}

//
//  GeneralSettingsView.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-12-21.
//

import SwiftBeanCountImporter
import SwiftUI
import UniformTypeIdentifiers

struct GeneralSettingsView: View {

    private struct SettingsFile: FileDocument, Codable {
        static var readableContentTypes = [UTType.json]

        let payees: [String: String]
        let accounts: [String: String]
        let descriptions: [String: String]
        let ignoredPayeeDuplicates: [IgnoredPayeeDuplicatePair]
        let dateTolerance: String

        init(
            payees: [String: String],
            accounts: [String: String],
            descriptions: [String: String],
            ignoredPayeeDuplicates: [IgnoredPayeeDuplicatePair],
            dateTolerance: String
        ) {
            self.payees = payees
            self.accounts = accounts
            self.descriptions = descriptions
            self.ignoredPayeeDuplicates = ignoredPayeeDuplicates
            self.dateTolerance = dateTolerance
        }

        init(data: Data) throws {
            let decoder = JSONDecoder()
            self = try decoder.decode(Self.self, from: data)
        }

        init(configuration: ReadConfiguration) throws {
            if let data = configuration.file.regularFileContents {
                try self.init(data: data)
            } else {
                throw CocoaError(.fileReadCorruptFile)
            }
        }

        func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self)
            return FileWrapper(regularFileWithContents: data)
        }
    }

    @State private var dateTolerance: Int
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isDocumentOpenPickerPresented = false
    @State private var isDocumentSavePickerPresented = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("Importer").bold()
            Stepper(value: $dateTolerance, in: 0...10) {
                HStack {
                    Text("Date tolerance for checking duplicate transactions:")
                    TextField("", value: $dateTolerance, formatter: NumberFormatter()).frame(minWidth: 15, maxWidth: 40)
#if !os(macOS)
                        .textFieldStyle(.roundedBorder)
#endif
                }
            }.onChange(of: dateTolerance) { _, newValue in
                Settings.dateToleranceInDays = newValue
            }
            Text("Import/Export All Settings").bold().padding(.top)
            HStack {
                Button("Import Settings") {
                    isDocumentOpenPickerPresented = true
                }.buttonStyle(.bordered)
                Button("Export Settings") {
                    isDocumentSavePickerPresented = true
                }.buttonStyle(.bordered)
            }
            Spacer()
        }
        .alert("Error", isPresented: $showError) { Button("OK") { /* empty */ } } message: { Text(errorMessage) }
        .fileImporter(
            isPresented: $isDocumentOpenPickerPresented,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: selectFileFromURL
        )
        .fileExporter(isPresented: $isDocumentSavePickerPresented,
                      document: generateSettings(),
                      contentType: .json,
                      defaultFilename: "Settings.json") { _ in
            // do nothing
        }
    }

    init() {
        _dateTolerance = State(initialValue: Settings.dateToleranceInDays)
    }

    private func selectFileFromURL(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let url = urls.first!
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access file"
                showError = true
                return
            }
            do {
                let data = try Data(contentsOf: url)
                let settingsFile = try SettingsFile(data: data)
                apply(settingsFile: settingsFile)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            url.stopAccessingSecurityScopedResource()
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func apply(settingsFile: SettingsFile) {
        // Delete all old mappings
        for (description, _) in Settings.allDescriptionMappings {
            Settings.setDescriptionMapping(key: description, description: nil)
        }
        for (description, _) in Settings.allPayeeMappings {
            Settings.setPayeeMapping(key: description, payee: nil)
        }
        for (description, _) in Settings.allAccountMappings {
            Settings.setAccountMapping(key: description, account: nil)
        }

        // Set new once
        for (description, newDescriptions) in settingsFile.descriptions {
            Settings.setDescriptionMapping(key: description, description: newDescriptions)
        }
        for (description, payee) in settingsFile.payees {
            Settings.setPayeeMapping(key: description, payee: payee)
        }
        for (description, account) in settingsFile.accounts {
            Settings.setAccountMapping(key: description, account: account)
        }
        IgnoredPayeeDuplicateSettings.replaceAll(with: settingsFile.ignoredPayeeDuplicates)
        if let dateTolerance = Int(settingsFile.dateTolerance) {
            Settings.dateToleranceInDays = dateTolerance
            self.dateTolerance = dateTolerance
        }
    }

    private func generateSettings() -> SettingsFile {
        SettingsFile(payees: Settings.allPayeeMappings,
                     accounts: Settings.allAccountMappings,
                     descriptions: Settings.allDescriptionMappings,
                     ignoredPayeeDuplicates: IgnoredPayeeDuplicateSettings.allPairs(),
                     dateTolerance: "\(Settings.dateToleranceInDays)")
    }

}

#Preview {
    GeneralSettingsView().scenePadding()
}

//
//  ImporterSelection.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-12-01.
//

import OSLog
import SwiftBeanCountImporter
import SwiftUI

struct ImporterSelection: View {

#if os(macOS)
    @Environment(\.colorScheme)
    var colorScheme: ColorScheme
#endif

    @Environment(\.openWindow)
    var openWindow

    @Binding private var imports: [ImportType]

    @State private var fileImport = [URL]()
    @State private var textImport = [(String, String)]() // transaction, balance
    @State private var downloadImport: [Bool] = Array(repeating: false, count: ImporterFactory.downloadImporterNames.count)
    @State private var isDocumentPickerPresented = false
    @State private var showTextInputSheet = false
    @State private var textInputTransaction = ""
    @State private var textInputBalance = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

#if !os(macOS)
    @State private var showHelp = false
#endif

    var body: some View {
        VStack(alignment: .leading) {
            Text("Select Input").font(.headline)
            Grid(alignment: .leadingFirstTextBaseline) {
                GridRow {
                    Button("Add File(s)") { isDocumentPickerPresented = true }
                    Text("\(fileImport.count) files selected")
                }
                GridRow {
                    Button("Add Text") { showTextInputSheet = true }
                    Text("\(textImport.count) texts added")
                }
            }.padding(.leading).padding(.bottom)

            Text("Download Input").font(.headline)
            VStack(alignment: .leading) {
                ForEach(Array(ImporterFactory.downloadImporterNames.enumerated()), id: \.element) { index, downloadImporter in
                    Toggle(downloadImporter, isOn: $downloadImport[index])
                }.padding(.leading)
            }.padding(.bottom)

            Spacer()
            HStack {
                Button("?") { openHelp() }.buttonBorderShape(.circle)
                Spacer()
                Button("Reset") { resetInput() }.disabled(fileImport.isEmpty && textImport.isEmpty && downloadImport.allSatisfy { !$0 })
                Button("Generate Transactions") { generate() }
                    .buttonStyle(.borderedProminent)
                    .disabled(fileImport.isEmpty && textImport.isEmpty && downloadImport.allSatisfy { !$0 })
            }
        }.buttonStyle(.bordered)
        .padding()
        .fileImporter(
            isPresented: $isDocumentPickerPresented,
            allowedContentTypes: [.commaSeparatedText, .folder],
            allowsMultipleSelection: true,
            onCompletion: selectFilesFromURLs
        )
        .alert("Error", isPresented: $showErrorAlert) { Button("OK") { /* empty */ } } message: { Text(errorMessage) }
        .sheet(isPresented: $showTextInputSheet) {
            textInputSheet
        }
#if !os(macOS)
        .sheet(isPresented: $showHelp) {
            ImporterHelpView()
        }
#endif
    }

    var textInputSheet: some View {
        VStack {
            HStack {
                VStack {
                    Text("Transaction").font(.headline)
                    TextEditor(text: $textInputTransaction).frame(minHeight: 400).padding(5).overlay(
                        RoundedRectangle(cornerRadius: 8).stroke(.separator)
#if os(macOS)
                            .opacity(colorScheme == .dark ? 0.0 : 0.5)
#else
                            .opacity(0.5)
#endif
                    )
                }
                VStack {
                    Text("Balance").font(.headline)
                    TextEditor(text: $textInputBalance).frame(minHeight: 400).padding(5).overlay(
                        RoundedRectangle(cornerRadius: 8).stroke(.separator)
#if os(macOS)
                            .opacity(colorScheme == .dark ? 0.0 : 0.5)
#else
                            .opacity(0.5)
#endif
                    )
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { closeTextInputSheet() }.buttonStyle(.bordered)
                Button("Add") { addAndCloseTextInput() }.buttonStyle(.borderedProminent)
            }.padding(.top)
        }.padding()
    }

    init(_ imports: Binding<[ImportType]>) {
        self._imports = imports
    }

    private func generate() {
        imports = fileImport.map { ImportType.csv($0) }
            + textImport.map { ImportType.text($0.0, $0.1) }
            + downloadImport.enumerated().compactMap { $0.element ? ImportType.download(ImporterFactory.downloadImporterNames[$0.offset]) : nil }
    }

    private func resetInput() {
        fileImport = []
        textImport = []
        downloadImport = Array(repeating: false, count: ImporterFactory.downloadImporterNames.count)
    }

    private func addAndCloseTextInput() {
        let transactionString = textInputTransaction.trimmingCharacters(in: .whitespacesAndNewlines)
        let balanceString = textInputBalance.trimmingCharacters(in: .whitespacesAndNewlines)
        if !transactionString.isEmpty || !balanceString.isEmpty {
            textImport.append((textInputTransaction, textInputBalance))
        }
        closeTextInputSheet()
    }

    private func closeTextInputSheet() {
        showTextInputSheet = false
        textInputTransaction = ""
        textInputBalance = ""
    }

    private func openHelp() {
#if os(macOS)
        openWindow(id: "importer-help")
#else
        showHelp = true
#endif
    }

    private func csvURLsInDirectory(_ url: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: url,
                                                              includingPropertiesForKeys: [.isDirectoryKey],
                                                              options: [.skipsHiddenFiles],
                                                              errorHandler: { _, error -> Bool in
            errorMessage = error.localizedDescription
            showErrorAlert = true
            return true
        }) else {
            errorMessage = "Could not enumerate directory"
            showErrorAlert = true
            return []
        }
        var urls = [URL]()
        for case let fileURL as URL in enumerator where !fileURL.hasDirectoryPath && fileURL.pathExtension.lowercased() == "csv" {
            urls.append(fileURL)
        }
        return urls
    }

    private func selectFilesFromURLs(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else {
                    errorMessage = "Could not access file"
                    showErrorAlert = true
                    return
                }
                if !url.hasDirectoryPath {
                    fileImport.append(url)
                } else {
                    fileImport.append(contentsOf: csvURLsInDirectory(url))
                }
                url.stopAccessingSecurityScopedResource()
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

#Preview {
    ImporterSelection(.constant([])).environmentObject(LedgerManager(URL(fileURLWithPath: "/Users/User/Download/Test.beancount")))
}

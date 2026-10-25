//
//  Statements.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-10-13.
//

import OSLog
import SwiftBeanCountModel
import SwiftBeanCountStatements
import SwiftUI

#if os(macOS)

struct Statements: View {

    private static let dateFormatterMonth: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/yyyy"
        return dateFormatter
    }()

    private static let dateFormatterYear: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy"
        return dateFormatter
    }()

    private static let dateFormatterQuarter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "QQQ/yyyy"
        return dateFormatter
    }()

    @EnvironmentObject var ledger: LedgerManager

    @State private var generating = false
    @State private var includeClosedAccounts = false
    @State private var startEndDateCheck = false
    @State private var currentStatementCheck = true
    @State private var generatingError: String?
    @State private var results = [AccountName: AccountResult]()
    @State private var keys = [AccountName]()
    @State private var scopedRootURL: URL?

    private let bookmarkKey = "rootDocumentFolderBookmark"

    var body: some View {
        VStack(alignment: .leading) {
            if generatingError == nil {
                HStack {
                    Toggle("Include closed accounts", isOn: $includeClosedAccounts)
                    Toggle("Compare account opening and closing dates against startements", isOn: $startEndDateCheck)
                    Toggle("Check for last statement", isOn: $currentStatementCheck)
                    Button {
                        generate()
                    } label: {
                        if generating {
                            ProgressView().padding(.vertical, 5).controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .accessibilityLabel(Text("Refresh"))
                                .padding(.vertical, 5)
                        }
                    }
                }
            }
            if generating {
                LoadingView()
            } else if let generatingError {
                VStack(alignment: .center) {
                    Text(generatingError)
                    Button("Retry") {
                        generate()
                    }
                }
            } else {
                table
            }
        }
        .padding()
        .onAppear { generate() }
        .onChange(of: includeClosedAccounts) { generate() }
        .onChange(of: startEndDateCheck) { generate() }
        .onChange(of: currentStatementCheck) { generate() }
        .onChange(of: ledger.loadingLedger) {
            if ledger.loadingLedger {
                generate()
            }
        }
    }

    private var table: some View {
        Table(of: StatementResult.self) {
            TableColumn("Document Name", value: \.name).width(min: 120, ideal: 340, max: 450)
            TableColumn("Frequency", value: \.frequency.rawValue).width(min: 60, ideal: 70, max: 100)
            TableColumn("Start") {
                if let date = $0.startDate {
                    Text(formatted(date: date, for: $0.frequency))
                }
            }.width(min: 60, ideal: 60, max: 90)
            TableColumn("End") {
                if let date = $0.endDate {
                    Text(formatted(date: date, for: $0.frequency))
                }
            }.width(min: 60, ideal: 60, max: 90)
            TableColumn("Status") {
                if !$0.errors.isEmpty {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red).accessibilityLabel("Errors")
                } else if !$0.warnings.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow).accessibilityLabel("Warning")
                } else {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityLabel("No Errors")
                }
            }.width(50)
            TableColumn("Errors") { result in
                VStack(alignment: .leading) {
                    ForEach(result.errors + result.warnings, id: \.self) { error in
                        Text(error)
                    }
                }
            }.width(min: 250, ideal: 500, max: 700)
        } rows: {
            ForEach(keys) { accountName in
                let result = results[accountName]!
                Section {
                    ForEach(result.statementResults, id: \.self) { statementResult in
                        TableRow(statementResult)
                    }
                } header: {
                    HStack {
                        Text("\(accountName.fullName) (\(result.folderName))")
                        Button {
                            guard scopedRootURL?.startAccessingSecurityScopedResource() == true else {
                                Logger.files.error("Failed to access scoped root URL")
                                return
                            }
                            defer { scopedRootURL?.stopAccessingSecurityScopedResource() }
                            guard NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: result.folderURL.path) else {
                                Logger.files.error("Failed to open folder in Finder")
                                return
                            }
                        } label: {
                            Image(systemName: "arrow.forward.circle.fill").accessibilityLabel(Text("Open in Finder"))
                        }.buttonStyle(BorderlessButtonStyle())
                    }
                }
            }
        }
    }

    private func formatted(date: Date, for frequency: StatementFrequency) -> String {
        switch frequency {
        case .monthly, .single, .unkown:
            Self.dateFormatterMonth.string(from: date)
        case .quarterly:
            Self.dateFormatterQuarter.string(from: date)
        case .yearly:
            Self.dateFormatterYear.string(from: date)
        }
    }

    private func generate() {
        generating = true
        let showClosedAccounts = includeClosedAccounts
        let showStartEndDateWarnings = startEndDateCheck
        let showCurrentStatementWarning = currentStatementCheck
        Task.detached {
            do {
                let ledger = try await ledger.getLedgerContent()
                let rootFolder = try StatementValidator.getRootFolder(from: ledger)
                guard let scopedRootURL = try await getSecurityScopedURL(for: rootFolder) else {
                    await showError("Failed to read folder")
                    return
                }
                defer { scopedRootURL.stopAccessingSecurityScopedResource() }
                let result = try await StatementValidator.validate(ledger,
                                                                   securityScopedRootURL: scopedRootURL,
                                                                   includeClosedAccounts: showClosedAccounts,
                                                                   includeStartEndDateWarning: showStartEndDateWarnings,
                                                                   includeCurrentStatementWarning: showCurrentStatementWarning)
                await showResults(result, url: scopedRootURL)
            } catch {
                Logger.files.error("\(error.localizedDescription)")
                await showError(error.localizedDescription)
            }
        }
    }

    private func getSecurityScopedURL(for folder: String) async throws -> URL? {
        let scopedRootURL: URL
        var isStale = false
        if let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey),
           let bookmarkUrl = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, bookmarkDataIsStale: &isStale),
            !isStale,
            bookmarkUrl.startAccessingSecurityScopedResource() {
            scopedRootURL = bookmarkUrl
        } else {
            // swiftlint:disable:next legacy_objc_type
            guard let filePickerURL = await showFilePickerForPermissions(url: URL(filePath: NSString(string: folder).expandingTildeInPath)) else {
                return nil
            }
            scopedRootURL = filePickerURL
            let bookmarkData = try scopedRootURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        }
        return scopedRootURL
    }

    @MainActor
    private func showFilePickerForPermissions(url: URL) async -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = false
        openPanel.canChooseFiles = false
        openPanel.prompt = "Grant Access"
        openPanel.directoryURL = url
        let response = await openPanel.begin()
        guard response == .OK, let url = openPanel.url else {
            Logger.files.error("Did not receive URL from file picker")
            return nil
        }
        return url
    }

    @MainActor
    private func showResults(_ results: [AccountName: AccountResult], url: URL) {
        generatingError = nil
        self.results = results
        keys = Array(results.keys).sorted { $0.fullName < $1.fullName }
        scopedRootURL = url
        generating = false
    }

    @MainActor
    private func showError(_ error: String) {
        generatingError = error
        generating = false
    }
}

#if hasFeature(RetroactiveAttribute)
extension AccountName: @retroactive Identifiable {
    public var id: String {
        fullName
    }
}
#else
extension AccountName: Identifiable {
    public var id: String {
        fullName
    }
}

#endif

#Preview {
    Statements().environmentObject(LedgerManager(URL(fileURLWithPath: "/Users/User/Download/Test.beancount")))
}

#endif

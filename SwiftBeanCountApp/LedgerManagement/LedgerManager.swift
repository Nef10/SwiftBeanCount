//
//  LedgerManager.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-02-18.
//

import CryptoKit
import Foundation
import OSLog
import SwiftBeanCountModel
import SwiftBeanCountParser

enum LedgerManagerError: Error {
    case noLedgerSpecified
    case noTask
    case noAccess
}

struct RecentFile: Hashable {
    let url: URL
    let name: String
    let path: String
}

private struct SavedRecentFile: Codable {
    let bookmarkData: Data
    let name: String
    let path: String
}

class LedgerManager: ObservableObject {

    private static let recentsKey = "recents"
    private static let recentsLimit = 5

    @Published var url: URL? {
        didSet {
            if oldValue != url {
                task?.cancel()
                loadLedger()
            }
        }
    }
    @Published var displayLedgerSelector = false
    @Published var waitingForLedgerLoad = false
    @Published private(set) var loadingLedger = false

    private var ledgerLoaded = false
    private var task: Task<(SHA256.Digest, Ledger), Error>?

    // paramters only used for previews
    init(_ ledgerURL: URL? = nil, waitingForLedgerLoad: Bool = false) {
        self.url = ledgerURL
        self.waitingForLedgerLoad = waitingForLedgerLoad
    }

    public static func lastURLs() -> [RecentFile] {
#if os(macOS)
        guard let data = UserDefaults.standard.data(forKey: recentsKey), let recents = try? JSONDecoder().decode([SavedRecentFile].self, from: data) else {
            Logger.ledger.warning("Failed to read recents from UserDefaults")
            return []
        }
        return recents.compactMap {
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: $0.bookmarkData, options: .withSecurityScope, bookmarkDataIsStale: &isStale), !isStale else {
                return nil
            }
            return RecentFile(url: url, name: $0.name, path: $0.path)
        }
#else
        return []
#endif
    }

    private static func saveLastURL(_ url: URL) {
#if os(macOS)
        var recents: [SavedRecentFile]!

        if let data = UserDefaults.standard.data(forKey: recentsKey) {
            recents = try? JSONDecoder().decode([SavedRecentFile].self, from: data)
        }
        if recents == nil {
            Logger.ledger.warning("Failed to read recents from UserDefaults - will create a new array")
            recents = []
        }
        guard let bookmarkData = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) else {
            Logger.ledger.error("Failed to create bookmark data for \(url)")
            return
        }
        let save = SavedRecentFile(bookmarkData: bookmarkData, name: url.lastPathComponent, path: url.path)
        // remove if already present
        recents = recents.filter { $0.path != save.path }
        // insert at first position
        recents.insert(save, at: 0)
        // only keep last `recentsLimit` entries
        recents = Array(recents.prefix(recentsLimit))
        guard let data = try? JSONEncoder().encode(recents) else {
            Logger.ledger.error("Failed to encode recents to JSON")
            return
        }
        UserDefaults.standard.set(data, forKey: recentsKey)
#endif
    }

    /// Re-reads the ledger file from disk and checks if the hash
    /// changed. If so it will parse again, otherwise it won't.
    /// If the loading is stil ongoing, it cancles and re-starts.
    public func refresh() {
        if !ledgerLoaded {
            Logger.ledger.info("Canceling running task due to refresh")
            task?.cancel()
            loadLedger()
        } else if let task {
            Task.detached(priority: .background) {
                do {
                    let (hash, _) = try await task.value
                    let (newHash, _) = try self.getHashAndText()
                    if hash != newHash {
                        Logger.ledger.info("Found file change during refresh")
                        self.loadLedger()
                    } else {
                        Logger.ledger.debug("No file change found during refresh")
                    }
                } catch {
                    Logger.ledger.error("\(error.localizedDescription)")
                }
            }
        } else {
            loadLedger()
        }
    }

    /// Gets the content of the currently selected ledger.
    /// It  can check the hash of the current file to the loaded
    /// one, so it does not return content older then when the
    /// method was called.
    /// If parsing needs to happen, it will set the waitingForLedgerLoad variable.
    /// - Parameter skipHashCheck:Skip loading the current file to check the hash
    /// - Returns: Ledger
    public func getLedgerContent(skipHashCheck: Bool = false) async throws -> Ledger {
        guard url != nil else {
            throw LedgerManagerError.noLedgerSpecified
        }
        guard let task else {
            throw LedgerManagerError.noTask
        }
        if !ledgerLoaded || skipHashCheck {
            Task { @MainActor in
                self.waitingForLedgerLoad = true
            }
        }
        defer {
            Task { @MainActor in
                self.waitingForLedgerLoad = false
            }
        }
        let (hash, ledger) = try await task.value
        if skipHashCheck {
            return ledger
        }
        let (newHash, _) = try getHashAndText()
        if hash != newHash {
            Logger.ledger.info("File changed")
            loadLedger()
            return try await getLedgerContent(skipHashCheck: true)
        }
        return ledger
    }

    @discardableResult
    private func loadLedger() -> Task<(SHA256.Digest, Ledger), Error>? {
        task?.cancel()
        Task { @MainActor in
            self.ledgerLoaded = false
        }
        guard url != nil else {
            return nil
        }
        Task { @MainActor in
            self.loadingLedger = true
        }
        task = Task.detached(priority: .background) { () -> (SHA256.Digest, Ledger) in
            Logger.ledger.info("Start loading ledger")
            defer {
                if !Task.isCancelled {
                    Task { @MainActor in
                        self.loadingLedger = false
                    }
                }
            }
            let (hash, text) = try self.getHashAndText()
            try Task.checkCancellation()
            let ledger = Parser.parse(string: text)
            Logger.ledger.debug("Done parsing")
            try Task.checkCancellation()
            self.ledgerLoaded = true
            return (hash, ledger)
        }
        return task
    }

    private func getHashAndText() throws -> (SHA256.Digest, String) {
        guard let url else {
            throw LedgerManagerError.noLedgerSpecified
        }
        guard url.startAccessingSecurityScopedResource() else {
            throw LedgerManagerError.noAccess
        }
        Self.saveLastURL(url)
        let text = try String(contentsOf: url, encoding: .utf8)
        url.stopAccessingSecurityScopedResource()
        let data = Data(text.utf8)
        let hash = SHA256.hash(data: data)
        return (hash, text)
    }

}

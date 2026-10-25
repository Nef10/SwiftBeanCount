//
//  IgnoredPayeeDuplicateSettings.swift
//  SwiftBeanCountApp
//
//  Created by Copilot on 2026-06-06.
//

import Foundation

struct IgnoredPayeeDuplicatePair: Codable, Hashable {

    let payee1: String
    let payee2: String

    init(payee1: String, payee2: String) {
        let trimmedPayee1 = payee1.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPayee2 = payee2.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.shouldSwap(trimmedPayee1, trimmedPayee2) {
            self.payee1 = trimmedPayee2
            self.payee2 = trimmedPayee1
        } else {
            self.payee1 = trimmedPayee1
            self.payee2 = trimmedPayee2
        }
    }

    private static func shouldSwap(_ left: String, _ right: String) -> Bool {
        // too keep consitent when changing locale, do not use localized compare
        // Otherwise, after chaning locale, the order might change, so they would
        // no longer match and show up incorrectly again
        left > right
    }
}

enum IgnoredPayeeDuplicateSettings {

    private static let key = "ignoredPayeeDuplicates"

    static func allPairs() -> [IgnoredPayeeDuplicatePair] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let pairs = try? JSONDecoder().decode([IgnoredPayeeDuplicatePair].self, from: data) else {
            return []
        }
        return normalized(pairs)
    }

    static func allPairsSet() -> Set<IgnoredPayeeDuplicatePair> {
        Set(allPairs())
    }

    static func add(_ pair: IgnoredPayeeDuplicatePair) {
        var pairs = allPairsSet()
        pairs.insert(pair)
        save(Array(pairs))
    }

    static func remove(_ pair: IgnoredPayeeDuplicatePair) {
        var pairs = allPairsSet()
        pairs.remove(pair)
        save(Array(pairs))
    }

    static func replaceAll(with pairs: [IgnoredPayeeDuplicatePair]) {
        save(pairs)
    }

    private static func save(_ pairs: [IgnoredPayeeDuplicatePair]) {
        let normalizedPairs = normalized(pairs)
        guard !normalizedPairs.isEmpty else {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        guard let data = try? JSONEncoder().encode(normalizedPairs) else {
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func normalized(_ pairs: [IgnoredPayeeDuplicatePair]) -> [IgnoredPayeeDuplicatePair] {
        Array(Set(pairs.filter { !$0.payee1.isEmpty && !$0.payee2.isEmpty }))
            .sorted {
                if $0.payee1 == $1.payee1 {
                    return $0.payee2.localizedCaseInsensitiveCompare($1.payee2) == .orderedAscending
                }
                return $0.payee1.localizedCaseInsensitiveCompare($1.payee1) == .orderedAscending
            }
    }
}

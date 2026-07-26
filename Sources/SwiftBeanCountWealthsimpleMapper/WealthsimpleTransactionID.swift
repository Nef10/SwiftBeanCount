//
//  WealthsimpleTransactionID.swift
//  SwiftBeanCountWealthsimpleMapper
//
//  Created by Steffen Kötte on 2026-07-25.
//

import Foundation

enum WealthsimpleTransactionID {

    private static let cardActivityPrefix = "card-activity-"
    private static let postedCardActivityComponentCount = 8

    static func normalized(_ id: String) -> String {
        guard id.hasPrefix(cardActivityPrefix) else {
            return id
        }

        let components = id.split(separator: "-")
        guard components.count == postedCardActivityComponentCount else {
            return id
        }

        return components.dropLast().joined(separator: "-")
    }

    static func normalizedIDs(in value: String) -> Set<String> {
        Set(value.split(separator: " ").map { normalized(String($0)) })
    }
}

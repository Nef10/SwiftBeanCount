import Foundation
import RitualDownloader

/// Receipt description normalization shared by all Ritual import paths.
public enum RitualDescription {

    /// Creates a narration from main item names, excluding variants and packaging prompts.
    static func narration(items: [RitualReceiptItem]) throws -> String {
        guard !items.isEmpty else { throw RitualMappingError.invalidReceipt("Missing items") }
        return try items.compactMap { item -> String? in
            let name = itemName(item.itemName)
            if isPackagingPrompt(name) {
                return nil
            }
            guard item.quantity > 0, !name.isEmpty else { throw RitualMappingError.invalidReceipt("Invalid item") }
            return item.quantity == 1 ? name : "\(item.quantity) × \(name)"
        }
        .joined(separator: "; ")
    }

    private static func isPackagingPrompt(_ name: String) -> Bool {
        let supplies = #"\b(?:bags?|cutlery|utensils?|napkins?|straws?|chopsticks)\b"#
        guard name.range(of: supplies, options: [.regularExpression, .caseInsensitive]) != nil else {
            return false
        }
        let question = #"^(?:(?:would|do|did|will|can)\s+you\b|(?:add|need|want)\b)"#
        return name.contains("?") || name.range(of: question, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private static func itemName(_ original: String) -> String {
        let labelPattern = #"\[GF\]|\(GF\)|\(\s*(?i:delivery|feeds\s+\d+(?:\s*[-–—]\s*\d+)?)\s*\)"#
        let locale = Locale(identifier: "en_CA")
        var name = original.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"(?:\s*(?:\#(labelPattern))\s*)+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"^\d+\)\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*(?:[-–—]\s*)?\d+(?:\.\d+)?\s*[\"″]\s*"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if name.rangeOfCharacter(from: .letters) != nil, name == name.uppercased(with: locale), name != name.lowercased(with: locale) {
            name = name.capitalized(with: locale)
        }
        name = name.replacingOccurrences(of: #"\s*-\s*Ritual\s+Combo\b"#, with: " Combo", options: [.regularExpression, .caseInsensitive])
        return name.split(separator: ";", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "; ")
    }
}

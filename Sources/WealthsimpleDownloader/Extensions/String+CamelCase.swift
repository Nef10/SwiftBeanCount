//
//  String+CamelCase.swift
//
//
//  Created by Steffen Kötte on 2021-09-15.
//

import Foundation

extension String {

    var camelCase: String {
        guard !isEmpty else {
            return ""
        }
        var parts = components(separatedBy: CharacterSet.alphanumerics.inverted)
        return "\(parts.removeFirst().lowercasingFirst)\(parts.map(\.uppercasingFirst).joined())"
    }

    private var uppercasingFirst: Substring {
        prefix(1).uppercased() + dropFirst()
    }

    private var lowercasingFirst: Substring {
        prefix(1).lowercased() + dropFirst()
    }

}

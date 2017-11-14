//
//  String.swift
//  SwiftBeanCountParser
//
//  Created by Steffen Kötte on 2017-06-07.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

extension String {

    // https://stackoverflow.com/q/27880650/3386893
    func matchingStrings(regex: NSRegularExpression) -> [[String]] {
        let nsString = self as NSString
        let results = regex.matches(in: self, options: [], range: NSRange(self.startIndex..., in: self))
        return results.map { result in
            (0..<result.numberOfRanges).map { result.range(at: $0).location != NSNotFound
                ? nsString.substring(with: result.range(at: $0))
                : ""
            }
        }
    }

}

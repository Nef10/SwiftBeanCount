//
//  ParserUtils.swift
//  SwiftBeanCountParser
//
//  Created by Steffen Kötte on 2018-05-26.
//  Copyright © 2018 Steffen Kötte. All rights reserved.
//

import Foundation

/// Constants for parsing a ledger file
enum ParserUtils {

    static let accountGroup = "([^\\s]+:[^\\s]+)"
    static let decimalGroup = "([-+]?[0-9]+(,[0-9]{3})*(.[0-9]+)?)"
    static let commodityGroup = "([^\\s]+)"
    static let amountGroup = "\(decimalGroup)\\s+\(commodityGroup)"

}

//
//  Option.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2020-05-18.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation

/// Option to control bahaviour of Beancount
public struct Option {

    /// name of the option
    public let name: String
    /// value the option should be set to
    public let value: String

}

extension Option: CustomStringConvertible {

    public var description: String {
        "option \"\(name)\" \"\(value)\""
    }

}

extension Option: Comparable {

    public static func < (lhs: Option, rhs: Option) -> Bool {
        String(describing: lhs) < String(describing: rhs)
    }

}

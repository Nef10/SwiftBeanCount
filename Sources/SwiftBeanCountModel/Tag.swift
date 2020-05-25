//
//  Tag.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-10.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

/// A Tag is just a `String` which can be attatched to a `Transaction`
public struct Tag {

    /// the name of the tag without the leading **#**
    public let name: String

    /// Creates a tag
    ///
    /// - Parameter name:  the name of the tag, should be without the leading **#**
    public init(name: String) {
        self.name = name
    }

}

extension Tag: CustomStringConvertible {

    /// the string of how to represent the tag in the ledger file, e.g. with **#** at the beginning
    public var description: String { "#\(name)" }

}

extension Tag: Comparable {

    /// Compares the name of two tags
    ///
    /// - Parameters:
    ///   - lhs: first tag
    ///   - rhs: second tag
    /// - Returns: if the name of tag 1 is < name of tag 2
    public static func < (lhs: Tag, rhs: Tag) -> Bool {
        lhs.name < rhs.name
    }

    /// Compares the name of two tags
    ///
    /// - Parameters:
    ///   - lhs: first tag
    ///   - rhs: second tag
    /// - Returns: if name of both tags match
    public static func == (lhs: Tag, rhs: Tag) -> Bool {
        lhs.name == rhs.name
    }

}

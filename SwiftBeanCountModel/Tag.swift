//
//  Tag.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-10.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

public class Tag {

    public let name: String

    public init(name: String) {
        self.name = name
    }

}

extension Tag: CustomStringConvertible {
    public var description: String { return "#\(name)" }
}

extension Tag: Comparable {

    public static func < (lhs: Tag, rhs: Tag) -> Bool {
        return lhs.name < rhs.name
    }

    public static func == (lhs: Tag, rhs: Tag) -> Bool {
        return lhs.name == rhs.name
    }

}

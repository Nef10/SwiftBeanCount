//
//  Tag.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-10.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

class Tag {

    let name: String

    init(name: String) {
        self.name = name
    }

}

extension Tag : CustomStringConvertible {
    var description: String { return "#\(name)" }
}

extension Tag : Comparable {

    static func < (lhs: Tag, rhs: Tag) -> Bool {
        return lhs.name < rhs.name
    }

    static func == (lhs: Tag, rhs: Tag) -> Bool {
        return lhs.name == rhs.name
    }

}

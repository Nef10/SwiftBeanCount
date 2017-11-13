//
//  Flag.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2017-06-10.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

public enum Flag: String {
    case complete = "*"
    case incomplete = "!"
}

extension Flag: CustomStringConvertible {
    public var description: String { return self.rawValue }
}

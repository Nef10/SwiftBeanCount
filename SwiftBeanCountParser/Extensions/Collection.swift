//
//  Collection.swift
//  SwiftBeanCountParser
//
//  Created by Steffen Kötte on 2017-06-07.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

extension Collection {

    /// Returns the element at the specified index iff it is within bounds, otherwise nil.
    /// https://stackoverflow.com/a/30593673/3386893
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }

}

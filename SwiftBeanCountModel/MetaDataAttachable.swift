//
//  MetaDataAttachable.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2019-09-25.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation

/// protocol for types where meta data can be attached
public protocol MetaDataAttachable {

    /// meta data in form of a string to string dict
    var metaData: [String: String] { get set }
}

//
//  MetaDataAttachable.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2019-09-25.
//  Copyright © 2019 Steffen Kötte. All rights reserved.
//

import Foundation

protocol MetaDataAttachable {
    var metaData: [String: String] { get set }
}

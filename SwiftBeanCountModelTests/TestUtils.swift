//
//  TestUtils.swift
//  SwiftBeanCountModelTests
//
//  Created by Steffen Kötte on 2020-05-22.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation
import SwiftBeanCountModel

enum TestUtils {

    static var date20170610: Date = {
        Date(timeIntervalSince1970: 1_497_078_000)
    }()

    static var date20170609: Date = {
        Date(timeIntervalSince1970: 1_496_991_600)
    }()

    static var date20170608: Date = {
        Date(timeIntervalSince1970: 1_496_905_200)
    }()

    static var cad: Commodity = {
        Commodity(symbol: "CAD")
    }()

    static var eur: Commodity = {
        Commodity(symbol: "EUR")
    }()

    static var usd: Commodity = {
        Commodity(symbol: "USD")
    }()

}

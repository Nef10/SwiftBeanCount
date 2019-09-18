//
//  TestUtils.swift
//  SwiftBeanCountParserTests
//
//  Created by Steffen Kötte on 2017-09-02.
//  Copyright © 2017 Steffen Kötte. All rights reserved.
//

import Foundation

enum TestUtils {

    static let calendar = Calendar.current

    static var date20170608: Date = {
        var dateComponents = DateComponents()
        dateComponents.year = 2_017
        dateComponents.month = 6
        dateComponents.day = 8
        dateComponents.timeZone = TimeZone.current
        return calendar.date(from: dateComponents)!
    }()

    static var date20170609: Date = {
        var dateComponents = DateComponents()
        dateComponents.year = 2_017
        dateComponents.month = 6
        dateComponents.day = 9
        dateComponents.timeZone = TimeZone.current
        return calendar.date(from: dateComponents)!
    }()

    static var date20170610: Date = {
        var dateComponents = DateComponents()
        dateComponents.year = 2_017
        dateComponents.month = 6
        dateComponents.day = 10
        dateComponents.timeZone = TimeZone.current
        return calendar.date(from: dateComponents)!
    }()

}

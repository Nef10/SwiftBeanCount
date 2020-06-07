//
//  Settings.swift
//  SwiftBeanCountImporter
//
//  Created by Steffen Kötte on 2020-05-10.
//  Copyright © 2020 Steffen Kötte. All rights reserved.
//

import Foundation

/// Constants releated to settings of the importer
public enum Settings {

    /// `UserDefaults` key for the payee mapping
    public static let payeesUserDefaultKey = "payees"
    /// `UserDefaults` key for the account mapping
    public static let accountsUserDefaultsKey = "accounts"
    /// `UserDefaults` key for the description mapping
    public static let descriptionUserDefaultsKey = "description"
    /// `UserDefaults` key for the date tolerance to detect duplicate transactions
    public static let dateToleranceUserDefaultsKey = "date_tolerance"

    /// Default date tolerance to detect duplicate transactions
    public static let defaultDateTolerance = 2 // days

    static let defaultAccountName = "Expenses:TODO"
    static let fallbackCommodity = "CAD"

}

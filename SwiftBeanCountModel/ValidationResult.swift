//
//  ValidationResult.swift
//  SwiftBeanCountModel
//
//  Created by Steffen Kötte on 2018-05-20.
//  Copyright © 2018 Steffen Kötte. All rights reserved.
//

import Foundation

/// Result of a validation
///
/// - valid: the tested object is valid
/// - invalid: the tested object is invalid, including an error message
enum ValidationResult {

    case valid
    case invalid(String)

}

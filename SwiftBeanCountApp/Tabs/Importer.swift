//
//  Importer.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-12-18.
//

import Foundation
import SwiftUI

enum ImportType: Equatable, Codable, Hashable {
    case csv(URL) // import file URL
    case text(String, String) // transaction, balance
    case download(String) // importer name
}

struct Importer: View {

    @State private var imports: [ImportType] = []

    var body: some View {
        if imports.isEmpty {
            ImporterSelection($imports)
        } else {
            ImporterResultsView($imports)
        }
    }

}

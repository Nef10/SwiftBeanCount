//
//  LoadingView.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-03-31.
//

import SwiftUI

struct LoadingView: View {

    @Binding var message: String?

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                ProgressView().padding()
                Spacer()
            }
            if let message {
                Text(message)
            }
            Spacer()
        }
    }

    init(message: Binding<String?>? = nil) {
        self._message = message ?? .constant(nil)
    }
}

#Preview {
    LoadingView(message: .constant("Test Message"))
}

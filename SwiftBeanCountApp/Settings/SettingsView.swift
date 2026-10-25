//
//  SettingsView.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-12-20.
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {

    var body: some View {
#if os(macOS)
        TabView {
            SwiftUI.Tab("General", systemImage: "gear") {
                settingsContainer {
                    GeneralSettingsView()
                }
            }
            SwiftUI.Tab("Description Mapping", image: "DescriptionMapping") {
                settingsContainer {
                    SettingsTableView<DescriptionPayeeMapping>()
                }
            }
            SwiftUI.Tab("Account Mapping", image: "AccountMapping") {
                settingsContainer {
                    SettingsTableView<PayeeAccountMapping>()
                }
            }
            SwiftUI.Tab("Ignored Duplicates", systemImage: "xmark.circle") {
                settingsContainer {
                    SettingsTableView<IgnoredPayeeDuplicateMapping>()
                }
            }
        }
        .frame(minWidth: 900, minHeight: 500)
#else
        NavigationSplitView {
            List {
                NavigationLink {
                    GeneralSettingsView().padding()
                } label: {
                    Text("General")
                }
                NavigationLink {
                    SettingsTableView<DescriptionPayeeMapping>().padding()
                } label: {
                    Text("Description Mapping")
                }
                NavigationLink {
                    SettingsTableView<PayeeAccountMapping>().padding()
                } label: {
                    Text("Account Mapping")
                }
                NavigationLink {
                    SettingsTableView<IgnoredPayeeDuplicateMapping>().padding()
                } label: {
                    Text("Ignored Duplicates")
                }
            }
            .navigationTitle("Settings")
        } detail: {
            Text("Select a Settings option")
        }
#endif
    }

    @ViewBuilder
    private func settingsContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack {
            VStack {
                content()
                Spacer()
            }
            Spacer()
        }
        .padding()
    }

}

#Preview {
    SettingsView()
}

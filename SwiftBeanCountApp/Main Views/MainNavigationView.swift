//
//  ContentView.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-02-17.
//

import SwiftUI

/// This view is displaying the main navigation.
///
/// On compact screen widths, this will be a tab view,
/// on all other devices a navigation split view (side bar).
/// It also syncs the selected option when resizing the app so
/// it switches between the size classes.
///
/// For the tab view, it dispalys and additional tab to change
/// the ledger, otherwise this is displayed at the bottom of the
/// side bar.
/// Lastly, it also injects the welcome view if no option is selected
/// (not applicable to tab view).
struct MainNavigationView: View {

    @EnvironmentObject var ledger: LedgerManager
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

    @State private var activeTab: Int?

    private let tabs: [Tab]

    private var toolbarItem: ToolbarItem<(), some View> {
        ToolbarItem(placement: .primaryAction) {
            Button {
                ledger.refresh()
            } label: {
                if ledger.loadingLedger {
                    ProgressView()
#if os(macOS)
                        .controlSize(.small)
#endif
                } else {
                    Image(systemName: "arrow.clockwise")
                        .accessibilityLabel(Text("Refresh Ledger"))
                }
            }.disabled(ledger.loadingLedger)
        }
    }

    var body: some View {
        if horizontalSizeClass == .compact {
            TabView(selection: $activeTab) {
                ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                    NavigationStack {
                        tab.view
                            .navigationTitle(tab.title)
                            .toolbar {
                                toolbarItem
                            }
                    }
                    .tabItem {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .tag(index as Int?)
                }
            }
        } else {
            NavigationSplitView {
                List(Array(tabs.enumerated()), id: \.element.id, selection: $activeTab) { index, tab in
                    NavigationLink(value: index) {
                        Label(tab.title, systemImage: tab.icon)
                    }
                }

                VStack {
#if os(macOS)
                    Divider().padding(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
#endif
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Ledger:")
                            Text(ledger.url?.lastPathComponent ?? "")
                        }
                        Spacer()
                    }
                    Button(action: {
                        ledger.displayLedgerSelector = true
                    }, label: {
                        Text("Change")
                    }).padding(EdgeInsets(top: 5, leading: 0, bottom: 0, trailing: 0))
                }.padding()
            } detail: {
                Group {
                    if let activeTab {
                        tabs[activeTab].view.navigationTitle(tabs[activeTab].title)
                    } else {
                        WelcomeView {
                            Text("To get started, select an option from the menu on the left.")
                                .font(.title3)
                        }
                    }
                }.toolbar {
                    toolbarItem
                }
            }
        }
    }

    init(_ tabs: [Tab]) {
        self.tabs = tabs
    }
}

#Preview {
    MainNavigationView([
        Tab(title: "Import", icon: "square.and.arrow.down", view: AnyView(Text("Import"))),
        Tab(title: "Export", icon: "square.and.arrow.up", view: AnyView(Text("Export")))
    ]).environmentObject(LedgerManager(URL(fileURLWithPath: "/Users/User/Download/Test.beancount")))
#if os(macOS)
        .frame(width: 900, height: 600)
#endif
}

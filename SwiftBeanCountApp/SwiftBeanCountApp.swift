//
//  SwiftBeanCountApp.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-02-17.
//

import SwiftUI

struct Tab: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let view: AnyView
}

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ _: NSApplication) -> Bool {
        true
    }
}
#endif

@main
struct SwiftBeanCountApp: App {

#if os(macOS)
    // Needed for the code above to run - close the application when the last window is closed
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
#endif

    @StateObject private var ledger = LedgerManager()

    private let initializedTabs: [Tab]

    var tabs: [Tab] { // Register all tab views here
        initializedTabs
    }

    var body: some Scene {

        let content = LedgerSelectionWrapperView(tabs).environmentObject(ledger)

#if os(macOS)
        Window("SwiftBeanCountApp", id: "main") { content }.handlesExternalEvents(matching: ["*"])
        Window("Importer Help", id: "importer-help") { ImporterHelpView() }
#else
        WindowGroup { content }
#endif

#if os(macOS)
       Settings {
           SettingsView()
       }
#endif
    }

    init() {
        var tabs = [
            Tab(title: "Tax Slips", icon: "text.page", view: AnyView(TaxSlips())),
            Tab(title: "Tax Sales", icon: "banknote", view: AnyView(TaxSales())),
            Tab(title: "Payees", icon: "person.2", view: AnyView(Payees())),
            Tab(title: "Importer", icon: "square.and.arrow.down.on.square", view: AnyView(Importer())),
            Tab(title: "Export", icon: "square.and.arrow.up.on.square", view: AnyView(Exporter())),
        ]
#if os(macOS)
        tabs += [
            Tab(title: "Statements", icon: "doc.text", view: AnyView(Statements())),
        ]
#else
        tabs += [
            Tab(title: "Ledger", icon: "doc.fill", view: AnyView(ChangeLedgerView())),
            Tab(title: "Settings", icon: "gear", view: AnyView(SettingsView())),
        ]
#endif
        initializedTabs = tabs
    }

}

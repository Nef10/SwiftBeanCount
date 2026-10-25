//
//  ImporterHelpView.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2021-09-13.
//

import SwiftBeanCountImporter
import SwiftUI

struct HelpTextView: View {

    let title: String
    let content: String

#if !os(macOS)
    let dismiss: DismissAction?
#endif

    var body: some View {
        ScrollView {
            Text(content).padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .navigationTitle(title)
#if !os(macOS)
        .toolbar {
            Button(role: .close) {
                dismiss?()
            }
        }
#endif
    }
}

struct ImporterHelpView: View {

#if !os(macOS)
    @Environment(\.dismiss)
    var dismiss
#endif

    var body: some View {
#if os(macOS)
        NavigationSplitView {
            list
        } detail: {
            Text("Select an importer to see its help text.").frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 500, idealWidth: 700, maxWidth: .infinity, minHeight: 300, idealHeight: 500, maxHeight: .infinity, alignment: .center)
#else
        NavigationStack {
            list.toolbar {
                Button(role: .close) {
                    dismiss()
                }
            }
        }
#endif
    }

    var list: some View {
        List(ImporterFactory.allImporters.indices, id: \.self) { index in
            NavigationLink(ImporterFactory.allImporters[index].importerName, value: index)
        }
        .navigationDestination(for: Int.self) { index in
#if os(macOS)
            HelpTextView(title: ImporterFactory.allImporters[index].importerName,
                         content: ImporterFactory.allImporters[index].helpText)
#else
            HelpTextView(title: ImporterFactory.allImporters[index].importerName,
                         content: ImporterFactory.allImporters[index].helpText,
                         dismiss: dismiss)
#endif
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("Importer Help")
    }
}

#Preview("HelpTextView", traits: .sizeThatFitsLayout) {
#if os(macOS)
    HelpTextView(title: "Title", content: "ABC\ndef\n\ngh")
#else
    HelpTextView(title: "Title", content: "ABC\ndef\n\ngh", dismiss: nil)
#endif
}

#Preview("ImporterHelpView") {
    ImporterHelpView()
}

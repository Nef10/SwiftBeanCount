//
//  SettingsTableView.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-12-21.
//

import SwiftBeanCountImporter
import SwiftUI

struct SettingsTableView<T: SettingsTableViewDataSource>: View {

    @State private var allData = [T]()
    @State private var searchText = ""
    @State private var selected: T.ID?
    @State private var editing: T.ID?
    @State private var showDiscardAlert = false
    @State private var value1 = ""
    @State private var value2 = ""
    @State private var pendingEdit: T?
    @State private var pendingSelection: T.ID?
    @State private var pendingDelete: T.ID?

    @State private var sortOrder = [
        KeyPathComparator(\T.key),
    ]

    private var data: [T] {
        var data = allData
        if !searchText.isEmpty {
            data = data.filter { mapping in
                mapping.key.lowercased().contains(searchText.lowercased()) ||
                mapping.value1.lowercased().contains(searchText.lowercased()) ||
                mapping.value2.lowercased().contains(searchText.lowercased())
            }
        }
        return data
    }

    var body: some View {
        HStack {
            Spacer()
            TextField("Search", text: $searchText).textFieldStyle(.roundedBorder).frame(maxWidth: 300)
        }
        Table(
            of: T.self,
            selection: $selected,
            sortOrder: $sortOrder,
            columns: {
                TableColumn(T.keyName, value: \.key)
                TableColumn(T.value1Name, value: \.value1) {
                    if editing == $0.id {
                        TextField(T.value1Name, text: $value1).onSubmit { endEditing() }
#if os(macOS)
                            .textFieldStyle(.squareBorder)
#endif
                    } else {
                        Text($0.value1)
                    }
                }
                if T.hasValue2 {
                    TableColumn(T.value2Name, value: \.value2) {
                        if editing == $0.id {
                            TextField(T.value2Name, text: $value2).onSubmit { endEditing() }
#if os(macOS)
                            .textFieldStyle(.squareBorder)
#endif
                        } else {
                            Text($0.value2)
                        }
                    }
                }
            }, rows: {
                ForEach(data) { mapping in
                    TableRow(mapping)
                }
            }
        )
        .contextMenu(forSelectionType: T.ID.self) { ids in
            let items = ids.map { id in allData.first { $0.id == id } }
            if let item = items.first {
                if T.isEditable {
                    Button("Edit") { edit(item!) }.keyboardShortcut(.defaultAction)
                }
                Button("Delete", role: .destructive) { delete(item!.id) }.keyboardShortcut(.delete)
            } else {
                EmptyView()
            }
        } primaryAction: { ids in
            guard T.isEditable else {
                return
            }
            let items = ids.map { id in allData.first { $0.id == id } }
            if let item = items.first {
                edit(item!)
            }
        }
        .onChange(of: sortOrder) { allData.sort(using: sortOrder) }
        .onChange(of: selected) { _, newValue in
            if selected != nil {
                if !endEditing(discard: true) {
                    pendingSelection = newValue
                }
            }
        }
        .task { loadData() }
#if os(macOS)
        .tableStyle(.bordered)
        .onDeleteCommand {
            if let selected {
                delete(selected)
            }
        }
#endif
        .onKeyPress(.return) {
            guard T.isEditable else {
                return .ignored
            }
            if let editing, editing == selected {
                endEditing()
                return .handled
            }
            if let selected, let mapping = allData.first(where: { $0.id == selected }) {
                edit(mapping)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.escape) {
            if editing != nil {
                endEditing(discard: true)
                return .handled
            }
            return .ignored
        }
        .alert("Discard Changes", isPresented: $showDiscardAlert) {
            Button("No") {
                pendingEdit = nil
                pendingSelection = nil
                pendingDelete = nil
            }
            Button("Yes") { endEditing(discard: true, confirmDiscard: true) }
        } message: {
            Text("Do you want to discard your changes?")
        }
    }

    private func loadData(keepSelection: Bool = false) {
        let selectedKey = allData.first { $0.id == selected }?.key
        let result = T.load()
        allData = result.sorted(using: sortOrder)
        if keepSelection, let selectedKey {
            selected = allData.first { $0.key == selectedKey }.map(\.id)
        }
    }

    private func delete(_ id: T.ID) {
        guard let mapping = allData.first(where: { $0.id == id }) else {
            return
        }
        if editing != nil {
            guard endEditing(discard: true, refresh: false) else {
                pendingDelete = mapping.id
                return
            }
        }
        mapping.delete()
        loadData()
    }

    private func edit(_ mapping: T) {
        guard endEditing(discard: true, refresh: false) else {
            pendingEdit = mapping
            return
        }
        selected = mapping.id
        value1 = mapping.value1
        value2 = mapping.value2
        editing = mapping.id
        selected = nil // force table row refresh..
    }

    @discardableResult
    private func endEditing(discard: Bool = false, confirmDiscard: Bool = false, refresh: Bool = true) -> Bool {
        guard let editing else {
            return true
        }
        if discard && !confirmDiscard {
            let originalValue1 = allData.first { $0.id == editing }?.value1
            let originalValue2 = allData.first { $0.id == editing }?.value2
            if let originalValue1, let originalValue2, originalValue1 != value1 || originalValue2 != value2 {
                showDiscardAlert = true
                return false
            }
        }
        if !discard, let mapping = allData.first(where: { $0.id == editing }) {
            mapping.setValue1(value1)
            mapping.setValue2(value2)
        }
        self.editing = nil
        if refresh && pendingEdit == nil && pendingSelection == nil && pendingDelete == nil {
            loadData(keepSelection: true)
        }
        if let pendingEdit {
            self.pendingEdit = nil
            edit(pendingEdit)
        } else if let pendingSelection {
            self.pendingSelection = nil
            selected = pendingSelection
        } else if let pendingDelete {
            self.pendingDelete = nil
            delete(pendingDelete)
        }
        return true
    }

}

#Preview {
    SettingsTableView<DescriptionPayeeMapping>().padding()
}

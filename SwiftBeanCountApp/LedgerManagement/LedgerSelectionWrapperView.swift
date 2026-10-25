//
//  LedgerSelectionView.swift
//  SwiftBeanCountApp
//
//  Created by Steffen Kötte on 2024-02-17.
//

import OSLog
import SwiftBeanCountModel
import SwiftUI
import UniformTypeIdentifiers

/// Forces the user to select a ledger before showing the MainNavigationView
struct LedgerSelectionWrapperView: View {

    @EnvironmentObject var ledger: LedgerManager

    private let tabs: [Tab]

    var body: some View {
        Group {
            if ledger.url != nil {
#if !os(macOS)
                MainNavigationView(tabs)
                        .disabled(ledger.waitingForLedgerLoad)
                        .blur(radius: ledger.waitingForLedgerLoad ? 3 : 0)
                        .overlay {
                            LoadingLedgerOverlay()
                        }
#else
                MainNavigationView(tabs)
#endif
            } else {
                WelcomeView {
                    VStack {
                        Text("To get started, open a ledger.").font(.title3)
                        Button {
                            ledger.displayLedgerSelector = true
                        } label: {
                            Text("Open ledger")
                        }.padding().buttonStyle(.borderedProminent)
                        if !LedgerManager.lastURLs().isEmpty {
                            recents
                        }
                    }
                }
            }
        }
        .onOpenURL { url in
            ledger.url = url
        }
        .fileImporter(isPresented: $ledger.displayLedgerSelector,
                      allowedContentTypes: [UTType(filenameExtension: "beancount")!]) { result in
            switch result {
            case .success(let url):
                ledger.url = url
            case .failure(let error):
                Logger.ledger.error("\(error.localizedDescription)")
            }
        }
#if os(macOS)
        .sheet(isPresented: $ledger.waitingForLedgerLoad) {
            Text("Loading Ledger")
                .frame(width: 200, height: 50)
                .interactiveDismissDisabled(true)
        }
#endif
    }

    var recents: some View {
        Group {
            HStack {
                Text("Recents").font(.title2).padding(.top)
                Spacer()
            }
            VStack {
                ForEach(Array(LedgerManager.lastURLs().enumerated()), id: \.element) { index, element in
                    Button {
                        ledger.url = element.url
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(element.name).bold()
                                Text(element.path).font(.subheadline)
                            }
                            Spacer()
                        }.contentShape(Rectangle())
                    }.buttonStyle(PlainButtonStyle())
                    if index < LedgerManager.lastURLs().count - 1 {
                        Divider()
                    }
                }
            }.padding(10).background(.black.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    init(_ tabs: [Tab]) {
        self.tabs = tabs
    }
}

#Preview {
    LedgerSelectionWrapperView([
        Tab(title: "Import", icon: "square.and.arrow.down", view: AnyView(Text("Import"))),
        Tab(title: "Export", icon: "square.and.arrow.up", view: AnyView(Text("Export")))
    ]).frame(width: 500, height: 900).environmentObject(LedgerManager(URL(fileURLWithPath: "/Users/User/Download/Test.beancount")))
}

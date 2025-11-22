//
//  ChatTabView.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/20/25.
//

import SwiftData
import SwiftUI

struct ChatTabView: View {
    @State private var selectedChat: ChatHistory?

    var body: some View {
        // Warning: this is a bug that if we do not include the detail in the
        // navigation split view, will trigger swiftui runtime error
        // FAULT: NSInternalInconsistencyException: Cannot unregister separator item because it was not previously successfully registered
        NavigationSplitView(columnVisibility: .constant(.detailOnly)) {
            ChatHistorySidebarView(selectedChat: $selectedChat)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } content: {
            ChatDetailView(chat: selectedChat)
        } detail: {
            VStack {}
                .navigationSplitViewColumnWidth(
                    min: 0, ideal: 0, max: 0
                )
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: ChatHistory.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    return ChatTabView()
        .modelContainer(container)
}

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
        NavigationSplitView {
            ChatHistorySidebarView(selectedChat: $selectedChat)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        } detail: {
            ChatDetailView(chat: selectedChat)
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

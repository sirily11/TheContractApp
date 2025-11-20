//
//  ChatDetailView.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/20/25.
//

import SwiftData
import SwiftUI

struct ChatDetailView: View {
    let chat: ChatHistory?

    var body: some View {
        if let chat = chat {
            VStack {
                Text("Chat implementation coming soon")
                    .foregroundColor(.secondary)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "No Chat Selected",
                systemImage: "bubble.right",
                description: Text("Select a chat from the sidebar or create a new one")
            )
        }
    }
}

#Preview("With Chat") {
    let container = try! ModelContainer(
        for: ChatHistory.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let chat = ChatHistory(title: "Test Chat", messages: [])
    container.mainContext.insert(chat)

    return ChatDetailView(chat: chat)
        .modelContainer(container)
}

#Preview("No Chat") {
    ChatDetailView(chat: nil)
}

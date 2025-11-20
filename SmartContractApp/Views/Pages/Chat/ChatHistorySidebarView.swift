//
//  ChatHistorySidebarView.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/20/25.
//

import SwiftData
import SwiftUI

struct ChatHistorySidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatHistory.updatedAt, order: .reverse) private var allChats: [ChatHistory]
    @Binding var selectedChat: ChatHistory?

    @State private var displayLimit: Int = 50
    @State private var chatToRename: ChatHistory?
    @State private var newChatTitle: String = ""

    var body: some View {
        List(selection: $selectedChat) {
            if !past7DaysChats.isEmpty {
                Section("Past 7 Days") {
                    ForEach(past7DaysChats) { chat in
                        chatRow(chat)
                    }
                }
            }

            if !past30DaysChats.isEmpty {
                Section("Past 30 Days") {
                    ForEach(past30DaysChats) { chat in
                        chatRow(chat)
                    }
                }
            }

            if !olderChats.isEmpty {
                Section("Older") {
                    ForEach(olderChats) { chat in
                        chatRow(chat)
                    }
                }
            }

            if hasMoreChats {
                Section {
                    Button {
                        loadMore()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Load More")
                                .foregroundColor(.accentColor)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Chat History")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createNewChat()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier(.chat.addButton)
            }
        }
        .overlay {
            if allChats.isEmpty {
                ContentUnavailableView(
                    "No Chats",
                    systemImage: "bubble.right",
                    description: Text("Create a new chat to get started")
                )
            }
        }
        .alert("Rename Chat", isPresented: .init(
            get: { chatToRename != nil },
            set: { if !$0 { chatToRename = nil } }
        )) {
            TextField("Chat name", text: $newChatTitle)
            Button("Cancel", role: .cancel) {
                chatToRename = nil
            }
            Button("Rename") {
                renameChat()
            }
        } message: {
            Text("Enter a new name for this chat")
        }
    }

    // MARK: - Computed Properties

    private var displayedChats: [ChatHistory] {
        Array(allChats.prefix(displayLimit))
    }

    private var past7DaysChats: [ChatHistory] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return displayedChats.filter { $0.updatedAt >= sevenDaysAgo }
    }

    private var past30DaysChats: [ChatHistory] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return displayedChats.filter { $0.updatedAt < sevenDaysAgo && $0.updatedAt >= thirtyDaysAgo }
    }

    private var olderChats: [ChatHistory] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return displayedChats.filter { $0.updatedAt < thirtyDaysAgo }
    }

    private var hasMoreChats: Bool {
        allChats.count > displayLimit
    }

    // MARK: - Views

    @ViewBuilder
    private func chatRow(_ chat: ChatHistory) -> some View {
        NavigationLink(value: chat) {
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.title)
                    .font(.body)
                    .lineLimit(1)
            }
            .padding(.vertical, 4)
        }
        .contextMenu {
            Button {
                chatToRename = chat
                newChatTitle = chat.title
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .accessibilityIdentifier(.chat.renameButton)

            Button(role: .destructive) {
                deleteChat(chat)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .accessibilityIdentifier(.chat.row(chat.id.uuidString))
    }

    // MARK: - Actions

    private func createNewChat() {
        let newChat = ChatHistory(
            title: "New Chat",
            messages: []
        )
        modelContext.insert(newChat)
        selectedChat = newChat
    }

    private func deleteChat(_ chat: ChatHistory) {
        if selectedChat == chat {
            selectedChat = nil
        }
        modelContext.delete(chat)
    }

    private func renameChat() {
        guard let chat = chatToRename else { return }
        let trimmedTitle = newChatTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            chat.title = trimmedTitle
            chat.updatedAt = Date()
        }
        chatToRename = nil
    }

    private func loadMore() {
        displayLimit += 50
    }
}

#Preview {
    let container = try! ModelContainer(
        for: ChatHistory.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    // Add sample data
    let context = container.mainContext
    for i in 0 ..< 10 {
        let chat = ChatHistory(
            title: "Chat \(i + 1)",
            messages: [],
            updatedAt: Calendar.current.date(byAdding: .day, value: -i * 3, to: Date()) ?? Date()
        )
        context.insert(chat)
    }

    return NavigationStack {
        ChatHistorySidebarView(selectedChat: .constant(nil))
    }
    .modelContainer(container)
}

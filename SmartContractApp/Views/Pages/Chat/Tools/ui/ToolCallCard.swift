//
//  ToolCallCard.swift
//  SmartContractApp
//
//  Created on 11/25/25.
//

import AgentLayout
import SwiftUI

/// A reusable card component for displaying tool calls in the chat interface.
/// Provides a consistent visual container with the tool name header and customizable content.
struct ToolCallCard<Content: View>: View {
    // MARK: - Properties

    /// The name of the tool being called
    let toolName: String

    /// The content to display inside the card
    let content: () -> Content

    // MARK: - Initializer

    init(toolName: String, @ViewBuilder content: @escaping () -> Content) {
        self.toolName = toolName
        self.content = content
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tool call label
            Text("Tool call: \(toolName)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            // Content area
            content()
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview("Tool Call Card") {
    ToolCallCard(toolName: "Deploy Contract") {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sample Content")
                .font(.title2)
                .fontWeight(.semibold)

            Text("This is an example of content inside a tool call card.")
                .foregroundColor(.secondary)

            HStack {
                Spacer()
                Button("Action") {
                    print("Button pressed")
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    .frame(width: 400)
    .padding()
    .background(Color.black)
}
//
//  CopyableView.swift
//  SmartContractApp
//
//  Created by Claude on 11/12/25.
//

import SwiftUI

/// A reusable view component that displays text with a copy button
struct CopyableView: View {
    // MARK: - Properties

    let text: String
    let displayText: String?
    let label: String?
    let style: CopyableStyle

    @State private var showCopiedFeedback = false

    // MARK: - Initialization

    /// Initialize with full text and optional display text
    /// - Parameters:
    ///   - text: The full text to copy
    ///   - displayText: Optional truncated/formatted text to display (defaults to full text)
    ///   - label: Optional label to show above the copyable text
    ///   - style: Visual style of the component
    init(
        text: String,
        displayText: String? = nil,
        label: String? = nil,
        style: CopyableStyle = .default
    ) {
        self.text = text
        self.displayText = displayText
        self.label = label
        self.style = style
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label = label {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                Text(displayText ?? text)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(style.textColor)
                    .textSelection(.enabled)
                    .lineLimit(style.lineLimit)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: copyToClipboard) {
                    Image(systemName: showCopiedFeedback ? "checkmark.circle.fill" : "doc.on.doc")
                        .foregroundColor(showCopiedFeedback ? .green : style.iconColor)
                        .font(.system(size: 16))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")
            }
            .padding(8)
            .background(style.backgroundColor)
            .cornerRadius(6)
        }
    }

    // MARK: - Actions

    private func copyToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif

        // Show feedback
        withAnimation {
            showCopiedFeedback = true
        }

        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedFeedback = false
            }
        }
    }
}

// MARK: - Style Configuration

/// Visual style options for CopyableView
struct CopyableStyle {
    let backgroundColor: Color
    let textColor: Color
    let iconColor: Color
    let lineLimit: Int?

    static let `default` = CopyableStyle(
        backgroundColor: Color.secondary.opacity(0.1),
        textColor: .primary,
        iconColor: .secondary,
        lineLimit: nil
    )

    static let success = CopyableStyle(
        backgroundColor: Color.green.opacity(0.1),
        textColor: .primary,
        iconColor: .green,
        lineLimit: nil
    )

    static let info = CopyableStyle(
        backgroundColor: Color.blue.opacity(0.1),
        textColor: .primary,
        iconColor: .blue,
        lineLimit: nil
    )

    static let compact = CopyableStyle(
        backgroundColor: Color.secondary.opacity(0.1),
        textColor: .primary,
        iconColor: .secondary,
        lineLimit: 1
    )
}

// MARK: - Previews

#Preview("Transaction Hash") {
    VStack(spacing: 20) {
        CopyableView(
            text: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
            displayText: "0x1234...cdef",
            label: "Transaction Hash:",
            style: .success
        )

        CopyableView(
            text: "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
            label: "Contract Address:",
            style: .info
        )

        CopyableView(
            text: "npub1234567890abcdef",
            style: .default
        )
    }
    .padding()
}

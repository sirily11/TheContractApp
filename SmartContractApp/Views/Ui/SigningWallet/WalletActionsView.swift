//
//  WalletActionsView.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import SwiftUI

/// Action buttons for wallet operations (Send/Receive)
struct WalletActionsView: View {

    // MARK: - Properties

    @Binding var showingSendSheet: Bool
    @Binding var showingReceiveSheet: Bool

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            // Send button
            ActionButton(
                title: "Send",
                icon: "arrow.up.circle.fill",
                color: .blue
            ) {
                showingSendSheet = true
            }

            // Receive button
            ActionButton(
                title: "Receive",
                icon: "arrow.down.circle.fill",
                color: .green
            ) {
                showingReceiveSheet = true
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Action Button Component

private struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)

                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var showingSend = false
    @Previewable @State var showingReceive = false

    VStack {
        WalletActionsView(
            showingSendSheet: $showingSend,
            showingReceiveSheet: $showingReceive
        )

        if showingSend {
            Text("Send Sheet Shown")
                .foregroundColor(.blue)
        }

        if showingReceive {
            Text("Receive Sheet Shown")
                .foregroundColor(.green)
        }
    }
    .frame(width: 400)
    .padding()
}

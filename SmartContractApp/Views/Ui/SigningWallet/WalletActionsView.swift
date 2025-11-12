//
//  WalletActionsView.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import SwiftUI

// MARK: - Navigation Destinations

struct SendDestination: Hashable {}
struct ReceiveDestination: Hashable {}

/// Action buttons for wallet operations (Send/Receive)
struct WalletActionsView: View {
    // MARK: - Properties

    @Binding var navigationPath: NavigationPath

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            // Send button
            ActionButton(
                title: "Send",
                icon: "arrow.up.circle.fill",
                color: .blue
            ) {
                navigationPath.append(SendDestination())
            }

            // Receive button
            ActionButton(
                title: "Receive",
                icon: "arrow.down.circle.fill",
                color: .green
            ) {
                navigationPath.append(ReceiveDestination())
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
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var navigationPath = NavigationPath()

    VStack {
        WalletActionsView(navigationPath: $navigationPath)

        Text("Navigation path count: \(navigationPath.count)")
            .foregroundColor(.blue)
    }
    .frame(width: 400)
    .padding()
}

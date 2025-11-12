//
//  TransactionPendingView.swift
//  SmartContractApp
//
//  Created by Claude on 11/12/25.
//

import SwiftUI

/// Simple Apple-like pending screen shown while transaction is being processed on-chain
struct TransactionPendingView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Progress indicator
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.large)
                .scaleEffect(1.5)

            VStack(spacing: 8) {
                Text("Processing Transaction")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Please wait while your transaction\nis confirmed on the network")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .opacity(isAnimating ? 1.0 : 0.6)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview("Transaction Pending") {
    TransactionPendingView()
        .frame(width: 400, height: 300)
}

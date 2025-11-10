//
//  WalletAvatarView.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import SwiftUI
import CryptoKit

/// Generates a deterministic GitHub-style avatar based on wallet address
struct WalletAvatarView: View {
    let address: String
    let size: CGFloat

    // MARK: - Computed Properties

    private var addressData: Data {
        // Remove 0x prefix if present
        let cleanAddress = address.hasPrefix("0x") ? String(address.dropFirst(2)) : address
        return Data(hex: cleanAddress) ?? Data()
    }

    private var colorPalette: (background: Color, foreground: Color) {
        guard addressData.count > 0 else {
            return (.gray.opacity(0.2), .gray)
        }

        // Use predefined color schemes that look good together
        let colorSchemes: [(background: Color, foreground: Color)] = [
            // Blue tones
            (Color(red: 0.87, green: 0.92, blue: 0.98), Color(red: 0.13, green: 0.49, blue: 0.95)),
            // Green tones
            (Color(red: 0.86, green: 0.96, blue: 0.91), Color(red: 0.11, green: 0.73, blue: 0.49)),
            // Purple tones
            (Color(red: 0.93, green: 0.89, blue: 0.98), Color(red: 0.57, green: 0.27, blue: 0.93)),
            // Orange tones
            (Color(red: 0.99, green: 0.93, blue: 0.87), Color(red: 0.95, green: 0.52, blue: 0.13)),
            // Pink tones
            (Color(red: 0.99, green: 0.89, blue: 0.93), Color(red: 0.91, green: 0.21, blue: 0.46)),
            // Teal tones
            (Color(red: 0.88, green: 0.97, blue: 0.97), Color(red: 0.13, green: 0.70, blue: 0.76)),
            // Indigo tones
            (Color(red: 0.91, green: 0.91, blue: 0.98), Color(red: 0.39, green: 0.39, blue: 0.92)),
            // Red tones
            (Color(red: 0.99, green: 0.89, blue: 0.88), Color(red: 0.87, green: 0.27, blue: 0.27)),
            // Cyan tones
            (Color(red: 0.88, green: 0.96, blue: 0.98), Color(red: 0.13, green: 0.64, blue: 0.82)),
            // Lime tones
            (Color(red: 0.93, green: 0.98, blue: 0.87), Color(red: 0.51, green: 0.82, blue: 0.13)),
            // Amber tones
            (Color(red: 0.99, green: 0.95, blue: 0.87), Color(red: 0.92, green: 0.67, blue: 0.13)),
            // Rose tones
            (Color(red: 0.99, green: 0.90, blue: 0.95), Color(red: 0.88, green: 0.29, blue: 0.56))
        ]

        // Select color scheme based on first byte of address
        let index = Int(addressData[0]) % colorSchemes.count
        return colorSchemes[index]
    }

    private var backgroundColor: Color {
        colorPalette.background
    }

    private var foregroundColor: Color {
        colorPalette.foreground
    }

    private var pattern: [[Bool]] {
        // Generate 5x5 grid (symmetric for aesthetics)
        // We only need to define 3 columns since it's mirrored
        guard addressData.count >= 4 else {
            return Array(repeating: Array(repeating: false, count: 5), count: 5)
        }

        var grid: [[Bool]] = []
        var dataIndex = 2 // Start from byte 2 (0 and 1 used for colors)

        for row in 0..<5 {
            var rowData: [Bool] = []

            // Generate left half + middle
            for col in 0..<3 {
                let byteIndex = dataIndex % addressData.count
                let bitIndex = (row * 3 + col) % 8
                let byte = addressData[byteIndex]
                let bit = (byte >> bitIndex) & 1
                rowData.append(bit == 1)

                dataIndex += 1
            }

            // Mirror for symmetry
            rowData.append(rowData[1]) // Mirror column 1
            rowData.append(rowData[0]) // Mirror column 0

            grid.append(rowData)
        }

        return grid
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(backgroundColor)

            // Pattern grid
            GeometryReader { geometry in
                let cellSize = geometry.size.width / 5

                ForEach(0..<5, id: \.self) { row in
                    ForEach(0..<5, id: \.self) { col in
                        if pattern[row][col] {
                            RoundedRectangle(cornerRadius: cellSize * 0.2)
                                .fill(foregroundColor)
                                .frame(width: cellSize * 0.8, height: cellSize * 0.8)
                                .position(
                                    x: CGFloat(col) * cellSize + cellSize / 2,
                                    y: CGFloat(row) * cellSize + cellSize / 2
                                )
                        }
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Data Extension

private extension Data {
    init?(hex: String) {
        let len = hex.count / 2
        var data = Data(capacity: len)
        var i = hex.startIndex
        for _ in 0..<len {
            let j = hex.index(i, offsetBy: 2)
            let bytes = hex[i..<j]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
            i = j
        }
        self = data
    }
}

// MARK: - Preview

#Preview("Single Avatar") {
    VStack(spacing: 20) {
        WalletAvatarView(
            address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            size: 64
        )

        WalletAvatarView(
            address: "0x1234567890abcdef1234567890abcdef12345678",
            size: 64
        )

        WalletAvatarView(
            address: "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
            size: 64
        )
    }
    .padding()
}

#Preview("Different Sizes") {
    HStack(spacing: 20) {
        WalletAvatarView(
            address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            size: 32
        )

        WalletAvatarView(
            address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            size: 48
        )

        WalletAvatarView(
            address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            size: 64
        )

        WalletAvatarView(
            address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            size: 96
        )
    }
    .padding()
}

#Preview("Multiple Wallets") {
    let addresses = [
        "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
        "0x1234567890abcdef1234567890abcdef12345678",
        "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd",
        "0x9876543210fedcba9876543210fedcba98765432",
        "0x1111111111111111111111111111111111111111",
        "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
    ]

    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
        ForEach(addresses, id: \.self) { address in
            VStack {
                WalletAvatarView(address: address, size: 64)
                Text(TransactionFormatter.truncateAddress(address))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    .padding()
}

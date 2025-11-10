//
//  ReceiveView.swift
//  SmartContractApp
//
//  Created by Claude on 11/10/25.
//

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ReceiveView: View {
    @Environment(\.dismiss) private var dismiss
    let walletAddress: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Receive")
                .font(.title2)
                .fontWeight(.bold)

            // QR Code
            if let qrImage = generateQRCode(from: walletAddress) {
                Image(qrImage, scale: 1.0, label: Text("QR Code"))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 200, height: 200)
                    .background(Color.white)
                    .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .overlay {
                        Image(systemName: "qrcode")
                            .font(.system(size: 80))
                            .foregroundColor(.secondary)
                    }
            }

            // Address
            VStack(spacing: 8) {
                Text("Your Address")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(walletAddress)
                    .font(.system(.footnote, design: .monospaced))
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)

                Button(action: copyAddress) {
                    Label("Copy Address", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Receive")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Helper Methods

    private func copyAddress() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(walletAddress, forType: .string)
        #else
        UIPasteboard.general.string = walletAddress
        #endif
    }

    private func generateQRCode(from string: String) -> CGImage? {
        let data = Data(string.utf8)

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return nil }

        // Scale up the QR code
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return cgImage
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReceiveView(
            walletAddress: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb0"
        )
    }
}

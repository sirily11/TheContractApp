//
//  AbiRowView.swift
//  SmartContractApp
//
//  Created by Claude on 11/7/25.
//

import SwiftData
import SwiftUI
import EvmCore

struct AbiRowView: View {
    let abi: EvmAbi

    private var parsedSummary: String {
        guard let parser = try? AbiParser(fromJsonString: abi.abiContent) else {
            return "Invalid ABI"
        }

        let functionCount = parser.functions.count
        let eventCount = parser.events.count

        return "\(functionCount) function\(functionCount == 1 ? "" : "s"), \(eventCount) event\(eventCount == 1 ? "" : "s")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(abi.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(parsedSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Text("Created: \(abi.createdAt, style: .date)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let sampleAbi = """
    [
        {
            "type": "function",
            "name": "transfer",
            "inputs": [
                {"name": "to", "type": "address"},
                {"name": "amount", "type": "uint256"}
            ],
            "outputs": [
                {"name": "", "type": "bool"}
            ],
            "stateMutability": "nonpayable"
        },
        {
            "type": "event",
            "name": "Transfer",
            "inputs": [
                {"name": "from", "type": "address", "indexed": true},
                {"name": "to", "type": "address", "indexed": true},
                {"name": "value", "type": "uint256", "indexed": false}
            ]
        }
    ]
    """

    return AbiRowView(abi: EvmAbi(name: "ERC20 Token", abiContent: sampleAbi))
        .modelContainer(for: EvmAbi.self, inMemory: true)
        .padding()
}

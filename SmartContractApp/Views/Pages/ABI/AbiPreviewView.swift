//
//  AbiPreviewView.swift
//  SmartContractApp
//
//  Created by Claude on 11/7/25.
//

import EvmCore
import SwiftUI

struct AbiPreviewView: View {
    let parser: AbiParser

    @State private var showFunctions = false
    @State private var showEvents = false
    @State private var showErrors = false

    var body: some View {
        VStack(spacing: 12) {
            // Functions
            Button(action: {
                withAnimation {
                    showFunctions.toggle()
                }
            }) {
                HStack {
                    Text("Functions")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(parser.functions.count)")
                        .foregroundColor(.secondary)
                    Image(systemName: showFunctions ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showFunctions && !parser.functions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(parser.functions, id: \.name) { function in
                        if let name = function.name {
                            HStack {
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.leading, 8)
                        }
                    }
                }
                .padding(.vertical, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()

            // Events
            Button(action: {
                withAnimation {
                    showEvents.toggle()
                }
            }) {
                HStack {
                    Text("Events")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(parser.events.count)")
                        .foregroundColor(.secondary)
                    Image(systemName: showEvents ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showEvents && !parser.events.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(parser.events, id: \.name) { event in
                        if let name = event.name {
                            HStack {
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.leading, 8)
                        }
                    }
                }
                .padding(.vertical, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()

            // Errors
            Button(action: {
                withAnimation {
                    showErrors.toggle()
                }
            }) {
                HStack {
                    Text("Errors")
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(parser.errors.count)")
                        .foregroundColor(.secondary)
                    Image(systemName: showErrors ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showErrors && !parser.errors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(parser.errors, id: \.name) { error in
                        if let name = error.name {
                            HStack {
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.leading, 8)
                        }
                    }
                }
                .padding(.vertical, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()

            // Constructor
            HStack {
                Text("Constructor")
                Spacer()
                Text(parser.constructor != nil ? "Yes" : "No")
                    .foregroundColor(.secondary)
            }
        }
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
            "outputs": [{"name": "", "type": "bool"}],
            "stateMutability": "nonpayable"
        },
        {
            "type": "function",
            "name": "balanceOf",
            "inputs": [
                {"name": "account", "type": "address"}
            ],
            "outputs": [{"name": "", "type": "uint256"}],
            "stateMutability": "view"
        },
        {
            "type": "event",
            "name": "Transfer",
            "inputs": [
                {"name": "from", "type": "address", "indexed": true},
                {"name": "to", "type": "address", "indexed": true},
                {"name": "value", "type": "uint256", "indexed": false}
            ]
        },
        {
            "type": "event",
            "name": "Approval",
            "inputs": [
                {"name": "owner", "type": "address", "indexed": true},
                {"name": "spender", "type": "address", "indexed": true},
                {"name": "value", "type": "uint256", "indexed": false}
            ]
        }
    ]
    """

    if let parser = try? AbiParser(fromJsonString: sampleAbi) {
        return AbiPreviewView(parser: parser)
            .padding()
    } else {
        return Text("Failed to parse ABI")
    }
}

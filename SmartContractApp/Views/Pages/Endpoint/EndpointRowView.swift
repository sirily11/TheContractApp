//  EndpointListView.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/7/25.
//

import SwiftData
import SwiftUI

struct EndpointRowView: View {
    let endpoint: Endpoint

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(endpoint.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(endpoint.url)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Text("Chain ID: \(endpoint.chainId)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Text("Created: \(endpoint.createdAt, style: .date)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    EndpointRowView(endpoint: Endpoint(name: "Example Endpoint", url: "https://example.com", chainId: "1"))
        .modelContainer(for: Endpoint.self, inMemory: true)
}

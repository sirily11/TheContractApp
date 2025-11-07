//
//  EmptyPlaceholderView.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/7/25.
//

import SwiftUI

struct EmptyPlaceholderView: View {
    let title: String
    let description: String
    let systemImage: String
    
    init(title: String, description: String, systemImage: String = "exclamationmark.triangle") {
        self.title = title
        self.description = description
        self.systemImage = systemImage
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Go Back") {
                // This will be handled by navigation
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    NavigationView {
        EmptyPlaceholderView(
            title: "Feature Coming Soon",
            description: "This feature is not yet implemented but will be available in a future update."
        )
    }
}
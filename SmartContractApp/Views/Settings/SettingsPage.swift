//
//  SettingsPage.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/20/25.
//
import SwiftUI

// MARK: - Main Settings View

struct SettingsPage: View {
    @State private var selectedTab: SettingsTab = .providers

    var body: some View {
        TabView(selection: $selectedTab) {
            ProvidersSettingsTab()
                .tabItem {
                    Label(SettingsTab.providers.title, systemImage: SettingsTab.providers.systemImage)
                }
                .tag(SettingsTab.providers)
        }
        .padding(.top, -20)
        .toolbar(removing: .sidebarToggle)
        .tabViewStyle(.sidebarAdaptable)
    }
}

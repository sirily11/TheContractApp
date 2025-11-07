//
//  SmartContractAppApp.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/5/25.
//

import SwiftData
import SwiftUI

@main
struct SmartContractAppApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Endpoint.self,
            EVMContract.self,
            EvmAbi.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

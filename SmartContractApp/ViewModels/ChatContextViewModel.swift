//
//  ChatContextViewModel.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 12/3/25.
//

import SwiftUI

@Observable
final class ChatContextViewModel {
    private let defaultSystemPrompt = """
    You are the expert of writing smart contract, calling tools and deploy contract for user using the existing code.
    If user ask to write a smart contract, you should write it and deploy it for user unless user ask not to deploy it.

    Use existing tools to check the syntax you wrote is valid or not.
    """
    
    func setUp() {
        
    }

    func getSystemPrompt() -> String {
        return defaultSystemPrompt
    }
}

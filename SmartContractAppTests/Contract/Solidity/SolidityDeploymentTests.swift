//
//  SolidityDeploymentTests.swift
//  SmartContractAppTests
//
//  Created by Qiwei Li on 11/13/25.
//

@testable import SmartContractApp
import SwiftData
import SwiftUI
import Testing
import ViewInspector

struct SolidityDeploymentTests {
    // MARK: - Close Button Tests

    @Test @MainActor func testFormReviewPageShowsCancelButton() async throws {
        let wrapper = try SwiftUITestWrapper.withDefaults {
            SolidityDeploymentSheet(
                sourceCode: .constant("pragma solidity ^0.8.0; contract Test {}"),
                contractName: .constant("Test Contract")
            )
        }

        let view = try wrapper.inspect()

        // Verify Cancel button exists on the form review page
        let cancelButton = try view.find(button: "Cancel")
        #expect(cancelButton != nil)
    }

    @Test @MainActor func testCancelButtonIsClickable() async throws {
        let wrapper = try SwiftUITestWrapper.withDefaults {
            SolidityDeploymentSheet(
                sourceCode: .constant("pragma solidity ^0.8.0; contract Test {}"),
                contractName: .constant("Test")
            )
        }

        let view = try wrapper.inspect()

        // Verify Cancel button allows hit testing (is clickable)
        let cancelButton = try view.find(button: "Cancel")
        #expect(cancelButton.allowsHitTesting())
    }
}

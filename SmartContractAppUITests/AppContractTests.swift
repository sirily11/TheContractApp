//
//  AppContractTests.swift
//  SmartContractAppUITests
//
//  Created by Qiwei Li on 11/27/25.
//

import Cocoa
import XCTest

let contract = """
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract HelloWorld {
    string public message;

    constructor() {
        message = "Hello, World!";
    }

    function getMessage() public view returns (string memory) {
        return message;
    }

    function setMessage(string memory _newMessage) public {
        message = _newMessage;
    }

    function payMe() public payable {

    }
}
"""

final class AppContractTests: XCTestCase {
    override func setUpWithError() throws {}

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testCreateContractAndInteractWithIt() throws {
        let app = XCUIApplication()
        app.launchArguments = ["enable-testing"]
        app.launch()

        app/*@START_MENU_TOKEN@*/ .buttons.matching(identifier: "wallet.pass").element(boundBy: 1)/*[[".buttons.matching(identifier: \"wallet.pass\").element(boundBy: 1)",".windows[\"ContractApp\"].buttons[\"wallet.pass\"].firstMatch"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/ .click()

        let cellsQuery = app.cells

        // MARK: - Create Endpoint

        let sidebarEndpoints = cellsQuery.containing(.button, identifier: "sidebar-endpoints").firstMatch
        sidebarEndpoints.click()
        app.buttons["endpoint-add-button"].firstMatch.click()
        sidebarEndpoints.typeText("Local")
        app.groups.containing(.textField, identifier: "endpoint-name-textfield").firstMatch.click()
        app.textFields["endpoint-url-textfield"].firstMatch.click()
        sidebarEndpoints.typeText("http://localhost:8545")
        app.switches["endpoint-auto-detect-toggle"].firstMatch.click()
        app.buttons["endpoint-create-button"].firstMatch.click()

        // MARK: - Navigate to Wallet tab to create wallet

        let settingsTab = app.radioButtons["gearshape.2"].firstMatch
        settingsTab.click()
        cellsQuery.containing(.button, identifier: "sidebar-wallet").firstMatch.click()
        app.menuButtons["wallet-add-button"].firstMatch.click()
        app.menuItems["wallet-import-privatekey-menu-item"].firstMatch.click()

        // MARK: - Create wallet with private key

        app.sheets.scrollViews.firstMatch.click()
        let privateKeyField = app.secureTextFields["wallet-privatekey-field"].firstMatch
        privateKeyField.click()
        privateKeyField.typeText("0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80")
        app.buttons["wallet-create-button"].firstMatch.click()

        // MARK: - Navigate to Contract tab and deploy Solidity contract

        let contractTab = app.radioButtons["doc.text.fill"].firstMatch
        contractTab.click()
        app.menuButtons["contract-add-button"].firstMatch.click()
        app.menuItems["contract-solidity-menu-item"].firstMatch.click()

        // MARK: - Fill in contract deployment form

        let contractWindow = app.windows["ContractApp"]

        // Enter contract name first
        let contractNameField = app.textFields["deployment-contract-name-textfield"].firstMatch
        contractNameField.click()
        contractNameField.typeText("Hello World Contract")

        // Enter Solidity source code using clipboard (typeText can corrupt special chars)
        let sourceCodeView = contractWindow.textViews.firstMatch
        sourceCodeView.click()

        // Use pasteboard to paste the contract code
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(contract, forType: .string)
        sourceCodeView.typeKey("v", modifierFlags: .command)

        // Wait for text view to process input
        sleep(2)

        // Select endpoint
        app.popUpButtons["deployment-endpoint-picker"].firstMatch.click()
        app.menuItems["Local"].firstMatch.click()

        // MARK: - Deploy contract

        // Step 1: Click Next to start compilation
        let deploymentNextButton = app.buttons["deployment-next-button"].firstMatch
        deploymentNextButton.click()

        // Step 2: Wait for compilation to complete and Next button to reappear
        sleep(1)
        XCTAssertTrue(deploymentNextButton.waitForExistence(timeout: 60), "Next button should appear after compilation")
        deploymentNextButton.click()

        // Step 3: Constructor params page - click Next to start deployment
        // (HelloWorld has no params, but we still need to click Next on constructor page)
        sleep(1)

        let signingWindow = app.windows["signing-wallet-AppWindow-1"]

        let approveButton = signingWindow.buttons["signing-approve-button"].firstMatch
        XCTAssertTrue(approveButton.waitForExistence(timeout: 10), "Approve button should appear")
        approveButton.click()

        // MARK: - Close signing window and deployment sheet

        // Wait for transaction to complete and signing window to close automatically
        sleep(3)

        // Close signing window if still open
        let closeSigningWindowButton = signingWindow.buttons["_XCUI:CloseWindow"].firstMatch
        if closeSigningWindowButton.exists {
            closeSigningWindowButton.click()
        }

        // Wait for deployment success and close button to appear
        let deploymentCloseButton = app.buttons["deployment-close-button"].firstMatch
        XCTAssertTrue(deploymentCloseButton.waitForExistence(timeout: 30), "Close button should appear after deployment")
        deploymentCloseButton.click()

        // MARK: - Call contract functions

        let callButtons = app.buttons.matching(identifier: "contract-call-button")
        callButtons.element(boundBy: 0).click()
        callButtons.element(boundBy: 1).click()
        callButtons.element(boundBy: 2).click()
        callButtons.element(boundBy: 3).click()

        // MARK: - Interact with payable function

        let contractListCell = cellsQuery.containing(.button, identifier: "Hello World Contract").firstMatch
        contractListCell.typeText("1")
        app.sheets.scrollViews.firstMatch.click()

        let continueButton = app.buttons["functioncall-continue-button"].firstMatch
        continueButton.click()

        let signAndSendButton = app.buttons["functioncall-sign-send-button"].firstMatch
        signAndSendButton.click()
        app.otherElements.firstMatch.click()
        app.staticTexts["Payme"].firstMatch.click()
        // Approve in signing window for payMe function
        XCTAssertTrue(signingWindow.waitForExistence(timeout: 30), "Signing window should appear for payMe")
        let payMeApproveButton = signingWindow.buttons["signing-approve-button"].firstMatch
        XCTAssertTrue(payMeApproveButton.waitForExistence(timeout: 10), "Approve button should appear")
        payMeApproveButton.click()

        sleep(2)
        if signingWindow.buttons["_XCUI:CloseWindow"].firstMatch.exists {
            signingWindow.buttons["_XCUI:CloseWindow"].firstMatch.click()
        }
        app.buttons["functioncall-done-button"].firstMatch.click()

        // MARK: - Call setMessage function

        callButtons.element(boundBy: 3).click()
        contractListCell.typeText("Hello world")
        continueButton.click()
        signAndSendButton.click()

        app.staticTexts["Setmessage"].firstMatch.click()

        // Approve in signing window for setMessage function
        XCTAssertTrue(signingWindow.waitForExistence(timeout: 30), "Signing window should appear for setMessage")
        let setMessageApproveButton = signingWindow.buttons["signing-approve-button"].firstMatch
        XCTAssertTrue(setMessageApproveButton.waitForExistence(timeout: 10), "Approve button should appear")
        setMessageApproveButton.click()

        sleep(2)
        if signingWindow.buttons["_XCUI:CloseWindow"].firstMatch.exists {
            signingWindow.buttons["_XCUI:CloseWindow"].firstMatch.click()
        }

        // Verify success message appears (not error)
        let successMessage = app.staticTexts["functioncall-success-message"]
        XCTAssertTrue(successMessage.waitForExistence(timeout: 10), "Success message should appear after setMessage function call")

        app.buttons["functioncall-done-button"].firstMatch.click()
    }
}

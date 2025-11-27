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

let privateKey = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

final class AppContractTests: XCTestCase {
    @MainActor
    func testCreateContractAndInteractWithIt() throws {
        // MARK: - Create Endpoint

        let app = AppUtils()
        app.openWalletWindow()

        app.createEndpoint(name: "Local", url: "http://localhost:8545")

        // MARK: - Create Wallet

        app.createWallet(with: privateKey)

        // MARK: - Deploy Contract

        app.navigateToContractTab()
        app.openContractDeploymentForm()
        app.fillContractDeploymentForm(name: "Hello World Contract", sourceCode: contract, endpoint: "Local")
        app.stepThroughDeployment()
        app.clickSigningWalletFunctionName(name: "<Constructor>")
        app.approveTransaction()
        app.closeDeploymentSheet()

        // MARK: - Call read-only contract functions

        app.callContractFunction(at: 0)
        app.callContractFunction(at: 1)
        app.callContractFunction(at: 2)

        // MARK: - Interact with payable function (payMe)

        app.fillFunctionValue(value: "1")
        app.continueFunctionCall()
        app.signAndSendFunctionCall()
        app.approveTransaction()
        app.closeFunctionCallResult()

        // MARK: - Call setMessage function

        app.callContractFunction(at: 3)
        app.fillFunctionParameter(field: "_newMessage", value: "Hello world")
        app.continueFunctionCall()
        app.signAndSendFunctionCall()
        app.approveTransaction()
        app.waitForFunctionCallSuccess()
        app.closeFunctionCallResult()
    }
}

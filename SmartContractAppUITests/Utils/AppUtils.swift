//
//  AppUtils.swift
//  SmartContractApp
//
//  Created by Qiwei Li on 11/27/25.
//
import Cocoa
import XCTest

struct AppUtils {
    let app: XCUIApplication

    // MARK: - Element Queries

    private var cellsQuery: XCUIElementQuery {
        app.cells
    }

    // MARK: - Sidebar Navigation Elements

    private var sidebarEndpointTab: XCUIElement {
        app.cells.containing(.button, identifier: "sidebar-endpoints").firstMatch
    }

    private var sidebarWalletTab: XCUIElement {
        app.cells.containing(.button, identifier: "sidebar-wallet").firstMatch
    }

    private var sidebarContractTab: XCUIElement {
        app.radioButtons["doc.text.fill"].firstMatch
    }

    private var sidebarSettingsTab: XCUIElement {
        app.radioButtons["gearshape.2"].firstMatch
    }

    // MARK: - Window Elements

    var contractWindow: XCUIElement {
        app.windows["ContractApp"]
    }

    var signingWindow: XCUIElement {
        app.windows["signing-wallet"]
    }

    var mainWindow: XCUIElement {
        app.windows["main-AppWindow-1"]
    }

    init(app: XCUIApplication) {
        self.app = app
        self.app.launchArguments = ["enable-testing"]
        self.app.launch()
    }

    init() {
        self.app = XCUIApplication()
        app.launchArguments = ["enable-testing"]
        app.launch()
    }

    func createEndpoint(name: String, url: String) {
        // MARK: - Create Endpoint

        sidebarEndpointTab.click()
        app.buttons["endpoint-add-button"].firstMatch.click()
        sidebarEndpointTab.typeText(name)
        app.groups.containing(.textField, identifier: "endpoint-name-textfield").firstMatch.click()
        app.textFields["endpoint-url-textfield"].firstMatch.click()
        sidebarEndpointTab.typeText(url)
        app.switches["endpoint-auto-detect-toggle"].firstMatch.click()
        app.buttons["endpoint-create-button"].firstMatch.click()
    }

    func openWalletWindow() {
        let predicate = NSPredicate(format: "isHittable == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: signingWindow)
        let result = XCTWaiter().wait(for: [expectation], timeout: 5)
        if result == .completed || result == .timedOut {
            return
        }
        app/*@START_MENU_TOKEN@*/ .buttons.matching(identifier: "wallet.pass").element(boundBy: 1)/*[[".buttons.matching(identifier: \"wallet.pass\").element(boundBy: 1)",".windows[\"ContractApp\"].buttons[\"wallet.pass\"].firstMatch"],[[[-1,1],[-1,0]]],[1]]@END_MENU_TOKEN@*/ .click()
    }

    func createWallet(with privateKey: String) {
        sidebarSettingsTab.click()
        sidebarWalletTab.click()
        app.menuButtons["wallet-add-button"].firstMatch.click()
        app.menuItems["wallet-import-privatekey-menu-item"].firstMatch.click()

        app.sheets.scrollViews.firstMatch.click()
        let privateKeyField = app.secureTextFields["wallet-privatekey-field"].firstMatch
        privateKeyField.click()
        privateKeyField.typeText(privateKey)
        app.buttons["wallet-create-button"].firstMatch.click()
    }

    // MARK: - Navigation Helpers

    func navigateToContractTab() {
        sidebarContractTab.click()
    }

    func navigateToSettingsTab() {
        sidebarSettingsTab.click()
    }

    // MARK: - Contract Deployment Helpers

    func openContractDeploymentForm() {
        app.menuButtons["contract-add-button"].firstMatch.click()
        app.menuItems["contract-solidity-menu-item"].firstMatch.click()
    }

    func fillContractDeploymentForm(name: String, sourceCode: String, endpoint: String) {
        let contractNameField = app.textFields["deployment-contract-name-textfield"].firstMatch
        contractNameField.click()
        contractNameField.typeText(name)

        let sourceCodeView = contractWindow.textViews.firstMatch
        sourceCodeView.click()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(sourceCode, forType: .string)
        sourceCodeView.typeKey("v", modifierFlags: .command)

        sleep(2)

        app.popUpButtons["deployment-endpoint-picker"].firstMatch.click()
        app.menuItems[endpoint].firstMatch.click()
    }

    func stepThroughDeployment() {
        let deploymentNextButton = app.buttons["deployment-next-button"].firstMatch

        // Step 1: Click Next to start compilation
        deploymentNextButton.click()

        // Step 2: Wait for compilation to complete and Next button to reappear
        sleep(1)
        XCTAssertTrue(deploymentNextButton.waitForExistence(timeout: 60), "Next button should appear after compilation")
        deploymentNextButton.click()

        // Step 3: Constructor params page - wait for signing window
        sleep(1)
    }

    func closeDeploymentSheet() {
        let deploymentCloseButton = app.buttons["deployment-close-button"].firstMatch
        XCTAssertTrue(deploymentCloseButton.waitForExistence(timeout: 30), "Close button should appear after deployment")
        deploymentCloseButton.click()
    }

    // MARK: - Signing Window Helpers

    func approveTransaction() {
        // click signing window
        print("Winodw: \(app.windows.allElementsBoundByIndex)")
        signingWindow.click()
        let approveButton = signingWindow.buttons["signing-approve-button"].firstMatch
        XCTAssertTrue(approveButton.waitForExistence(timeout: 10), "Approve button should appear")
        approveButton.click()
    }

    func closeSigningWindowIfOpen() {
        sleep(2)
        while signingWindow.exists {
            // click back button first
            let backButton = app.buttons["_XCUI:Back"].firstMatch
            if backButton.waitForExistence(timeout: 10) {
                backButton.click()
            }
            let closeButton = signingWindow.buttons["_XCUI:CloseWindow"].firstMatch
            closeButton.click()
            sleep(1)
        }
    }

    // MARK: - Function Call Helpers

    func callContractFunction(at index: Int) {
        mainWindow.click()
        let callButtons = app.buttons.matching(identifier: "contract-call-button")
        callButtons.element(boundBy: index).click()
    }

    func clickSigningWalletFunctionName(name: String) {
        signingWindow.click()
        // check if the static text exists
        if app.staticTexts[name].firstMatch.exists {
            app.staticTexts[name].firstMatch.click()
        }
    }

    func fillFunctionValue(value: String) {
        let contractListCell = app.textFields["transaction-value"].firstMatch
        contractListCell.typeText(value)
        app.sheets.scrollViews.firstMatch.click()
    }

    func fillFunctionParameter(field: String, value: String) {
        let contractListCell = app.textFields[field].firstMatch
        contractListCell.typeText(value)
        app.sheets.scrollViews.firstMatch.click()
    }

    func continueFunctionCall() {
        app.buttons["functioncall-continue-button"].firstMatch.click()
    }

    func signAndSendFunctionCall() {
        app.buttons["functioncall-sign-send-button"].firstMatch.click()
        app.otherElements.firstMatch.click()
    }

    func closeFunctionCallResult() {
        app.buttons["functioncall-done-button"].firstMatch.click()
    }

    func waitForFunctionCallSuccess() {
        let successMessage = app.staticTexts["functioncall-success-message"]
        XCTAssertTrue(successMessage.waitForExistence(timeout: 10), "Success message should appear after function call")
    }
}

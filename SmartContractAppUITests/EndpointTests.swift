//
//  SmartContractAppUITests.swift
//  SmartContractAppUITests
//
//  Created by Qiwei Li on 11/5/25.
//

import XCTest

final class EndpointTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // Configure app for testing with in-memory storage
        app = XCUIApplication()
        app.launchArguments = ["enable-testing"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testEndpoint() throws {
        app.activate()
        let cellsQuery = app.cells
        let element = cellsQuery/*@START_MENU_TOKEN@*/ .containing(.button, identifier: "sidebar-endpoints").firstMatch/*[[".element(boundBy: 0)",".containing(.button, identifier: \"sidebar-endpoints\").firstMatch"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        element.click()

        let element2 = app/*@START_MENU_TOKEN@*/ .buttons.matching(identifier: "endpoint-add-button").element(boundBy: 1)/*[[".buttons.matching(identifier: \"endpoint-add-button\").element(boundBy: 1)",".buttons[\"Add\"]",".buttons.firstMatch",".buttons[\"Add\"].firstMatch",".buttons[\"endpoint-add-button\"].firstMatch"],[[[-1,1,1],[-1,0]],[[-1,4],[-1,3],[-1,2]]],[1]]@END_MENU_TOKEN@*/
        element2.click()
        element.typeText("Test Endpoint")

        let element3 = app/*@START_MENU_TOKEN@*/ .textFields["endpoint-url-textfield"]/*[[".groups.textFields[\"endpoint-url-textfield\"]",".textFields[\"endpoint-url-textfield\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .firstMatch
        element3.click()
        element.typeText("http://localhost:8545")

        let element4 = app/*@START_MENU_TOKEN@*/ .switches["endpoint-auto-detect-toggle"]/*[[".groups.switches[\"endpoint-auto-detect-toggle\"]",".switches",".switches[\"endpoint-auto-detect-toggle\"]"],[[[-1,2],[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .firstMatch
        element4.click()

        let element5 = app/*@START_MENU_TOKEN@*/ .buttons["endpoint-create-button"]/*[[".groups",".buttons[\"Create\"]",".buttons[\"endpoint-create-button\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .firstMatch
        element5.click()
        cellsQuery/*@START_MENU_TOKEN@*/ .containing(.button, identifier: "Test Endpoint, http://localhost:8545, Chain ID: 31337, Created: November 19, 2025").firstMatch/*[[".element(boundBy: 3)",".containing(.button, identifier: \"Test Endpoint, http:\/\/localhost:8545, Chain ID: 31337, Created: November 19, 2025\").firstMatch"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .click()
        element2.click()
        element.typeText("Test Endpoint 2")
        element3.click()
        element.typeText("http://localhost:8545")
        element4.click()
        element5.click()
        cellsQuery/*@START_MENU_TOKEN@*/ .containing(.button, identifier: "Test Endpoint 2, http://localhost:8545, Chain ID: 31337, Created: November 19, 2025").firstMatch/*[[".element(boundBy: 3)",".containing(.button, identifier: \"Test Endpoint 2, http:\/\/localhost:8545, Chain ID: 31337, Created: November 19, 2025\").firstMatch"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/ .rightClick()

        let element6 = app/*@START_MENU_TOKEN@*/ .menuItems.matching(identifier: "Delete").element(boundBy: 1)/*[[".menuItems.matching(identifier: \"Delete\").element(boundBy: 1)",".outlines.menuItems[\"Delete\"].firstMatch",".windows[\"Endpoints\"].menuItems[\"menuAction:\"].firstMatch"],[[[-1,2],[-1,1],[-1,0]]],[2]]@END_MENU_TOKEN@*/
        element6.click()

        let element7 = app/*@START_MENU_TOKEN@*/ .buttons["endpoint-delete-confirm-button"]/*[[".sheets[\"_NS:87\"].buttons",".sheets",".buttons[\"Delete\"]",".buttons[\"endpoint-delete-confirm-button\"]"],[[[-1,3],[-1,2],[-1,1,1],[-1,0]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/ .firstMatch
        element7.click()
    }
}

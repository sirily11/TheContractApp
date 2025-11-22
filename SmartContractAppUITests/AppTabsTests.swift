import XCTest

final class AppTabTests: XCTestCase {
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

    func testSwitchingTabs() throws {
        app.activate()

        for _ in 0 ..< 5 {
            app/*@START_MENU_TOKEN@*/ .radioButtons["gearshape.2"]/*[[".radioGroups",".radioButtons[\"配置\"]",".radioButtons[\"gearshape.2\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .firstMatch.click()
            app/*@START_MENU_TOKEN@*/ .radioButtons["doc.text.fill"]/*[[".radioGroups",".radioButtons[\"执行\"]",".radioButtons[\"doc.text.fill\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .firstMatch.click()
            app/*@START_MENU_TOKEN@*/ .radioButtons["bubble.right.fill"]/*[[".radioGroups",".radioButtons[\"Chat\"]",".radioButtons[\"bubble.right.fill\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/ .firstMatch.click()
        }
    }
}

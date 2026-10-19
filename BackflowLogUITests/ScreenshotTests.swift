import XCTest

/// Captures App Store screenshots. Run with scripts/screenshots.sh BackflowLog.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testAppScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-unlock", "-resetData", "-sampleData", "-skipOnboarding", "-uiTesting"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Route"].waitForExistence(timeout: 15))
        sleep(1)
        snap("01-route", app)

        // Tap a named row rather than an index, because the first cell is the summary.
        app.staticTexts["Northside Car Wash"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["New Test"].waitForExistence(timeout: 5))
        // Fill the form so the shot shows the flagging, with the relief valve deliberately short.
        let fields = app.textFields
        fields.element(boundBy: 0).tap(); app.typeText("5.2")
        fields.element(boundBy: 1).tap(); app.typeText("3.1")
        fields.element(boundBy: 2).tap(); app.typeText("1.6")
        app.buttons["Done"].firstMatch.tap()   // drop the number pad
        sleep(1)
        snap("02-test", app)
        app.buttons["Cancel"].tap()

        tab("Customers", app)
        XCTAssertTrue(app.navigationBars["Customers"].waitForExistence(timeout: 5))
        snap("03-customers", app)

        app.staticTexts["Riverside Apartments"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Building A"].waitForExistence(timeout: 5))
        app.staticTexts["Building A"].firstMatch.tap()
        sleep(1)
        snap("04-assemblies", app)

        tab("Tests", app)
        XCTAssertTrue(app.navigationBars["Tests"].waitForExistence(timeout: 5))
        snap("05-tests", app)

        tab("Route", app)
        XCTAssertTrue(app.buttons["How do I use this app"].waitForExistence(timeout: 5))
        app.buttons["How do I use this app"].tap()
        XCTAssertTrue(app.staticTexts["Put your details in"].waitForExistence(timeout: 5))
        snap("06-how-to", app)
    }

    func testPaywall() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-uiTesting", "-mockPrices"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Lifetime"].waitForExistence(timeout: 10))
        snap("paywall", app)
    }

    private func tab(_ name: String, _ app: XCUIApplication) {
        let inTabBar = app.tabBars.buttons[name]
        if inTabBar.waitForExistence(timeout: 2) { inTabBar.tap() } else { app.buttons[name].firstMatch.tap() }
    }

    private func snap(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

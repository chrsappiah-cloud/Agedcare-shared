import XCTest

final class Agedcare_sharedUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAddItemCreatesEntry() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Add Item"].tap()
        XCTAssertTrue(app.collectionViews.cells.firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testTapItemShowsDetail() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Add Item"].tap()
        let cell = app.collectionViews.cells.firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.tap()
        let detail = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Item at'")).firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
    }

    @MainActor
    func testDeleteItem() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Add Item"].tap()
        let cell = app.collectionViews.cells.firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5))
        cell.swipeLeft()
        if app.buttons["Delete"].waitForExistence(timeout: 3) {
            app.buttons["Delete"].tap()
        }
    }

    @MainActor
    func testEditButtonExists() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

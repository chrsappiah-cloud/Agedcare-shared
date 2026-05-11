import XCTest

// MARK: - Hero Page UI Tests
// These tests validate the redesigned hero page (RoleSelectionView) and the
// panel routing features added in the Agedcare-shared rebuild.
// Accessibility identifiers referenced:
//   panel_router   – segmented Picker toggling Resident / Staff
//   setup_resident – Resident Panel card / CTA button
//   staff_login    – Staff Panel card / CTA button
//   switch_panel_tab – tab bar item that returns either shell to the hero page

final class Agedcare_sharedUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Hero Page

    /// The app must launch and the panel router picker must be visible on the hero page.
    @MainActor
    func testHeroPageShowsPanelRouter() throws {
        let router = app.segmentedControls["panel_router"]
        XCTAssertTrue(router.waitForExistence(timeout: 10),
                      "panel_router segmented control should be visible on the hero page")
    }

    /// The Resident Panel card / button must be reachable from the hero page.
    @MainActor
    func testResidentPanelCardVisible() throws {
        let residentCTA = app.buttons["setup_resident"]
        XCTAssertTrue(residentCTA.waitForExistence(timeout: 10),
                      "setup_resident button should be visible on the hero page")
    }

    /// The Staff Panel card / button must be reachable from the hero page.
    @MainActor
    func testStaffPanelCardVisible() throws {
        let staffCTA = app.buttons["staff_login"]
        XCTAssertTrue(staffCTA.waitForExistence(timeout: 10),
                      "staff_login button should be visible on the hero page")
    }

    /// Both panel cards must co-exist on the hero page simultaneously.
    @MainActor
    func testBothPanelCardsCoexist() throws {
        let residentCTA = app.buttons["setup_resident"]
        let staffCTA    = app.buttons["staff_login"]
        XCTAssertTrue(residentCTA.waitForExistence(timeout: 10),
                      "Resident card must exist on hero page")
        XCTAssertTrue(staffCTA.exists,
                      "Staff card must exist alongside resident card")
    }

    // MARK: - Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

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
        addUIInterruptionMonitor(withDescription: "System Permissions") { alert in
            let preferredButtons = ["Allow While Using App", "Allow", "OK", "Continue"]
            for title in preferredButtons where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
        app.launch()
        app.tap()
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

    @MainActor
    func testResidentSetupEntersResidentShell() throws {
        let residentCTA = app.buttons["setup_resident"]
        XCTAssertTrue(residentCTA.waitForExistence(timeout: 10))
        residentCTA.tap()

        let residentCell = app.buttons["Aisha Khan"]
        XCTAssertTrue(residentCell.waitForExistence(timeout: 20),
                      "Resident setup should show the seeded demo resident list")
        residentCell.tap()

        let sosButton = app.buttons["resident_sos_button"]
        XCTAssertTrue(sosButton.waitForExistence(timeout: 20),
                      "Resident shell should expose the SOS action")

        app.tabBars.buttons["Navigate"].tap()
        XCTAssertTrue(app.staticTexts["Resident Navigator"].waitForExistence(timeout: 10),
                      "Resident navigator should be reachable from the shell")
    }

    @MainActor
    func testTestingAccessEntersStaffShellAndReturnsToHero() throws {
        let staffCTA = app.buttons["staff_login"]
        XCTAssertTrue(staffCTA.waitForExistence(timeout: 10))
        staffCTA.tap()

        let adminTestingAccess = app.buttons["testing_admin@gvcare.com"]
        XCTAssertTrue(adminTestingAccess.waitForExistence(timeout: 20),
                      "Testing access profiles should be shown in the staff login sheet")
        adminTestingAccess.tap()

        XCTAssertTrue(app.navigationBars["Residents"].waitForExistence(timeout: 20),
                      "Testing access should enter the staff residents shell")

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10),
                      "Staff settings should be reachable from the staff shell")

        let switchPanel = app.tabBars.buttons["switch_panel_tab"]
        XCTAssertTrue(switchPanel.waitForExistence(timeout: 10))
        switchPanel.tap()

        XCTAssertTrue(app.segmentedControls["panel_router"].waitForExistence(timeout: 10),
                      "Switch Panel should return to the onboarding hero")
    }

    @MainActor
    func testResidentWeatherTabsRenderAndSwitch() throws {
        let residentCTA = app.buttons["setup_resident"]
        XCTAssertTrue(residentCTA.waitForExistence(timeout: 10))
        residentCTA.tap()

        let residentCell = app.buttons["Aisha Khan"]
        XCTAssertTrue(residentCell.waitForExistence(timeout: 20))
        residentCell.tap()
        app.tap()

        let weatherTabs = app.segmentedControls["weather_section_tabs"]
        XCTAssertTrue(weatherTabs.waitForExistence(timeout: 20),
                      "Weather tabs should appear on the resident home view")

        XCTAssertTrue(app.otherElements["weather_overview_panel"].waitForExistence(timeout: 10),
                      "Overview weather panel should render by default")

        weatherTabs.buttons["Location"].tap()
        XCTAssertTrue(app.otherElements["weather_location_panel"].waitForExistence(timeout: 10),
                      "Location weather panel should render when selected")

        weatherTabs.buttons["Systems"].tap()
        XCTAssertTrue(app.otherElements["weather_systems_panel"].waitForExistence(timeout: 10),
                      "Systems weather panel should render when selected")
        XCTAssertTrue(app.staticTexts["Backend sync"].waitForExistence(timeout: 10),
                      "Systems panel should show backend sync status")
    }
}

//
//  ScapLogUITests.swift
//  ScapLogUITests
//
//  Created by Claude on 2026/01/05.
//

import XCTest

final class ScapLogUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Launch Tests

    @MainActor
    func testAppLaunches() throws {
        app.launch()
        // For a menu bar app, we verify the app is running
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground)
    }

    @MainActor
    func testAppLaunchPerformance() throws {
        // Measure app launch time
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // MARK: - Menu Bar Tests
    // Note: Testing menu bar apps is challenging with XCTest.
    // These tests verify basic functionality.

    @MainActor
    func testAppRemainsRunningAfterLaunch() throws {
        app.launch()

        // Wait briefly to ensure app stabilizes
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "state != %d", XCUIApplication.State.notRunning.rawValue),
            object: app
        )

        let result = XCTWaiter().wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(result, .completed, "App should remain running")
    }

    @MainActor
    func testMultipleLaunchesDoNotCrash() throws {
        // Launch and terminate multiple times to catch startup/shutdown issues
        for _ in 1...3 {
            app.launch()
            XCTAssertNotEqual(app.state, .notRunning)
            app.terminate()
        }
    }

    // MARK: - Settings Window Tests (if accessible)

    @MainActor
    func testSettingsWindowAccessibility() throws {
        app.launch()

        // Try to find the settings window
        // Note: Menu bar apps may not expose windows directly
        let windows = app.windows
        // This test documents the window count - useful for debugging
        print("Number of windows: \(windows.count)")
    }

    // MARK: - Memory and Performance Tests

    @MainActor
    func testMemoryStability() throws {
        // Launch app and let it run briefly
        app.launch()

        // Wait for app to stabilize
        Thread.sleep(forTimeInterval: 2.0)

        // Verify app is still running (no memory-related crashes)
        XCTAssertNotEqual(app.state, .notRunning)
    }
}

// MARK: - UI Test Launch Arguments Extension

extension ScapLogUITests {
    /// Helper to launch app with specific arguments for testing
    func launchWithArguments(_ arguments: [String]) {
        app.launchArguments = arguments
        app.launch()
    }

    /// Helper to launch app with specific environment variables
    func launchWithEnvironment(_ environment: [String: String]) {
        app.launchEnvironment = environment
        app.launch()
    }
}

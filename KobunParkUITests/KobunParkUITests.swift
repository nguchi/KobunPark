//
//  KobunParkUITests.swift
//  KobunParkUITests
import XCTest

final class KobunParkUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFormatsJSONAndClearsWorkspace() throws {
        let app = XCUIApplication()
        app.launch()

        let input = app.textViews["json-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        input.click()
        input.typeText(#"{"name":"KobunPark"}"#)

        app.buttons["json-run"].click()
        XCTAssertTrue(app.staticTexts["json-valid"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["json-copy-result"].isEnabled)

        app.buttons["json-clear-all"].click()
        XCTAssertEqual(input.value as? String, "")
        XCTAssertFalse(app.buttons["json-copy-result"].isEnabled)

        app.buttons["undo"].click()
        XCTAssertEqual(input.value as? String, #"{"name":"KobunPark"}"#)
        XCTAssertTrue(app.buttons["json-copy-result"].isEnabled)

        app.buttons["redo"].click()
        XCTAssertEqual(input.value as? String, "")
    }

    @MainActor
    func testEncodesURLComponentAndClearsWorkspace() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["文字列"].click()
        let input = app.textViews["url-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        input.click()
        input.typeText("hello world")

        app.buttons["url-run"].click()
        XCTAssertTrue(app.staticTexts["url-success"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["url-copy-result"].isEnabled)

        app.buttons["url-clear-all"].click()
        XCTAssertEqual(input.value as? String, "")
        XCTAssertFalse(app.buttons["url-copy-result"].isEnabled)
    }

    @MainActor
    func testEncodesBase64String() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["文字列"].click()
        app.buttons["Base64"].click()
        let input = app.textViews["url-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        input.click()
        input.typeText("KobunPark")

        app.buttons["url-run"].click()
        XCTAssertTrue(app.staticTexts["url-success"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["url-output"].label.contains("S29idW5QYXJr"))
    }

    @MainActor
    func testConvertsCSVToMarkdownAndClearsWorkspace() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["CSV"].click()
        let input = app.textViews["csv-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        input.click()
        input.typeText("name,value\nKobunPark,1")

        app.buttons["csv-run"].click()
        XCTAssertTrue(app.staticTexts["csv-success"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["csv-copy-result"].isEnabled)

        app.buttons["csv-clear-all"].click()
        XCTAssertEqual(input.value as? String, "")
        app.buttons["undo"].click()
        XCTAssertEqual(input.value as? String, "name,value\nKobunPark,1")
    }

    @MainActor
    func testPreviewsLaTeXOfflineAndRestoresAfterClear() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["LaTeX"].click()
        let input = app.textViews["latex-input"]
        XCTAssertTrue(input.waitForExistence(timeout: 3))
        app.buttons["input-assist-latex-root"].click()
        input.typeText("1+1")
        XCTAssertEqual(input.value as? String, #"\sqrt{1+1}"#)

        app.buttons["latex-preview"].click()
        XCTAssertTrue(app.staticTexts["latex-success"].waitForExistence(timeout: 3))

        app.buttons["latex-clear-all"].click()
        XCTAssertEqual(input.value as? String, "")
        app.buttons["undo"].click()
        XCTAssertEqual(input.value as? String, #"\sqrt{1+1}"#)
    }

    @MainActor
    func testRegularExpressionMatchesAndPreviewsReplacement() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["正規表現"].click()
        let pattern = app.textFields["regex-pattern"]
        let target = app.textViews["regex-target"]
        XCTAssertTrue(pattern.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["input-assist-regex-digit"].exists)
        pattern.click()
        pattern.typeText(#"([A-Za-z]+)-(\d+)"#)
        target.click()
        target.typeText("item-12 test-34")
        app.switches["regex-replacement-enabled"].click()
        let replacement = app.textFields["regex-replacement"]
        replacement.click()
        replacement.typeText("$2 $1")

        app.buttons["regex-run"].click()
        XCTAssertTrue(app.staticTexts["regex-success"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["regex-match-count"].label.contains("2"))
        XCTAssertTrue(app.staticTexts["regex-replacement-preview"].waitForExistence(timeout: 2))

        app.buttons["regex-clear-all"].click()
        XCTAssertEqual(target.value as? String, "")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

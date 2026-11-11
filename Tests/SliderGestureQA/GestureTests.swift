import XCTest
final class GestureTests:XCTestCase {
    func testDoubleTapAndDrag() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--verify-slider-gestures"];app.launch()
        let slider = app.sliders["testSlider"],value = app.staticTexts["testValue"]
        XCTAssertTrue(slider.waitForExistence(timeout:15))
        slider.doubleTap()
        XCTAssertEqual(value.label,"0.25")
        XCTAssertEqual(app.staticTexts["resetCount"].label,"1")
        app.buttons["setChanged"].tap()
        let start = slider.coordinate(withNormalizedOffset:CGVector(dx:0.75,dy:0.5)),end = slider.coordinate(withNormalizedOffset:CGVector(dx:0.35,dy:0.5))
        start.press(forDuration:0.05,thenDragTo:end)
        XCTAssertNotEqual(value.label,"0.75")
        XCTAssertNotEqual(value.label,"0.25")
        slider.doubleTap()
        XCTAssertEqual(value.label,"0.25")
        XCTAssertEqual(app.staticTexts["resetCount"].label,"2")
    }
    func testEditorExposureResetAndUndo() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--demo-editor"];app.launch()
        let slider = app.sliders["Exposure"]
        XCTAssertTrue(slider.waitForExistence(timeout:30))
        slider.adjust(toNormalizedSliderPosition:0.85)
        let changed = slider.value as? String
        slider.doubleTap()
        XCTAssertEqual(slider.value as? String,"0")
        app.buttons["Undo"].tap()
        XCTAssertEqual(slider.value as? String,changed)
        let attachment = XCTAttachment(screenshot:app.screenshot());attachment.name = "Actual editor slider reset and undo";attachment.lifetime = .keepAlways;add(attachment)
    }

}

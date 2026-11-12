import XCTest
final class GestureTests:XCTestCase {
    func testCropCornerResizeMoveUndoAndRatio() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--demo-editor","--neutral-demo","--tool","Crop"];app.launch()
        let corner = app.otherElements["cropCorner.bottomRight"].firstMatch
        XCTAssertTrue(corner.waitForExistence(timeout:30))
        let initial = corner.frame
        let begin = corner.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        begin.press(forDuration:0.05,thenDragTo:begin.withOffset(CGVector(dx:-45,dy:-65)))
        XCTAssertLessThan(corner.frame.midX,initial.midX-15)
        let shrunk = corner.frame
        let attachment = XCTAttachment(screenshot:app.screenshot());attachment.name = "Direct crop handles";attachment.lifetime = .keepAlways;add(attachment)
        app.buttons["Undo"].tap();XCTAssertEqual(corner.frame.midX,initial.midX,accuracy:2)
        app.buttons["Redo"].tap();XCTAssertEqual(corner.frame.midX,shrunk.midX,accuracy:2)
        let top = app.otherElements["cropCorner.topLeft"].firstMatch
        let center = app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:(top.frame.midX+corner.frame.midX)/2,dy:(top.frame.midY+corner.frame.midY)/2))
        center.press(forDuration:0.05,thenDragTo:center.withOffset(CGVector(dx:15,dy:15)))
        XCTAssertGreaterThan(corner.frame.midX,shrunk.midX+5)
        app.buttons["1:1"].tap()
        XCTAssertEqual(corner.frame.midX-top.frame.midX,corner.frame.midY-top.frame.midY,accuracy:2)
        let start = corner.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        start.press(forDuration:0.05,thenDragTo:start.withOffset(CGVector(dx:-30,dy:-50)))
        XCTAssertEqual(corner.frame.midX-top.frame.midX,corner.frame.midY-top.frame.midY,accuracy:2)
    }
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

    func testTrackingSheetAnalyzeAndClear() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--tracking-demo"];app.launch()
        let target = app.sliders["Target horizontal position"]
        XCTAssertTrue(target.waitForExistence(timeout:30))
        let value = target.value as? String
        target.adjust(toNormalizedSliderPosition:0.7)
        XCTAssertNotEqual(target.value as? String,value)
        target.doubleTap()
        XCTAssertEqual(target.value as? String,value)
        let targetFrame = app.otherElements["trackingFrame"].firstMatch
        XCTAssertTrue(targetFrame.exists)
        let begin = targetFrame.coordinate(withNormalizedOffset:CGVector(dx:0.3,dy:0.5)),end = targetFrame.coordinate(withNormalizedOffset:CGVector(dx:0.4,dy:0.5))
        begin.press(forDuration:0.05,thenDragTo:end)
        XCTAssertNotEqual(target.value as? String,value)
        target.doubleTap();XCTAssertEqual(target.value as? String,value)
        let seedImage = XCTAttachment(screenshot:app.screenshot());seedImage.name = "Tracking target sheet";seedImage.lifetime = .keepAlways;add(seedImage)
        let button = app.buttons["trackingAnalyze"]
        if !button.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(button.isEnabled);button.tap()
        let clear = app.buttons["Clear tracking"]
        XCTAssertTrue(clear.waitForExistence(timeout:45))
        if !clear.isHittable { app.scrollViews.firstMatch.swipeUp() }
        let attachment = XCTAttachment(screenshot:app.screenshot());attachment.name = "Tracked radial mask editor";attachment.lifetime = .keepAlways;add(attachment)
        clear.tap()
        XCTAssertTrue(app.buttons["Track mask"].exists)
    }

    func testAutomaticSkyMaskAndRefinement() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--demo-editor","--neutral-demo","--tool","Masks"];app.launch()
        let add = app.buttons["Add mask"]
        XCTAssertTrue(add.waitForExistence(timeout:30));add.tap();app.buttons["Sky"].tap()
        let create = app.buttons["createAutomaticMask"]
        XCTAssertTrue(create.waitForExistence(timeout:15))
        if !create.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(create.isEnabled);create.tap()
        let recreate = app.buttons["Recreate sky selection"]
        XCTAssertTrue(recreate.waitForExistence(timeout:30))
        let refine = app.buttons["Refine automatic selection"]
        if !refine.isHittable { app.scrollViews.firstMatch.swipeUp() };refine.tap()
        let threshold = app.sliders["Selection threshold"]
        XCTAssertTrue(threshold.waitForExistence(timeout:10))
        if !threshold.isHittable { app.scrollViews.firstMatch.swipeUp() }
        let original = threshold.value as? String
        threshold.adjust(toNormalizedSliderPosition:0.8);XCTAssertNotEqual(threshold.value as? String,original)
        threshold.doubleTap();XCTAssertEqual(threshold.value as? String,original)
        let capture = XCTAttachment(screenshot:app.screenshot());capture.name = "Sky selection and refinement";capture.lifetime = .keepAlways;self.add(capture)
        if !add.isHittable { app.scrollViews.firstMatch.swipeDown() }
        add.tap();app.buttons["Subject"].tap()
        XCTAssertTrue(app.buttons["createAutomaticMask"].waitForExistence(timeout:15))
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Recreate sky selection"].exists)
        XCTAssertFalse(app.buttons["Recreate subject selection"].exists)
    }

}

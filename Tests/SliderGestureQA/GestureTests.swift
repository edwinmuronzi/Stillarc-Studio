import XCTest
final class GestureTests:XCTestCase {
    private func resumeCrop(_ app:XCUIApplication) {
        if app.buttons["Adjust crop"].exists { app.buttons["Adjust crop"].tap() }
    }
    func testCropCornerResizeMoveUndoAndRatio() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--demo-editor","--neutral-demo","--tool","Crop"];app.launch()
        XCTAssertTrue(app.buttons["1:1"].waitForExistence(timeout:30));resumeCrop(app)
        let corner = app.otherElements["cropCorner.bottomRight"].firstMatch
        let initial = corner.frame
        let begin = corner.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        begin.press(forDuration:0.05,thenDragTo:begin.withOffset(CGVector(dx:-45,dy:-65)))
        XCTAssertLessThan(corner.frame.midX,initial.midX-15)
        let shrunk = corner.frame
        app.buttons["Undo"].tap();resumeCrop(app);XCTAssertEqual(corner.frame.midX,initial.midX,accuracy:2)
        app.buttons["Redo"].tap();resumeCrop(app);XCTAssertEqual(corner.frame.midX,shrunk.midX,accuracy:2)
        let top = app.otherElements["cropCorner.topLeft"].firstMatch
        let center = app.coordinate(withNormalizedOffset:.zero).withOffset(CGVector(dx:(top.frame.midX+corner.frame.midX)/2,dy:(top.frame.midY+corner.frame.midY)/2))
        center.press(forDuration:0.05,thenDragTo:center.withOffset(CGVector(dx:15,dy:15)))
        XCTAssertGreaterThan(corner.frame.midX,shrunk.midX+5)
        app.buttons["1:1"].tap();resumeCrop(app)
        XCTAssertEqual(corner.frame.midX-top.frame.midX,corner.frame.midY-top.frame.midY,accuracy:2)
        let start = corner.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        start.press(forDuration:0.05,thenDragTo:start.withOffset(CGVector(dx:-30,dy:-50)))
        XCTAssertEqual(corner.frame.midX-top.frame.midX,corner.frame.midY-top.frame.midY,accuracy:2)
        XCTAssertTrue(app.buttons["Adjust crop"].waitForExistence(timeout:5))
        let attachment = XCTAttachment(screenshot:app.screenshot());attachment.name = "Large fitted crop preview";attachment.lifetime = .keepAlways;add(attachment)
    }
    func testAutomaticMaskImmediateCropExportAndDetail() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--demo-editor","--neutral-demo","--crop-mask-demo","--tool","Crop"];app.launch()
        let square = app.buttons["1:1"];XCTAssertTrue(square.waitForExistence(timeout:30));square.tap()
        app.buttons["Export photo"].tap()
        let create = app.buttons["Create export"];XCTAssertTrue(create.waitForExistence(timeout:10))
        if !create.isHittable { app.scrollViews.firstMatch.swipeUp() };create.tap()
        XCTAssertTrue(app.buttons["Share or save to Files"].waitForExistence(timeout:30))
        let image = XCTAttachment(screenshot:app.screenshot());image.name = "Automatic mask crop export succeeds";image.lifetime = .keepAlways;add(image)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Adjust crop"].waitForExistence(timeout:6))
        app.buttons["Expand preview"].tap();XCTAssertTrue(app.buttons["Show adjustments"].exists)
        let expanded = XCTAttachment(screenshot:app.screenshot());expanded.name = "Expanded cropped preview";expanded.lifetime = .keepAlways;add(expanded)
        app.buttons["Show adjustments"].tap();app.buttons["Detail"].tap()
        let texture = app.sliders["Texture"];XCTAssertTrue(texture.waitForExistence(timeout:10))
        texture.adjust(toNormalizedSliderPosition:0.8);XCTAssertNotEqual(texture.value as? String,"0")
        texture.doubleTap();XCTAssertEqual(texture.value as? String,"0")
        XCTAssertTrue(app.sliders["Clarity"].exists)
        let dehaze = app.sliders["Dehaze"]
        dehaze.doubleTap() // Native accessibility scrolls the complete slider into view.
        XCTAssertTrue(dehaze.isHittable);dehaze.adjust(toNormalizedSliderPosition:0.75)
        XCTAssertNotEqual(dehaze.value as? String,"0")
        let screenshot = XCTAttachment(screenshot:app.screenshot());screenshot.name = "Live Dehaze detail control";screenshot.lifetime = .keepAlways;add(screenshot)
        dehaze.doubleTap();XCTAssertEqual(dehaze.value as? String,"0")
    }
    func testVideoPlaybackControlsAppearAndHide() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--video-demo","--neutral-demo"];app.launch()
        XCTAssertTrue(app.buttons["Export video"].waitForExistence(timeout:30))
        XCTAssertFalse(app.buttons["Play video"].exists)
        let reveal = app.buttons["playbackReveal"]
        XCTAssertTrue(reveal.waitForExistence(timeout:10));reveal.tap()
        let play = app.buttons["Play video"];XCTAssertTrue(play.waitForExistence(timeout:5));play.tap()
        let pause = app.buttons["Pause video"];XCTAssertTrue(pause.waitForExistence(timeout:5))
        let hidden = XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:pause)
        XCTAssertEqual(XCTWaiter.wait(for:[hidden],timeout:7),.completed)
        reveal.tap();XCTAssertTrue(app.buttons["Trim video"].waitForExistence(timeout:5))
        let attachment = XCTAttachment(screenshot:app.screenshot());attachment.name = "Large video preview and playback on tap";attachment.lifetime = .keepAlways;add(attachment)
    }
    func testLevelsUndoResetAndReopen() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--demo-editor","--neutral-demo","--tool","Curves"];app.launch()
        let levels = app.buttons["Levels"];XCTAssertTrue(levels.waitForExistence(timeout:30));levels.tap()
        let black = app.sliders["Input black"];XCTAssertTrue(black.waitForExistence(timeout:10));black.doubleTap()
        black.adjust(toNormalizedSliderPosition:0.15);let changed = black.value as? String;XCTAssertNotEqual(changed,"0")
        app.buttons["Undo"].tap();XCTAssertEqual(black.value as? String,"0")
        app.buttons["Redo"].tap();XCTAssertEqual(black.value as? String,changed)
        let gamma = app.sliders["Midtones"];gamma.doubleTap();gamma.adjust(toNormalizedSliderPosition:0.65)
        XCTAssertNotEqual(gamma.value as? String,"1");gamma.doubleTap();XCTAssertEqual(gamma.value as? String,"1")
        let image = XCTAttachment(screenshot:app.screenshot());image.name = "Levels controls and large preview";image.lifetime = .keepAlways;add(image)
        app.buttons["Back to workspace"].tap()
        XCTAssertTrue(app.buttons["About Stillarc Studio"].waitForExistence(timeout:10))
        app.terminate();app.launchArguments = ["--demo-editor","--tool","Curves"];app.launch()
        XCTAssertTrue(app.buttons["Levels"].waitForExistence(timeout:30));app.buttons["Levels"].tap()
        XCTAssertEqual(app.sliders["Input black"].value as? String,changed)
    }
    func testWorkspaceFavoritesRatingsSearchAndSort() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--organization-demo"];app.launch()
        let search = app.textFields["workspaceSearch"];XCTAssertTrue(search.waitForExistence(timeout:30));search.tap();search.typeText("Studio sample")
        app.keyboards.buttons["Search"].tap()
        let card = app.buttons["Manage Studio sample"]
        if !card.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout:10));card.tap()
        app.buttons["Mark favorite"].tap();XCTAssertFalse(app.buttons["Back to workspace"].exists)
        if !app.buttons["Filter workspace"].isHittable { app.scrollViews.firstMatch.swipeDown() }
        app.buttons["Filter workspace"].tap();app.buttons["Favorites"].tap()
        if !card.isHittable { app.scrollViews.firstMatch.swipeUp() };card.tap()
        app.buttons["Rate"].tap();app.buttons["4 stars"].tap()
        if !app.buttons["Sort workspace"].isHittable { app.scrollViews.firstMatch.swipeDown() }
        app.buttons["Sort workspace"].tap();app.buttons["Highest rated"].tap()
        XCTAssertEqual(app.buttons["Sort workspace"].value as? String,"Highest rated")
        let screenshot = XCTAttachment(screenshot:app.screenshot());screenshot.name = "Search favorites ratings and sorting";screenshot.lifetime = .keepAlways;add(screenshot)
        app.terminate();app.launchArguments = [];app.launch()
        XCTAssertTrue(app.buttons["Filter workspace"].waitForExistence(timeout:30))
        XCTAssertEqual(app.buttons["Filter workspace"].value as? String,"Favorites")
        XCTAssertEqual(app.buttons["Sort workspace"].value as? String,"Highest rated")
        search.tap();search.typeText("Studio sample");app.keyboards.buttons["Search"].tap()
        if !card.isHittable { app.scrollViews.firstMatch.swipeUp() };card.tap()
        XCTAssertTrue(app.buttons["Remove favorite"].exists)
    }
    func testFilmHalationGrainAndLensReset() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--demo-editor","--neutral-demo","--tool","Film"];app.launch()
        let grain = app.sliders["Grain"];XCTAssertTrue(grain.waitForExistence(timeout:30));grain.doubleTap();grain.adjust(toNormalizedSliderPosition:0.5)
        let size = app.sliders["Grain size"];XCTAssertTrue(size.waitForExistence(timeout:5));size.doubleTap();size.adjust(toNormalizedSliderPosition:0.7)
        let halo = app.sliders["Halation"];halo.doubleTap();halo.adjust(toNormalizedSliderPosition:0.6)
        XCTAssertEqual(app.buttons["Film"].value as? String,"Adjustments applied")
        let shot = XCTAttachment(screenshot:app.screenshot());shot.name = "Natural grain and halation";shot.lifetime = .keepAlways;add(shot)
        app.buttons["Crop"].tap();app.buttons["Lens correction"].tap()
        let lens = app.sliders["Lens distortion"];XCTAssertTrue(lens.waitForExistence(timeout:5));lens.doubleTap();lens.adjust(toNormalizedSliderPosition:0.7)
        XCTAssertEqual(app.buttons["Crop"].value as? String,"Adjustments applied")
        lens.doubleTap();XCTAssertEqual(app.buttons["Crop"].value as? String,"No adjustments")
        app.buttons["Back to workspace"].tap()
        app.terminate();app.launchArguments = [];app.launch()
        let search = app.textFields["workspaceSearch"];XCTAssertTrue(search.waitForExistence(timeout:10));search.tap();search.typeText("Studio sample");app.keyboards.buttons["Search"].tap()
        app.scrollViews.firstMatch.swipeUp();app.buttons["Open Studio sample"].tap()
        XCTAssertTrue(app.buttons["Film"].waitForExistence(timeout:15));XCTAssertEqual(app.buttons["Film"].value as? String,"Adjustments applied")
    }
    func testNewLogProfilesAndColorLUTExport() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--demo-editor","--neutral-demo","--color-tools-demo"];app.launch()
        XCTAssertTrue(app.buttons["Input conversion"].waitForExistence(timeout:30));app.buttons["Input conversion"].tap()
        app.descendants(matching:.any)["inputProfilePicker"].tap();app.buttons["Sony S-Log3 · S-Gamut3.Cine"].tap()
        XCTAssertTrue(app.buttons["Reset input conversion"].waitForExistence(timeout:5))
        app.descendants(matching:.any)["inputProfilePicker"].tap();app.buttons["Panasonic V-Log · V-Gamut"].tap()
        app.buttons["Reset input conversion"].tap();app.navigationBars["Input conversion"].buttons["Done"].tap()
        app.buttons["Looks"].tap();app.buttons["Looks & presets"].tap()
        let search = app.searchFields.firstMatch;XCTAssertTrue(search.waitForExistence(timeout:5));search.tap();search.typeText("QA Color LUT");app.keyboards.buttons["Search"].tap()
        app.buttons["QA Color LUT"].tap()
        app.buttons["Looks"].tap();app.buttons["Looks & presets"].tap();app.buttons["Export current color as LUT"].tap()
        let create = app.buttons["createColorLUT"];XCTAssertTrue(create.waitForExistence(timeout:5));create.tap()
        XCTAssertTrue(app.buttons["Share color LUT"].waitForExistence(timeout:25))
        let shot = XCTAttachment(screenshot:app.screenshot());shot.name = "Color LUT export";shot.lifetime = .keepAlways;add(shot)
    }
    func testPresetSearchRenameDuplicate() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--demo-editor","--neutral-demo","--color-tools-demo"];app.launch()
        XCTAssertTrue(app.buttons["Looks"].waitForExistence(timeout:30));app.buttons["Looks"].tap();app.buttons["Looks & presets"].tap()
        let search = app.searchFields.firstMatch;XCTAssertTrue(search.waitForExistence(timeout:5));search.tap();search.typeText("QA Color LUT");app.keyboards.buttons["Search"].tap()
        app.buttons["Manage QA Color LUT"].tap();app.buttons["Rename preset"].tap()
        let name = app.alerts.textFields["Preset name"];name.tap();name.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:12)+"QA Renamed")
        app.alerts.buttons["Save"].tap()
        search.tap();search.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:12)+"QA Renamed");app.keyboards.buttons["Search"].tap()
        let manage = app.buttons["Manage QA Renamed"];XCTAssertTrue(manage.waitForExistence(timeout:5));manage.tap();app.buttons["Duplicate preset"].tap()
        XCTAssertTrue(app.buttons["Manage QA Renamed copy"].waitForExistence(timeout:5))
        manage.tap();app.buttons["Export color as LUT"].tap();XCTAssertTrue(app.buttons["createColorLUT"].waitForExistence(timeout:5))
    }
    func testBatchExportPrivacyChoicesAndRetry() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--batch-demo","--privacy-demo"];app.launch()
        XCTAssertTrue(app.staticTexts["Added 2 of 2."].waitForExistence(timeout:30))
        let search = app.textFields["workspaceSearch"];search.tap();search.typeText("Studio batch QA");app.keyboards.buttons["Search"].tap()
        app.buttons["Select"].tap();app.buttons["Select shown"].tap();app.buttons["Export 2"].tap()
        app.buttons["Metadata & privacy"].tap()
        let location = app.switches["Include location"],names = app.switches["Use project names in filenames"]
        XCTAssertEqual(location.value as? String,"0");location.tap();names.tap()
        app.buttons["Metadata & privacy"].tap();app.buttons["createBatchExport"].tap()
        XCTAssertTrue(app.buttons["Share or save files"].waitForExistence(timeout:20));app.buttons["Change export options"].tap()
        app.buttons["Metadata & privacy"].tap();XCTAssertEqual(location.value as? String,"1");XCTAssertEqual(names.value as? String,"1")
        app.buttons["Remove identifying metadata"].tap();XCTAssertEqual(location.value as? String,"0");XCTAssertEqual(names.value as? String,"0")
        let shot = XCTAttachment(screenshot:app.screenshot());shot.name = "Batch export metadata and privacy";shot.lifetime = .keepAlways;add(shot)
    }
    func testSinglePhotoExportPrivacyControls() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--demo-editor","--neutral-demo","--privacy-demo"];app.launch()
        XCTAssertTrue(app.buttons["Export photo"].waitForExistence(timeout:30));app.buttons["Export photo"].tap()
        app.buttons["Metadata & privacy"].tap();app.switches["Include capture date"].tap();app.switches["Include camera details"].tap()
        app.buttons["Metadata & privacy"].tap();app.buttons["Create export"].tap()
        XCTAssertTrue(app.buttons["Share or save to Files"].waitForExistence(timeout:30));app.buttons["Change export options"].tap()
        app.buttons["Metadata & privacy"].tap();XCTAssertEqual(app.switches["Include capture date"].value as? String,"1")
        app.buttons["Remove identifying metadata"].tap();XCTAssertEqual(app.switches["Include capture date"].value as? String,"0")
    }
    func testHomeRevertToOriginal() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--batch-demo","--batch-paste-demo"];app.launch()
        XCTAssertTrue(app.staticTexts["Added 2 of 2."].waitForExistence(timeout:30))
        let search = app.textFields["workspaceSearch"];search.tap();search.typeText("Studio batch QA");app.keyboards.buttons["Search"].tap();app.scrollViews.firstMatch.swipeUp()
        app.buttons["Manage Studio batch QA 1"].tap();app.buttons["doc.on.clipboard"].tap()
        XCTAssertTrue(app.buttons["applyBatchPaste"].waitForExistence(timeout:5));app.buttons["applyBatchPaste"].tap()
        XCTAssertTrue(app.staticTexts["Applied to 1 of 1."].waitForExistence(timeout:10));app.navigationBars["Paste adjustments"].buttons["Done"].tap()
        app.buttons["Manage Studio batch QA 1"].tap();app.buttons["Revert to original"].tap()
        app.buttons["Revert to original"].tap()
        app.buttons["Open Studio batch QA 1"].tap()
        XCTAssertTrue(app.buttons["Light"].waitForExistence(timeout:15));XCTAssertEqual(app.buttons["Light"].value as? String,"No adjustments")
    }
    func testInstantSelectionAndHomeCopyPaste() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--batch-demo"];app.launch()
        XCTAssertTrue(app.staticTexts["Added 2 of 2."].waitForExistence(timeout:30))
        let search = app.textFields["workspaceSearch"];search.tap();search.typeText("Studio batch QA");app.keyboards.buttons["Search"].tap();app.scrollViews.firstMatch.swipeUp()
        app.buttons["Manage Studio batch QA 1"].tap();app.buttons["Copy adjustments"].tap()
        XCTAssertTrue(app.buttons["copyHomeAdjustments"].waitForExistence(timeout:5));app.buttons["copyHomeAdjustments"].tap()
        let other = app.buttons["Open Studio batch QA 2"]
        other.press(forDuration:1);app.buttons["Copy adjustments"].tap()
        XCTAssertTrue(app.navigationBars["Copy adjustments"].waitForExistence(timeout:5));app.navigationBars["Copy adjustments"].buttons["Done"].tap()
        app.buttons["Manage Studio batch QA 2"].tap();app.buttons["doc.on.clipboard"].tap()
        XCTAssertTrue(app.buttons["applyBatchPaste"].waitForExistence(timeout:5));app.buttons["applyBatchPaste"].tap()
        XCTAssertTrue(app.staticTexts["Applied to 1 of 1."].waitForExistence(timeout:10));app.navigationBars["Paste adjustments"].buttons["Done"].tap()
        app.scrollViews.firstMatch.swipeDown();app.buttons["Select"].tap();app.scrollViews.firstMatch.swipeUp()
        let item = app.buttons["Select Studio batch QA 1"]
        item.tap();XCTAssertEqual(item.value as? String,"Selected")
        item.tap();XCTAssertNotEqual(item.value as? String,"Selected")
        item.tap();app.buttons["Select Studio batch QA 2"].tap()
        item.press(forDuration:1);app.buttons["Rate selected"].tap();app.buttons["5 stars"].tap()
        app.buttons["Manage Studio batch QA 1"].tap();XCTAssertTrue(app.buttons["Export selected"].waitForExistence(timeout:5))
        app.buttons["Export selected"].tap();XCTAssertTrue(app.buttons["createBatchExport"].waitForExistence(timeout:5))
    }
    func testSelectedHoldActionsTrashPreviewAndBatchPaste() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--batch-demo","--batch-paste-demo"];app.launch()
        XCTAssertTrue(app.staticTexts["Added 2 of 2."].waitForExistence(timeout:30))
        let search = app.textFields["workspaceSearch"];search.tap();search.typeText("Studio batch QA");app.keyboards.buttons["Search"].tap()
        app.buttons["Select"].tap();app.buttons["Select shown"].tap();app.scrollViews.firstMatch.swipeUp()
        let project = app.buttons["Select Studio batch QA 1"]
        project.press(forDuration:1)
        XCTAssertTrue(app.buttons["Favourite selected"].waitForExistence(timeout:5));app.buttons["Favourite selected"].tap()
        project.press(forDuration:1);app.buttons["Export selected"].tap()
        XCTAssertTrue(app.buttons["createBatchExport"].waitForExistence(timeout:5));app.navigationBars["Batch export"].buttons["Done"].tap()
        project.press(forDuration:1);app.buttons["doc.on.clipboard"].tap()
        let apply = app.buttons["applyBatchPaste"];XCTAssertTrue(apply.waitForExistence(timeout:5));apply.tap()
        XCTAssertTrue(app.staticTexts["Applied to 2 of 2."].waitForExistence(timeout:10));app.navigationBars["Paste adjustments"].buttons["Done"].tap()
        project.press(forDuration:1);app.buttons["Delete selected"].firstMatch.tap();app.buttons["Delete 2 projects"].tap()
        XCTAssertTrue(app.staticTexts["No matching items"].waitForExistence(timeout:10));app.scrollViews.firstMatch.swipeDown();app.buttons["Recently Deleted"].tap()
        XCTAssertTrue(app.staticTexts["30 days left"].firstMatch.waitForExistence(timeout:10))
        let preview = app.buttons["Preview deleted Studio batch QA 1"]
        if !preview.isHittable { app.swipeUp() };preview.tap()
        XCTAssertTrue(app.navigationBars["Studio batch QA 1"].waitForExistence(timeout:5));app.navigationBars["Studio batch QA 1"].buttons["Done"].tap()
        let shot = XCTAttachment(screenshot:app.screenshot());shot.name = "Trash thumbnails and days remaining";shot.lifetime = .keepAlways;add(shot)
    }
    func testProjectHoldFavoriteAndBulkDelete() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--batch-demo"];app.launch()
        XCTAssertTrue(app.staticTexts["Added 2 of 2."].waitForExistence(timeout:30))
        XCTAssertTrue(app.buttons["Recently Deleted"].exists)
        let search = app.textFields["workspaceSearch"];search.tap();search.typeText("Studio batch QA");app.keyboards.buttons["Search"].tap()
        app.scrollViews.firstMatch.swipeUp()
        let project = app.buttons["Open Studio batch QA 1"]
        project.doubleTap()
        XCTAssertFalse(app.buttons["Back to workspace"].exists)
        project.press(forDuration:1)
        XCTAssertTrue(app.buttons["Remove favorite"].waitForExistence(timeout:5))
        XCTAssertTrue(app.buttons["Rate"].exists)
        let hold = XCTAttachment(screenshot:app.screenshot());hold.name = "Project hold preview and actions";hold.lifetime = .keepAlways;add(hold)
        app.buttons["Select project"].tap()
        app.buttons["Select shown"].tap()
        app.buttons["Delete selected"].firstMatch.tap()
        app.buttons["Delete 2 projects"].tap()
        XCTAssertTrue(app.staticTexts["No matching items"].waitForExistence(timeout:10))
        app.scrollViews.firstMatch.swipeDown()
        app.buttons["Recently Deleted"].tap()
        XCTAssertTrue(app.buttons["Restore"].firstMatch.waitForExistence(timeout:10))
        app.navigationBars["Recently Deleted"].buttons["Done"].tap()
        app.buttons["Delete"].tap();app.buttons["Delete all projects…"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format:"label BEGINSWITH 'Delete ' AND label ENDSWITH ' projects'")).firstMatch.waitForExistence(timeout:5))
        app.coordinate(withNormalizedOffset:CGVector(dx:0.9,dy:0.15)).tap()
        XCTAssertTrue(app.buttons["Recently Deleted"].exists)
    }
    func testCurvesScrollWithoutEditingAndExplicitEdit() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--demo-editor","--neutral-demo","--tool","Curves"];app.launch()
        let graph = app.otherElements["rgbCurveGraph"].firstMatch,panel = app.scrollViews["editorAdjustments"]
        XCTAssertTrue(graph.waitForExistence(timeout:30))
        panel.swipeUp()
        XCTAssertEqual(app.buttons["Curves"].value as? String,"No adjustments")
        let before = graph.frame.minY
        let begin = graph.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.75))
        begin.press(forDuration:0.05,thenDragTo:begin.withOffset(CGVector(dx:0,dy:70)))
        XCTAssertEqual(app.buttons["Curves"].value as? String,"No adjustments")
        XCTAssertNotEqual(graph.frame.minY,before)
        let edit = app.buttons["Edit curve points"]
        if !edit.isHittable { panel.swipeDown() };edit.tap()
        if graph.frame.midY > panel.frame.maxY-40 {
            let gutter = panel.coordinate(withNormalizedOffset:CGVector(dx:0.97,dy:0.85))
            gutter.press(forDuration:0.05,thenDragTo:gutter.withOffset(CGVector(dx:0,dy:-160)))
        }
        let middle = graph.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        middle.press(forDuration:0.05,thenDragTo:middle.withOffset(CGVector(dx:0,dy:-20)))
        XCTAssertEqual(app.buttons["Curves"].value as? String,"Adjustments applied")
        app.buttons["Undo"].tap();XCTAssertEqual(app.buttons["Curves"].value as? String,"No adjustments")
        let shot = XCTAttachment(screenshot:app.screenshot());shot.name = "Scroll-safe curves and edit mode";shot.lifetime = .keepAlways;add(shot)
    }
    func testHomeKeyboardDismissAndFloatingPanel() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = [];app.launch()
        let search = app.textFields["workspaceSearch"]
        XCTAssertTrue(search.waitForExistence(timeout:30));search.tap();search.typeText("Studio")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        app.staticTexts["Your workspace"].tap()
        let hidden = XCTNSPredicateExpectation(predicate:NSPredicate(format:"exists == false"),object:app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for:[hidden],timeout:5),.completed)
        let shot = XCTAttachment(screenshot:app.screenshot());shot.name = "Floating import panel and dismissed keyboard";shot.lifetime = .keepAlways;add(shot)
        search.tap();search.typeText(" sample");XCTAssertTrue(app.keyboards.firstMatch.exists)
    }
    func testBatchImportExportAndRecentlyDeleted() throws {
        let app = XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments = ["--batch-demo"];app.launch()
        XCTAssertTrue(app.staticTexts["Added 2 of 2."].waitForExistence(timeout:30))
        let search = app.textFields["workspaceSearch"];search.tap();search.typeText("Studio batch QA");app.keyboards.buttons["Search"].tap()
        app.buttons["Select"].tap();app.buttons["Select shown"].tap();app.buttons["Export 2"].tap()
        let create = app.buttons["createBatchExport"];XCTAssertTrue(create.waitForExistence(timeout:10));create.tap()
        XCTAssertTrue(app.buttons["Share or save files"].waitForExistence(timeout:30))
        let exported = XCTAttachment(screenshot:app.screenshot());exported.name = "Batch export completed";exported.lifetime = .keepAlways;add(exported)
        app.navigationBars["Batch export"].buttons["Done"].tap();app.buttons["Done"].tap()
        let manage = app.buttons["Manage Studio batch QA 1"]
        app.scrollViews.firstMatch.swipeUp();manage.tap();app.buttons["Delete Studio copy"].tap()
        app.buttons["Delete Studio copy"].tap()
        let deleted = app.buttons["Recently Deleted"]
        if !deleted.isHittable { app.scrollViews.firstMatch.swipeDown() };deleted.tap()
        let restore = app.buttons["Restore"].firstMatch;XCTAssertTrue(restore.waitForExistence(timeout:10));restore.tap()
        XCTAssertTrue(app.staticTexts["No recently deleted projects"].waitForExistence(timeout:10))
        app.navigationBars["Recently Deleted"].buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Manage Studio batch QA 1"].exists)
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

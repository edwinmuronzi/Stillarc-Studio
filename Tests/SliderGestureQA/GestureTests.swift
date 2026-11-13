import XCTest
final class GestureTests:XCTestCase {
    func testOriginalVerificationAndMissingSourceRepair() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--original-media-ui-test"];app.launch()
        let verify=app.buttons["verifyOriginalMedia"];XCTAssertTrue(verify.waitForExistence(timeout:30));verify.tap()
        XCTAssertTrue(app.staticTexts["Fingerprint saved. Keep a project backup too."].waitForExistence(timeout:10))
        verify.tap();XCTAssertTrue(app.staticTexts["Verified: the original matches its saved fingerprint."].waitForExistence(timeout:10))
        let remove=app.buttons["removeTestOriginal"]
        for _ in 0..<8 {if remove.exists && remove.isHittable {break};app.swipeUp()}
        XCTAssertTrue(remove.waitForExistence(timeout:10));remove.tap()
        let restore=app.buttons["restoreTestOriginal"];XCTAssertTrue(restore.isEnabled);restore.tap()
        let status=app.staticTexts["Original restored. Saved edits and versions are unchanged."]
        for _ in 0..<8 {if status.exists {break};app.swipeDown()}
        XCTAssertTrue(status.waitForExistence(timeout:15))
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Exact original media recovery";shot.lifetime = .keepAlways;add(shot)
        app.buttons["closeOriginalMedia"].tap()
        let manage=app.descendants(matching:.any).matching(NSPredicate(format:"label == %@","Manage QA Original repair")).firstMatch
        for _ in 0..<10 {if manage.exists && manage.isHittable {break};app.swipeUp()}
        XCTAssertTrue(manage.waitForExistence(timeout:10));manage.tap();app.buttons["Original media & repair"].tap()
        XCTAssertTrue(verify.waitForExistence(timeout:10));XCTAssertEqual(verify.label,"Verify original");app.buttons["closeOriginalMedia"].tap()
    }
    func testLookLibraryFavoritesCollectionsAndReopen() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--look-library-ui-test"];app.launch()
        let home=app.buttons["homeLookLibrary"];XCTAssertTrue(home.waitForExistence(timeout:30));home.tap()
        let star=app.buttons["Favourite QA Library Amber"];XCTAssertTrue(star.waitForExistence(timeout:10));star.tap()
        let marked=expectation(for:NSPredicate {_,_ in star.value as? String == "On"},evaluatedWith:nil);wait(for:[marked],timeout:5)
        let collectionControl=app.descendants(matching:.any).matching(identifier:"lookCollectionFilter").firstMatch
        for _ in 0..<12 {if collectionControl.exists && collectionControl.isHittable {break};app.swipeDown()}
        app.buttons["favoriteLooksFilter"].tap();XCTAssertFalse(app.buttons["Select look QA Library Blue"].exists);app.buttons["favoriteLooksFilter"].tap()
        app.buttons["Library options QA Library Amber"].tap();app.buttons["Collection"].tap();app.buttons["New collection…"].tap()
        app.alerts.textFields.firstMatch.tap();app.alerts.textFields.firstMatch.typeText("Portraits");app.alerts.buttons["Save"].tap()
        for _ in 0..<12 {if collectionControl.exists && collectionControl.isHittable {break};app.swipeDown()}
        app.descendants(matching:.any).matching(identifier:"lookCollectionFilter").firstMatch.tap();app.buttons["Portraits"].tap()
        XCTAssertTrue(app.buttons["Select look QA Library Amber"].exists);XCTAssertFalse(app.buttons["Select look QA Library Blue"].exists)
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Look library favourites and collections";shot.lifetime = .keepAlways;add(shot)
        app.buttons["closeLookLibrary"].tap();app.terminate();app.launchArguments=[];app.launch();XCTAssertTrue(home.waitForExistence(timeout:20));home.tap()
        XCTAssertEqual(app.buttons["Favourite QA Library Amber"].value as? String,"On")
        app.descendants(matching:.any).matching(identifier:"lookCollectionFilter").firstMatch.tap();XCTAssertTrue(app.buttons["Portraits"].exists);app.buttons.matching(identifier:"All collections").allElementsBoundByIndex.last!.tap();app.buttons["closeLookLibrary"].tap()
    }
    func testLookLibraryBackupAndDuplicateImport() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--look-library-ui-test"];app.launch();XCTAssertTrue(app.buttons["homeLookLibrary"].waitForExistence(timeout:30));app.buttons["homeLookLibrary"].tap()
        let backup=app.buttons["backupAllLooks"]
        for _ in 0..<12 {if backup.exists && backup.isHittable {break};app.swipeUp()}
        XCTAssertTrue(backup.waitForExistence(timeout:10));backup.tap()
        let share=app.buttons["shareLookLibrary"],testImport=app.buttons["importTestLookLibrary"]
        var n=0;while (!testImport.exists || !testImport.isHittable) && n<8 {app.swipeUp();n+=1}
        XCTAssertTrue(share.waitForExistence(timeout:30));XCTAssertTrue(testImport.waitForExistence(timeout:10));testImport.tap()
        let status=app.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Imported 0 looks; skipped")).firstMatch
        for _ in 0..<8 {if status.exists {break};app.swipeUp()}
        XCTAssertTrue(status.waitForExistence(timeout:20))
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Portable library duplicate-safe import";shot.lifetime = .keepAlways;add(shot)
        app.buttons["closeLookLibrary"].tap()
    }
    func testLookLibraryOrderAndEditorAccess() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--look-library-ui-test"];app.launch();XCTAssertTrue(app.buttons["homeLookLibrary"].waitForExistence(timeout:30));app.buttons["homeLookLibrary"].tap()
        let amber=app.buttons["Select look QA Library Amber"],blue=app.buttons["Select look QA Library Blue"]
        XCTAssertTrue(amber.waitForExistence(timeout:10));app.buttons["Library options QA Library Amber"].tap();app.buttons["Move down"].tap()
        let reordered=expectation(for:NSPredicate {_,_ in amber.frame.midY>blue.frame.midY},evaluatedWith:nil);wait(for:[reordered],timeout:5)
        app.buttons["closeLookLibrary"].tap();app.buttons["Explore the editor"].tap();XCTAssertTrue(app.buttons["Looks"].waitForExistence(timeout:30));app.buttons["Looks"].tap();app.buttons["Looks & presets"].tap()
        XCTAssertTrue(app.buttons["manageLookLibrary"].waitForExistence(timeout:10));app.buttons["manageLookLibrary"].tap();XCTAssertTrue(app.buttons["closeLookLibrary"].waitForExistence(timeout:10));app.buttons["closeLookLibrary"].tap()
    }
    func testPhotoMaskZoomStrokeUndo() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments=["--demo-editor","--brush-demo","--tool","Masks"];app.launch()
        let interaction=app.buttons["maskPreviewInteraction"],zoom=app.buttons["maskPreviewZoom"]
        XCTAssertTrue(zoom.waitForExistence(timeout:30));zoom.tap();zoom.tap();XCTAssertEqual(zoom.value as? String,"4 times")
        let canvas=app.descendants(matching:.any).matching(identifier:"brushMaskCanvas").firstMatch;XCTAssertTrue(canvas.waitForExistence(timeout:10))
        canvas.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.45)).press(forDuration:0.1,thenDragTo:canvas.coordinate(withNormalizedOffset:CGVector(dx:0.53,dy:0.48)))
        XCTAssertEqual(canvas.value as? String,"2 strokes")
        interaction.tap();XCTAssertTrue(app.buttons["Undo"].isEnabled);app.buttons["Undo"].tap()
        let redoReady=expectation(for:NSPredicate {_,_ in app.buttons["Redo"].isEnabled},evaluatedWith:nil);wait(for:[redoReady],timeout:5);app.buttons["Redo"].tap()
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Precision photo masks at four times zoom";shot.lifetime = .keepAlways;add(shot)
        app.buttons["fitMaskPreview"].tap();app.buttons["Export photo"].tap();app.buttons["Create export"].tap();XCTAssertTrue(app.buttons["Change export options"].waitForExistence(timeout:30))
    }
    func testMaskZoomBrushAndPlayback() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments=["--video-demo","--brush-demo","--tool","Masks"];app.launch()
        let interaction=app.buttons["maskPreviewInteraction"],zoom=app.buttons["maskPreviewZoom"]
        XCTAssertTrue(interaction.waitForExistence(timeout:30));XCTAssertEqual(interaction.label,"Done brushing")
        zoom.tap();XCTAssertEqual(zoom.value as? String,"2 times")
        let canvas=app.descendants(matching:.any).matching(identifier:"brushMaskCanvas").firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout:10))
        canvas.coordinate(withNormalizedOffset:CGVector(dx:0.45,dy:0.48)).press(forDuration:0.1,thenDragTo:canvas.coordinate(withNormalizedOffset:CGVector(dx:0.55,dy:0.52)))
        interaction.tap();XCTAssertEqual(interaction.label,"Brush")
        let transport=app.sliders["Video position"];XCTAssertTrue(transport.waitForExistence(timeout:5));transport.adjust(toNormalizedSliderPosition:0.5)
        XCTAssertFalse(canvas.exists)
        let preview=app.descendants(matching:.any).matching(identifier:"playbackReveal").firstMatch
        preview.pinch(withScale:1.5,velocity:1.2)
        XCTAssertNotEqual(zoom.value as? String,"2 times")
        preview.coordinate(withNormalizedOffset:CGVector(dx:0.4,dy:0.4)).press(forDuration:0.1,thenDragTo:preview.coordinate(withNormalizedOffset:CGVector(dx:0.6,dy:0.5)))
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Zoomed masking with playback restored";shot.lifetime = .keepAlways;add(shot)
        app.buttons["fitMaskPreview"].tap();XCTAssertEqual(zoom.value as? String,"1 times")
        interaction.tap();XCTAssertTrue(canvas.waitForExistence(timeout:5));interaction.tap()
        app.buttons["Export video"].tap();app.buttons["Create export"].tap();XCTAssertTrue(app.buttons["Change export options"].waitForExistence(timeout:40))
    }
    func testSubjectSelectionMethods() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--demo-editor","--neutral-demo","--tool","Masks"];app.launch()
        XCTAssertTrue(app.buttons["Add mask"].waitForExistence(timeout:30));app.buttons["Add mask"].tap();app.buttons["Subject"].tap()
        let method=app.buttons["subjectSelectionMethod"];XCTAssertTrue(method.waitForExistence(timeout:15));method.tap();app.buttons["Tap a subject"].tap()
        let create=app.buttons["createAutomaticMask"];XCTAssertFalse(create.isEnabled)
        let pick=app.descendants(matching:.any).matching(identifier:"subjectPickPreview").firstMatch;XCTAssertTrue(pick.waitForExistence(timeout:10))
        pick.coordinate(withNormalizedOffset:CGVector(dx:0.35,dy:0.75)).tap();XCTAssertTrue(create.isEnabled)
        method.tap();app.buttons["People · fine edges"].tap();XCTAssertTrue(create.isEnabled)
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Intelligent subject selection methods";shot.lifetime = .keepAlways;add(shot)
        app.buttons["Done"].tap()
    }
    func testMaskSizeRotationPointsUndoAndExport() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--video-demo","--correction-demo"];app.launch()
        XCTAssertTrue(app.buttons["setTrackingCorrection"].waitForExistence(timeout:30))
        app.buttons["End"].tap();app.buttons["Size & rotation"].tap()
        let size=app.sliders["Mask size"],turn=app.sliders["Mask rotation"]
        XCTAssertTrue(size.waitForExistence(timeout:10));size.adjust(toNormalizedSliderPosition:0.4)
        turn.adjust(toNormalizedSliderPosition:0.6)
        XCTAssertTrue(app.staticTexts["2/32 points"].waitForExistence(timeout:10))
        let before=turn.value as? String
        app.buttons["correctionUndo"].tap();XCTAssertNotEqual(turn.value as? String,before)
        app.buttons["correctionRedo"].tap();XCTAssertEqual(turn.value as? String,before)
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Manual mask size and rotation";shot.lifetime = .keepAlways;add(shot)
        app.buttons["closeTrackingCorrection"].tap();app.buttons["Export video"].tap();app.buttons["Create export"].tap()
        XCTAssertTrue(app.staticTexts["actualExportSize"].waitForExistence(timeout:40))
    }
    func testTrackingCorrectionsUndoExport() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments=["--video-demo","--correction-demo"];app.launch()
        let set=app.buttons["setTrackingCorrection"];XCTAssertTrue(set.waitForExistence(timeout:30))
        set.tap();XCTAssertTrue(app.staticTexts["1/32 points"].exists)
        app.buttons["End"].tap();app.sliders["Horizontal correction"].adjust(toNormalizedSliderPosition:0.56)
        XCTAssertTrue(app.staticTexts["2/32 points"].waitForExistence(timeout:10))
        app.buttons["correctionUndo"].tap();XCTAssertTrue(app.staticTexts["1/32 points"].exists)
        app.buttons["correctionRedo"].tap();XCTAssertTrue(app.staticTexts["2/32 points"].exists)
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Tracking corrections";shot.lifetime = .keepAlways;add(shot)
        app.buttons["closeTrackingCorrection"].tap();app.buttons["Export video"].tap();app.buttons["Create export"].tap();XCTAssertTrue(app.buttons["Change export options"].waitForExistence(timeout:40))
    }
    func testTrackingCorrectionDragLandscapeReset() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments=["--video-demo","--correction-demo"];app.launch()
        XCTAssertTrue(app.buttons["setTrackingCorrection"].waitForExistence(timeout:30))
        XCUIDevice.shared.orientation = .landscapeLeft;defer {XCUIDevice.shared.orientation = .portrait}
        let toggle=app.switches["Move mask in preview"];XCTAssertTrue(toggle.waitForExistence(timeout:10));toggle.tap()
        let handle=app.descendants(matching:.any).matching(NSPredicate(format:"label == %@","Move tracked mask")).firstMatch;XCTAssertTrue(handle.waitForExistence(timeout:10))
        let wide=expectation(for:NSPredicate {_,_ in app.frame.width>app.frame.height},evaluatedWith:nil);wait(for:[wide],timeout:8)
        handle.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5)).press(forDuration:0.1,thenDragTo:handle.coordinate(withNormalizedOffset:CGVector(dx:1.8,dy:0.8)))
        XCTAssertTrue(app.staticTexts["1/32 points"].waitForExistence(timeout:10))
        XCTAssertNotEqual(app.sliders["Horizontal correction"].value as? String,"50%")
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Landscape tracking correction";shot.lifetime = .keepAlways;add(shot)
        app.swipeUp();app.buttons["Clear corrections"].tap();XCTAssertTrue(app.staticTexts["0/32 points"].waitForExistence(timeout:10))
        app.buttons["correctionUndo"].tap();XCTAssertTrue(app.staticTexts["1/32 points"].exists)
        app.buttons["closeTrackingCorrection"].tap()
    }
    func testVideoAnimationPointsAndUndo() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--video-demo"];app.launch()
        XCTAssertTrue(app.buttons["Looks"].waitForExistence(timeout:30));app.buttons["Looks"].tap();app.buttons["Video animation"].tap()
        let set=app.buttons["setAnimationPoint"];XCTAssertTrue(set.waitForExistence(timeout:15));set.tap();XCTAssertTrue(app.staticTexts["1/32 points"].exists)
        app.buttons["End"].tap();app.sliders["Animation value"].adjust(toNormalizedSliderPosition:0.7)
        XCTAssertTrue(app.staticTexts["2/32 points"].waitForExistence(timeout:10))
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Video keyframes and live preview";shot.lifetime = .keepAlways;add(shot)
        app.buttons["animationUndo"].tap();XCTAssertTrue(app.staticTexts["1/32 points"].exists)
        app.buttons["animationRedo"].tap();XCTAssertTrue(app.staticTexts["2/32 points"].exists)
        app.buttons["closeVideoAnimation"].tap();app.buttons["Export video"].tap();app.buttons["Create export"].tap();XCTAssertTrue(app.buttons["Change export options"].waitForExistence(timeout:40))
    }
    func testVideoAnimationLandscapeLayout() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--video-demo"];app.launch()
        XCTAssertTrue(app.buttons["Looks"].waitForExistence(timeout:30));app.buttons["Looks"].tap();app.buttons["Video animation"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft;defer {XCUIDevice.shared.orientation = .portrait}
        XCTAssertTrue(app.buttons["setAnimationPoint"].waitForExistence(timeout:15))
        let preview=app.descendants(matching:.any).matching(identifier:"animationPreview").firstMatch;XCTAssertTrue(preview.waitForExistence(timeout:10));XCTAssertGreaterThan(preview.frame.height,150)
        let wide=expectation(for:NSPredicate {_,_ in app.frame.width>app.frame.height && preview.frame.width>300},evaluatedWith:nil);wait(for:[wide],timeout:8)
        app.buttons["setAnimationPoint"].tap();XCTAssertTrue(app.staticTexts["1/32 points"].waitForExistence(timeout:10))
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Landscape video animation";shot.lifetime = .keepAlways;add(shot)
        app.buttons["closeVideoAnimation"].tap()
    }
    func testProjectBackupCreateInspectRestore() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--archive-ui-test"];app.launch()
        XCTAssertTrue(app.buttons["Project backups"].waitForExistence(timeout:30));app.scrollViews.firstMatch.swipeUp();app.buttons["Project backups"].tap()
        XCTAssertTrue(app.buttons["createProjectBackup"].waitForExistence(timeout:15))
        let source=app.buttons["Back up Studio sample"];var scrolls=0;while (!source.exists || source.frame.midY>app.frame.height-190) && scrolls<12 {app.swipeUp();scrolls+=1};XCTAssertTrue(source.waitForExistence(timeout:10));source.tap();XCTAssertEqual(source.value as? String,"Selected")
        let create=app.buttons["createProjectBackup"];XCTAssertTrue(create.isEnabled);create.tap()
        XCTAssertTrue(app.buttons["shareProjectBackup"].waitForExistence(timeout:30))
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Project backup ready";shot.lifetime = .keepAlways;add(shot)
        app.buttons["inspectTestBackup"].tap();XCTAssertTrue(app.buttons["restoreProjectBackup"].waitForExistence(timeout:10));app.buttons["restoreProjectBackup"].tap()
        XCTAssertTrue(app.staticTexts["Restored 1 new editable projects."].waitForExistence(timeout:30));app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Project backups"].waitForExistence(timeout:10))
    }
    func testProjectBackupSelectionAndFilePickerCancel() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--archive-ui-test"];app.launch()
        XCTAssertTrue(app.buttons["Project backups"].waitForExistence(timeout:30));app.scrollViews.firstMatch.swipeUp();app.buttons["Project backups"].tap()
        XCTAssertTrue(app.buttons["createProjectBackup"].waitForExistence(timeout:15));XCTAssertFalse(app.buttons["createProjectBackup"].isEnabled);app.buttons["Select up to 20"].tap();XCTAssertTrue(app.buttons["createProjectBackup"].isEnabled);app.buttons["Clear"].tap();XCTAssertFalse(app.buttons["createProjectBackup"].isEnabled)
        app.buttons["Restore"].tap();app.buttons["chooseProjectBackup"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout:10));app.buttons["Cancel"].tap();XCTAssertTrue(app.buttons["chooseProjectBackup"].exists);app.buttons["Done"].tap()
    }
    func testBackupAllAndPreviews() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--archive-ui-test"];app.launch()
        XCTAssertTrue(app.buttons["Project backups"].waitForExistence(timeout:30));app.scrollViews.firstMatch.swipeUp();app.buttons["Project backups"].tap()
        XCTAssertTrue(app.buttons["backupAllProjects"].waitForExistence(timeout:15));app.swipeUp()
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Backup thumbnails and all projects";shot.lifetime = .keepAlways;add(shot)
        app.buttons["backupAllProjects"].tap();XCTAssertTrue(app.buttons["shareProjectBackup"].waitForExistence(timeout:60));app.buttons["Done"].tap()
    }
    func testExportQueueDelivery() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--demo-editor","--neutral-demo"];app.launch()
        XCTAssertTrue(app.buttons["Export photo"].waitForExistence(timeout:30));app.buttons["Export photo"].tap();app.swipeUp()
        let enqueue=app.buttons["enqueueExport"];XCTAssertTrue(enqueue.waitForExistence(timeout:10));enqueue.tap()
        XCTAssertTrue(app.staticTexts["Added to queue. Open it to start delivery."].waitForExistence(timeout:15));app.buttons["openExportQueue"].tap()
        XCTAssertTrue(app.buttons["startExportQueue"].waitForExistence(timeout:10));app.buttons["startExportQueue"].tap()
        XCTAssertTrue(app.staticTexts["Ready"].firstMatch.waitForExistence(timeout:40))
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Completed export queue";shot.lifetime = .keepAlways;add(shot)
        app.buttons["closeExportQueue"].tap()
    }
    func testColorWarpResetUndoAndPersistence() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--demo-editor","--neutral-demo"];app.launch()
        XCTAssertTrue(app.buttons["Looks"].waitForExistence(timeout:30));app.buttons["Looks"].tap();app.buttons["Color Warp"].tap()
        XCTAssertTrue(app.buttons["addWarpPoint"].waitForExistence(timeout:10));app.buttons["addWarpPoint"].tap()
        let scroll=app.scrollViews.firstMatch
        scroll.swipeUp()
        let hue=app.sliders["Hue move"];XCTAssertTrue(hue.waitForExistence(timeout:10));hue.adjust(toNormalizedSliderPosition:0.7)
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Color Warp live controls";shot.lifetime = .keepAlways;add(shot)
        app.buttons["Done"].tap();app.buttons["Undo"].tap();app.buttons["Redo"].tap()
        app.buttons["Back to workspace"].tap();app.terminate();app.launchArguments=["--demo-editor"];app.launch()
        XCTAssertTrue(app.buttons["Looks"].waitForExistence(timeout:30));app.buttons["Looks"].tap();app.buttons["Color Warp"].tap()
        app.scrollViews.firstMatch.swipeUp();XCTAssertTrue(app.sliders["Hue move"].waitForExistence(timeout:10));XCTAssertNotEqual(app.sliders["Hue move"].value as? String,"50%")
        app.sliders["Hue move"].doubleTap();app.buttons["Done"].tap()
    }
    func testColorWarpMapAndPointLimit() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--demo-editor","--neutral-demo"];app.launch()
        XCTAssertTrue(app.buttons["Looks"].waitForExistence(timeout:30));app.buttons["Looks"].tap();app.buttons["Color Warp"].tap()
        let addPoint=app.buttons["addWarpPoint"];XCTAssertTrue(addPoint.waitForExistence(timeout:10));for _ in 0..<4 {addPoint.tap()};XCTAssertFalse(addPoint.isEnabled)
        let edit=app.descendants(matching:.any).matching(identifier:"editWarpMap").firstMatch;XCTAssertTrue(edit.waitForExistence(timeout:10));edit.tap()
        let map=app.otherElements["warpMap"];XCTAssertTrue(map.waitForExistence(timeout:10))
        map.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.4)).press(forDuration:0.1,thenDragTo:map.coordinate(withNormalizedOffset:CGVector(dx:0.58,dy:0.3)))
        edit.tap();app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(app.sliders["Hue move"].waitForExistence(timeout:10));XCTAssertNotEqual(app.sliders["Hue move"].value as? String,"50%")
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Color Warp map and four point limit";shot.lifetime = .keepAlways;add(shot)
        app.buttons["Done"].tap()
    }
    func testDeliverySizeQualityAndRetry() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--demo-editor","--neutral-demo"];app.launch()
        XCTAssertTrue(app.buttons["Export photo"].waitForExistence(timeout:30));app.buttons["Export photo"].tap()
        let scroll=app.scrollViews.firstMatch;scroll.swipeUp()
        let size=app.buttons["deliverySize"];XCTAssertTrue(size.waitForExistence(timeout:10));size.tap();app.buttons["1280 px"].tap()
        app.buttons["deliveryQuality"].tap();app.buttons["Balanced"].tap()
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Export size and quality";shot.lifetime = .keepAlways;add(shot)
        app.buttons["Create export"].tap();XCTAssertTrue(app.buttons["Change export options"].waitForExistence(timeout:30));app.buttons["Change export options"].tap()
        scroll.swipeDown();app.buttons["deliverySize"].tap();app.buttons["Original"].tap();app.buttons["deliveryQuality"].tap();app.buttons["Maximum"].tap()
        app.buttons["Done"].tap()
    }
    func testReferenceMatchStrengthUndoAndPersistence() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--demo-editor","--reference-demo"];app.launch()
        XCTAssertTrue(app.buttons["Looks"].waitForExistence(timeout:30));app.buttons["Looks"].tap();app.buttons["Reference & Match"].tap()
        XCTAssertTrue(app.buttons["suggestReferenceMatch"].waitForExistence(timeout:15));app.buttons["suggestReferenceMatch"].tap()
        let strength=app.sliders["Match strength"];XCTAssertTrue(strength.waitForExistence(timeout:15));strength.adjust(toNormalizedSliderPosition:0.5);strength.doubleTap()
        XCTAssertTrue(app.buttons["Reset match"].exists)
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Reference comparison and match";shot.lifetime = .keepAlways;add(shot)
        app.buttons["Done"].tap();app.buttons["Undo"].tap();app.buttons["Redo"].tap()
        app.buttons["Back to workspace"].tap();app.terminate();app.launchArguments=["--demo-editor"];app.launch()
        XCTAssertTrue(app.buttons["Looks"].waitForExistence(timeout:30));app.buttons["Looks"].tap();app.buttons["Reference & Match"].tap()
        XCTAssertTrue(app.sliders["Match strength"].waitForExistence(timeout:15));app.buttons["Reset match"].tap();XCTAssertFalse(app.sliders["Match strength"].exists)
    }
    func testReferenceFromPoolProjectAndClear() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--pool-demo"];app.launch()
        XCTAssertTrue(app.buttons["Looks"].waitForExistence(timeout:30));app.buttons["Looks"].tap();app.buttons["Reference & Match"].tap()
        app.buttons["From projects"].tap();app.buttons["Pool sample 2"].tap()
        XCTAssertTrue(app.buttons["suggestReferenceMatch"].waitForExistence(timeout:20));app.buttons["suggestReferenceMatch"].tap()
        XCTAssertTrue(app.sliders["Match strength"].waitForExistence(timeout:15));app.swipeUp();app.buttons["Clear reference"].tap()
        XCTAssertTrue(app.sliders["Match strength"].exists);app.buttons["Done"].tap();app.buttons["Undo"].tap()
        app.buttons["Looks"].tap();app.buttons["Reference & Match"].tap();XCTAssertTrue(app.buttons["suggestReferenceMatch"].waitForExistence(timeout:10))
    }
    func testSkinHueGuideToggle() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--demo-editor","--neutral-demo"];app.launch()
        XCTAssertTrue(app.buttons["Scopes"].waitForExistence(timeout:30));app.buttons["Scopes"].tap();app.buttons["Vectorscope"].tap()
        let guide=app.switches["skinHueGuide"];XCTAssertTrue(guide.waitForExistence(timeout:10));guide.tap()
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Vectorscope skin hue guide";shot.lifetime = .keepAlways;add(shot)
        guide.tap();XCTAssertTrue(app.buttons["Export photo"].isEnabled)
    }
    func testEmptyBinMenuAndConfirmationCancel() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=[];app.launch()
        let bin=app.buttons["Recently Deleted"];XCTAssertTrue(bin.waitForExistence(timeout:30));bin.press(forDuration:0.7)
        XCTAssertTrue(app.buttons["Empty Bin…"].waitForExistence(timeout:10));app.buttons["Empty Bin…"].tap();if app.buttons["Cancel"].waitForExistence(timeout:3) {app.buttons["Cancel"].tap()}
        XCTAssertTrue(app.buttons["emptyBinButton"].waitForExistence(timeout:10))
        if app.buttons["emptyBinButton"].isEnabled {app.buttons["emptyBinButton"].tap();XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout:10));app.buttons["Cancel"].tap()}
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Recently Deleted empty bin";shot.lifetime = .keepAlways;add(shot)
    }

    func testHealCloneAndFullResolutionInspection() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--demo-editor","--neutral-demo","--tool","Detail"];app.launch()
        XCTAssertTrue(app.buttons["Photo tools"].waitForExistence(timeout:30));app.buttons["Photo tools"].tap();app.buttons["Heal & Clone"].tap()
        XCTAssertTrue(app.buttons["Choose source"].waitForExistence(timeout:10))
        let first=app.coordinate(withNormalizedOffset:CGVector(dx:0.35,dy:0.3)),second=app.coordinate(withNormalizedOffset:CGVector(dx:0.6,dy:0.32));first.tap();second.tap()
        XCTAssertTrue(app.buttons["Remove last spot"].isEnabled);app.buttons["Remove last spot"].tap();XCTAssertFalse(app.buttons["Remove last spot"].isEnabled)
        app.buttons["Done"].tap();app.buttons["Photo tools"].tap();app.buttons["Inspect full-resolution detail"].tap()
        XCTAssertTrue(app.sliders["Inspect horizontal"].waitForExistence(timeout:10));app.sliders["Inspect horizontal"].adjust(toNormalizedSliderPosition:0.7)
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Full-resolution detail inspection";shot.lifetime = .keepAlways;add(shot)
    }
    func testPoolDeliveryAllAndSelected() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--pool-demo"];app.launch()
        XCTAssertTrue(app.buttons["Export photo"].waitForExistence(timeout:30));app.buttons["Export photo"].tap()
        app.buttons["exportPoolItems"].tap();XCTAssertTrue(app.buttons["exportEntirePool"].waitForExistence(timeout:10))
        app.buttons["Clear selection"].tap();XCTAssertFalse(app.buttons["exportChosenPoolItems"].isEnabled)
        app.buttons["Export item Pool sample 2"].tap();XCTAssertTrue(app.buttons["exportChosenPoolItems"].isEnabled)
        app.buttons["exportChosenPoolItems"].tap();XCTAssertTrue(app.buttons["createBatchExport"].waitForExistence(timeout:10))
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Pool selected delivery";shot.lifetime = .keepAlways;add(shot)
        let close=app.buttons.matching(identifier:"Done").allElementsBoundByIndex.first(where:{$0.isHittable})!;close.tap();app.buttons["exportEntirePool"].tap();XCTAssertTrue(app.buttons["createBatchExport"].waitForExistence(timeout:10))
        app.buttons["createBatchExport"].tap();XCTAssertTrue(app.buttons["Share or save files"].waitForExistence(timeout:40))
    }
    func testReplacementBackgroundAndDuplicate() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--pool-demo","--paired-fixture","--tool","Masks"];app.launch()
        XCTAssertTrue(app.buttons["Remove background"].waitForExistence(timeout:30));app.buttons["Remove background"].tap()
        app.buttons["replaceBackground"].tap();XCTAssertTrue(app.buttons["backgroundMode"].waitForExistence(timeout:10))
        app.buttons["backgroundMode"].tap();app.buttons["Solid"].tap()
        let slider=app.sliders["Background red"];XCTAssertTrue(slider.waitForExistence(timeout:10));slider.adjust(toNormalizedSliderPosition:0.8);slider.doubleTap()
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Replacement background";shot.lifetime = .keepAlways;add(shot)
        app.buttons["Done"].tap();XCTAssertTrue(app.buttons["Duplicate mask"].waitForExistence(timeout:10));app.buttons["Duplicate mask"].tap()
        app.buttons["Export photo"].tap();XCTAssertTrue(app.buttons["JPEG"].waitForExistence(timeout:10))
    }
    func testPhotoDevelopmentHDRProofAndDetail() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--demo-editor","--neutral-demo","--tool","Detail"];app.launch()
        XCTAssertTrue(app.buttons["Photo development"].waitForExistence(timeout:30));app.buttons["Photo development"].tap()
        XCTAssertTrue(app.sliders["Chromatic aberration"].waitForExistence(timeout:10));app.swipeUp()
        let hdr=app.switches["Develop in HDR"];XCTAssertTrue(hdr.waitForExistence(timeout:10));hdr.tap()
        let proof=app.switches["SDR proof"];XCTAssertTrue(proof.waitForExistence(timeout:10));proof.tap()
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Photo development";shot.lifetime = .keepAlways;add(shot)
        app.buttons["Done"].tap()
    }

    func testPoolSyncUndoRedoWholeTransaction() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--pool-demo"];app.launch()
        XCTAssertTrue(app.buttons["Next pool item"].waitForExistence(timeout:30))
        let exposure=app.sliders["Exposure"];exposure.doubleTap();let neutral=exposure.value as? String
        exposure.adjust(toNormalizedSliderPosition:0.65);let grade=exposure.value as? String
        app.buttons["syncPoolEdits"].tap();XCTAssertTrue(app.buttons["applyBatchPaste"].waitForExistence(timeout:10));app.buttons["applyBatchPaste"].tap()
        XCTAssertTrue(app.staticTexts["Applied to 3 of 3."].waitForExistence(timeout:15));app.buttons["Done"].tap()
        app.buttons["Undo"].tap();XCTAssertTrue(app.staticTexts["Undid sync edits · 2 items"].waitForExistence(timeout:10))
        XCTAssertEqual(exposure.value as? String,grade)
        app.buttons["Next pool item"].tap();XCTAssertTrue(app.staticTexts["Pool sample 2"].waitForExistence(timeout:15));XCTAssertEqual(exposure.value as? String,neutral)
        app.buttons["Next pool item"].tap();XCTAssertTrue(app.staticTexts["Pool sample 3"].waitForExistence(timeout:15));XCTAssertEqual(exposure.value as? String,neutral)
        app.buttons["Redo"].tap();XCTAssertTrue(app.staticTexts["Redid sync edits · 2 items"].waitForExistence(timeout:10));XCTAssertEqual(exposure.value as? String,grade)
        app.buttons["Undo"].tap();XCTAssertTrue(app.staticTexts["Undid sync edits · 2 items"].waitForExistence(timeout:10))
        app.buttons["Undo"].tap();XCTAssertTrue(app.staticTexts["Undid edit · 1 item"].waitForExistence(timeout:10))
        app.buttons["Previous pool item"].tap();XCTAssertTrue(app.staticTexts["Pool sample 2"].waitForExistence(timeout:15));app.buttons["Previous pool item"].tap();XCTAssertTrue(app.staticTexts["Pool sample 1"].waitForExistence(timeout:15));XCTAssertEqual(exposure.value as? String,neutral)
        app.buttons["Redo"].tap();XCTAssertTrue(app.staticTexts["Redid edit · 1 item"].waitForExistence(timeout:10));XCTAssertEqual(exposure.value as? String,grade)
        app.buttons["Redo"].tap();XCTAssertTrue(app.staticTexts["Redid sync edits · 2 items"].waitForExistence(timeout:10))
        app.buttons["Next pool item"].tap();XCTAssertTrue(app.staticTexts["Pool sample 2"].waitForExistence(timeout:15));XCTAssertEqual(exposure.value as? String,grade)
    }
    func testPhotoCutoutTransparentExportUndo() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--pool-demo","--paired-fixture","--tool","Masks"];app.launch()
        XCTAssertTrue(app.buttons["Remove background"].waitForExistence(timeout:30));app.buttons["Remove background"].tap()
        let toggle=app.switches["Keep selection as cutout"];XCTAssertTrue(toggle.waitForExistence(timeout:10));XCTAssertEqual(toggle.value as? String,"1")
        app.buttons["Undo"].tap();XCTAssertTrue(app.staticTexts["Undid edit · 1 item"].waitForExistence(timeout:10));XCTAssertEqual(toggle.value as? String,"0")
        app.buttons["Redo"].tap();XCTAssertTrue(app.staticTexts["Redid edit · 1 item"].waitForExistence(timeout:10));XCTAssertEqual(toggle.value as? String,"1")
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Cutout controls and transparency fixture";shot.lifetime = .keepAlways;add(shot)
        app.buttons["Export photo"].tap();XCTAssertTrue(app.descendants(matching:.any)["transparentPNGFormat"].waitForExistence(timeout:10))
        app.buttons["Create export"].tap();XCTAssertTrue(app.buttons["Share or save to Files"].waitForExistence(timeout:30))
        let result=XCTAttachment(screenshot:app.screenshot());result.name="Transparent PNG export";result.lifetime = .keepAlways;add(result)
    }
    func testEditingPoolSyncBrowseAndResume() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--pool-demo"];app.launch()
        XCTAssertTrue(app.buttons["Next pool item"].waitForExistence(timeout:30))
        let slider=app.sliders["Exposure"];slider.doubleTap();slider.adjust(toNormalizedSliderPosition:0.65)
        let changed=slider.value as? String
        app.buttons["Next pool item"].tap();XCTAssertTrue(app.staticTexts["Pool sample 2"].waitForExistence(timeout:15))
        XCTAssertNotEqual(app.sliders["Exposure"].value as? String,changed)
        app.buttons["Previous pool item"].tap();XCTAssertTrue(app.staticTexts["Pool sample 1"].waitForExistence(timeout:15))
        XCTAssertEqual(app.sliders["Exposure"].value as? String,changed)
        app.buttons["syncPoolEdits"].tap();XCTAssertTrue(app.buttons["applyBatchPaste"].waitForExistence(timeout:10));app.buttons["applyBatchPaste"].tap()
        XCTAssertTrue(app.staticTexts["Applied to 3 of 3."].waitForExistence(timeout:15));app.buttons["Done"].tap()
        app.buttons["Next pool item"].tap();XCTAssertTrue(app.staticTexts["Pool sample 2"].waitForExistence(timeout:15));XCTAssertEqual(app.sliders["Exposure"].value as? String,changed)
        let swipe=app.coordinate(withNormalizedOffset:CGVector(dx:0.65,dy:0.30))
        swipe.press(forDuration:0.05,thenDragTo:swipe.withOffset(CGVector(dx:-120,dy:0)))
        XCTAssertTrue(app.staticTexts["Pool sample 3"].waitForExistence(timeout:15))
        app.buttons["Previous pool item"].tap();XCTAssertTrue(app.staticTexts["Pool sample 2"].waitForExistence(timeout:15))
        for _ in 0..<4 {
            app.buttons["Previous pool item"].tap();XCTAssertTrue(app.staticTexts["Pool sample 1"].waitForExistence(timeout:15))
            app.buttons["Next pool item"].tap();XCTAssertTrue(app.staticTexts["Pool sample 2"].waitForExistence(timeout:15))
        }
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Editing pool and filmstrip";shot.lifetime = .keepAlways;add(shot)
        app.buttons["Select pool items"].tap();app.buttons["Pool item Pool sample 3"].tap()
        XCTAssertEqual(app.buttons["Pool item Pool sample 3"].value as? String,"Not selected")
        app.buttons["Select pool items"].tap();app.buttons["Back to workspace"].tap()
        XCTAssertTrue(app.buttons["Resume editing pool"].waitForExistence(timeout:10));app.terminate();app.launchArguments=[];app.launch()
        XCTAssertTrue(app.buttons["Resume editing pool"].waitForExistence(timeout:15));app.buttons["Resume editing pool"].tap()
        XCTAssertTrue(app.staticTexts["Pool sample 2"].waitForExistence(timeout:20));XCTAssertEqual(app.sliders["Exposure"].value as? String,changed)
    }
    func testSubjectBackgroundIndependentControls() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--pool-demo","--paired-fixture","--tool","Masks"];app.launch()
        XCTAssertTrue(app.buttons["1 · Subject"].waitForExistence(timeout:30))
        let exposure=app.sliders["Exposure"];exposure.doubleTap();exposure.adjust(toNormalizedSliderPosition:0.7);let subject=exposure.value as? String
        app.buttons["2 · Background"].tap();XCTAssertNotEqual(exposure.value as? String,subject)
        exposure.doubleTap();exposure.adjust(toNormalizedSliderPosition:0.3);let background=exposure.value as? String
        app.buttons["1 · Subject"].tap();XCTAssertEqual(exposure.value as? String,subject)
        app.buttons["2 · Background"].tap();XCTAssertEqual(exposure.value as? String,background)
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Independent Subject and Background";shot.lifetime = .keepAlways;add(shot)
        app.buttons["Add mask"].tap();app.buttons["Subject & Background"].tap()
        XCTAssertTrue(app.buttons["createAutomaticMask"].waitForExistence(timeout:15));app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["2 · Background"].waitForExistence(timeout:10))
    }
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
    func testOneDLUTDetailsStrengthUndoAndExport() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--demo-editor","--one-d-lut-demo","--tool","Film"];app.launch()
        let panel=app.scrollViews["editorAdjustments"]
        XCTAssertTrue(panel.waitForExistence(timeout:30))
        let detail=app.staticTexts["1D · 1024 points per channel"].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout:10))
        let strength=app.sliders["LUT strength"]
        strength.adjust(toNormalizedSliderPosition:0.3)
        app.buttons["Undo"].tap();app.buttons["Redo"].tap()
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Standalone 1D LUT strength and details";shot.lifetime = .keepAlways;add(shot)
        app.buttons["Export photo"].tap();app.buttons["Create export"].tap()
        XCTAssertTrue(app.staticTexts["actualExportSize"].waitForExistence(timeout:30))
        app.buttons["Done"].tap()
    }
    func testLivePhotoExportEstimates() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--demo-editor","--neutral-demo"];app.launch()
        XCTAssertTrue(app.buttons["Export photo"].waitForExistence(timeout:30));app.buttons["Export photo"].tap()
        let estimate=app.staticTexts["estimatedExportSize"]
        XCTAssertTrue(estimate.waitForExistence(timeout:10));XCTAssertTrue(estimate.isHittable)
        let initialSize=app.buttons["deliverySize"];if !initialSize.isHittable {app.swipeUp()};initialSize.tap();app.buttons["Original"].tap()
        let jpeg=estimate.label
        app.buttons["PNG"].tap();let png=estimate.label;XCTAssertNotEqual(jpeg,png)
        app.buttons["JPEG"].tap();XCTAssertEqual(estimate.label,jpeg)
        let size=app.buttons["deliverySize"]
        if !size.isHittable {app.swipeUp()};size.tap();app.buttons["1280 px"].tap()
        XCTAssertNotEqual(estimate.label,jpeg)
        app.buttons["Create export"].tap()
        let actual=app.staticTexts["actualExportSize"];XCTAssertTrue(actual.waitForExistence(timeout:30))
        let ready=expectation(for:NSPredicate {_,_ in actual.label != "Checking…" && actual.label != "Unavailable"},evaluatedWith:nil);wait(for:[ready],timeout:10)
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Measured photo export size";shot.lifetime = .keepAlways;add(shot)
        app.buttons["Done"].tap()
    }
    func testLiveVideoExportEstimates() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--video-demo"];app.launch()
        XCTAssertTrue(app.buttons["Export video"].waitForExistence(timeout:40));app.buttons["Export video"].tap()
        let picker=app.buttons["deliveryVideoCodec"],estimate=app.staticTexts["estimatedExportSize"]
        XCTAssertTrue(picker.waitForExistence(timeout:10));picker.tap();app.buttons["HEVC"].tap();let hevc=estimate.label
        picker.tap();app.buttons["H.264"].tap();XCTAssertNotEqual(estimate.label,hevc)
        app.buttons["Create export"].tap()
        let actual=app.staticTexts["actualExportSize"];XCTAssertTrue(actual.waitForExistence(timeout:40))
        let ready=expectation(for:NSPredicate {_,_ in actual.label != "Checking…" && actual.label != "Unavailable"},evaluatedWith:nil);wait(for:[ready],timeout:10)
        app.swipeUp();let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Measured MP4 export size";shot.lifetime = .keepAlways;add(shot)
        app.buttons["Done"].tap()
    }
    func testVideoCodecChoicesAndHDRGuard() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--video-demo"];app.launch()
        XCTAssertTrue(app.buttons["Export video"].waitForExistence(timeout:40));app.buttons["Export video"].tap()
        let picker=app.buttons["deliveryVideoCodec"]
        XCTAssertTrue(picker.waitForExistence(timeout:10));picker.tap();app.buttons["H.264"].tap()
        XCTAssertTrue(app.staticTexts["8-bit SDR MP4 for broad compatibility. Sound is encoded as AAC. For HDR, choose HEVC or ProRes."].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["10-bit HEVC"].exists)
        app.buttons["Create export"].tap()
        let share=app.buttons["Share or save to Files"];XCTAssertTrue(share.waitForExistence(timeout:40))
        let save=app.buttons["Save to Photos"]
        for _ in 0..<8 {if save.exists && save.isHittable {break};app.swipeUp()};save.tap()
        let system=XCUIApplication(bundleIdentifier:"com.apple.springboard");let alert=system.alerts.firstMatch
        if alert.waitForExistence(timeout:3) {let allow=alert.buttons.matching(NSPredicate(format:"label BEGINSWITH[c] 'Allow'")).firstMatch;if allow.exists {allow.tap()}}
        XCTAssertTrue(app.staticTexts["Saved to Photos."].waitForExistence(timeout:20))
        let change=app.buttons["Change export options"]
        for _ in 0..<8 {if change.exists && change.isHittable {break};app.swipeUp()};change.tap()
        for _ in 0..<8 {if app.switches["HDR video · HLG"].isHittable {break};app.swipeDown()}
        app.switches["HDR video · HLG"].tap()
        XCTAssertTrue(app.staticTexts["Smaller files with high detail. Supports SDR and 10-bit HLG HDR. Best everyday choice."].waitForExistence(timeout:5))
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="HDR-safe video formats";shot.lifetime = .keepAlways;add(shot)
        app.buttons["Done"].tap()
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
    private func reveal(_ element:XCUIElement,in panel:XCUIElement) {
        for _ in 0..<18 {
            if element.exists && element.frame.midY>panel.frame.minY+18 && element.frame.midY<panel.frame.maxY-18 {return}
            let upward = !element.exists || element.frame.midY>=panel.frame.maxY-18
            let start=panel.coordinate(withNormalizedOffset:CGVector(dx:0.98,dy:upward ? 0.8:0.2))
            start.press(forDuration:0.05,thenDragTo:start.withOffset(CGVector(dx:0,dy:upward ? -85:85)))
        }
    }
    func testColourBatchLayersAndFlexiblePoints() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--demo-editor","--colour-stack-demo","--tool","Film"];app.launch()
        let panel=app.scrollViews["editorAdjustments"]
        let stack=app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","LUT stack")).firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout:30));reveal(stack,in:panel);stack.tap()
        let clear=app.buttons["Turn off all LUTs"];reveal(clear,in:panel);clear.tap();app.buttons["Undo"].tap()
        XCTAssertTrue(app.buttons["Turn off all LUTs"].waitForExistence(timeout:5))
        app.buttons["Curves"].tap()
        let addPoint=app.buttons["addCurvePoint"];reveal(addPoint,in:panel);addPoint.tap()
        let output=app.sliders["Curve output"];reveal(output,in:panel);output.adjust(toNormalizedSliderPosition:0.7)
        XCTAssertEqual(app.buttons["Curves"].value as? String,"Adjustments applied")
        app.buttons["Undo"].tap();XCTAssertEqual(app.buttons["Curves"].value as? String,"No adjustments")
        app.buttons["Redo"].tap();XCTAssertEqual(app.buttons["Curves"].value as? String,"Adjustments applied")
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Flexible RGB curves";shot.lifetime = .keepAlways;add(shot)
    }
    func testCurvesScrollWithoutEditingAndExplicitEdit() throws {
        let app=XCUIApplication(bundleIdentifier:"com.edwinmuronzipersonalteam.StillarcStudio")
        app.launchArguments=["--demo-editor","--neutral-demo","--tool","Curves"];app.launch()
        let graph=app.otherElements["flexibleCurveGraph"].firstMatch,panel=app.scrollViews["editorAdjustments"]
        XCTAssertTrue(panel.waitForExistence(timeout:30));reveal(graph,in:panel)
        let before=graph.frame.minY
        let start=graph.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        start.press(forDuration:0.05,thenDragTo:start.withOffset(CGVector(dx:0,dy:-45)))
        XCTAssertEqual(app.buttons["Curves"].value as? String,"No adjustments")
        XCTAssertNotEqual(graph.frame.minY,before)
        let edit=app.buttons["editFlexibleCurve"];reveal(edit,in:panel);edit.tap();reveal(graph,in:panel)
        let middle=graph.coordinate(withNormalizedOffset:CGVector(dx:0.5,dy:0.5))
        middle.press(forDuration:0.05,thenDragTo:middle.withOffset(CGVector(dx:0,dy:-20)))
        XCTAssertEqual(app.buttons["Curves"].value as? String,"Adjustments applied")
        app.buttons["Undo"].tap();XCTAssertEqual(app.buttons["Curves"].value as? String,"No adjustments")
        let shot=XCTAttachment(screenshot:app.screenshot());shot.name="Scroll-safe flexible curves";shot.lifetime = .keepAlways;add(shot)
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

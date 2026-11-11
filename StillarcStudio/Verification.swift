#if DEBUG
import Foundation
import CoreImage
import ImageIO

@MainActor enum StudioVerification {
    static func run(library: StudioLibrary) async {
        let reportURL = FileManager.default.urls(for: .documentDirectory,in: .userDomainMask)[0].appendingPathComponent("studio-verification.json")
        do {
            var report = try await Task.detached(priority: .userInitiated) {
                try await verify()
            }.value
            let fixture = Project(id: UUID(),name: "History",sourceName: "test.jpg",created: Date(),modified: Date(),recipe: Recipe(),width: 1,height: 1,isRAW: false)
            let session = EditSession(fixture)
            session.begin(); session.recipe.exposure = 0.5; session.recipe.exposure = 1; session.end()
            session.undo(); try require(session.recipe.exposure == 0,"Undo gesture failed")
            session.redo(); try require(session.recipe.exposure == 1,"Redo gesture failed")
            session.change { $0.whites = 0.4; $0.grain = 0.2 }
            session.change { $0.reset(.light) }
            try require(!session.recipe.hasAdjustments(in: .light) && session.recipe.hasAdjustments(in: .film),"Section reset affected another section")
            session.undo(); try require(session.recipe.hasAdjustments(in: .light),"Undo did not restore active-dot state")
            session.redo(); try require(!session.recipe.hasAdjustments(in: .light),"Redo did not clear active-dot state")
            let colorSession = EditSession(fixture)
            colorSession.begin(); colorSession.recipe.rgbCurves.red.middle = 0.6; colorSession.recipe.selectiveColors.orange.hue = 12; colorSession.end()
            colorSession.undo(); try require(colorSession.recipe.rgbCurves.isNeutral && colorSession.recipe.selectiveColors.isNeutral,"Color gesture undo failed")
            colorSession.redo(); try require(colorSession.recipe.rgbCurves.red.middle == 0.6 && colorSession.recipe.selectiveColors.orange.hue == 12,"Color gesture redo failed")
            let gradingSession = EditSession(fixture)
            gradingSession.begin(); gradingSession.recipe.colorWheels.shadows.hue = 220; gradingSession.recipe.colorWheels.shadows.strength = 0.25; gradingSession.recipe.channelMixer.redGreen = 0.1; gradingSession.end()
            gradingSession.undo(); try require(gradingSession.recipe.colorWheels.isNeutral && gradingSession.recipe.channelMixer.isNeutral,"Wheel/mixer gesture undo failed")
            gradingSession.redo(); try require(gradingSession.recipe.colorWheels.shadows.strength == 0.25 && gradingSession.recipe.channelMixer.redGreen == 0.1,"Wheel/mixer gesture redo failed")
            let lutSession = EditSession(fixture)
            let lut = try LUTVerification.example()
            lutSession.change { $0.lut = lut; $0.lutAmount = 0.4 }
            lutSession.undo(); try require(lutSession.recipe.lut == nil,"LUT import undo failed")
            lutSession.redo(); try require(lutSession.recipe.lut === lut && lutSession.recipe.lutAmount == 0.4,"LUT redo failed")
            lutSession.change { $0.reset(.film) }; lutSession.undo()
            try require(lutSession.recipe.lut === lut,"Undo Film reset did not restore LUT")
            report["lutUndoRedo"] = true
            report["gradingUndoRedo"] = true
            report["colorUndoRedo"] = true
            report["undoRedo"] = true
            report["sectionResetUndo"] = true
            try JSONSerialization.data(withJSONObject: report,options: [.prettyPrinted,.sortedKeys]).write(to: reportURL,options: .atomic)
        } catch {
            let report = ["passed": false,"error": error.localizedDescription] as [String: Any]
            if let data = try? JSONSerialization.data(withJSONObject: report,options: .prettyPrinted) { try? data.write(to: reportURL) }
        }
    }
    private nonisolated static func require(_ condition: Bool,_ text: String) throws {
        if !condition { throw NSError(domain: "StudioVerification",code: 1,userInfo: [NSLocalizedDescriptionKey:text]) }
    }
    private nonisolated static func verify() async throws -> [String: Any] {
        let colorReport = try ColorVerification.run()
        let logReport = try LogVerification.run()
        let lutReport = try LUTVerification.run()
        let gradingReport = try GradingVerification.run()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("StudioQA-\(UUID())",isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = ProjectVault(root: root)
        guard let sample = Bundle.main.url(forResource: "Sample",withExtension: "jpg") else { throw StudioError.unreadable }
        let project = try await vault.importPhoto(sample)
        let sourceURL = await vault.source(project)
        let before = try Data(contentsOf: sourceURL)
        var recipe = Recipe(); recipe.exposure = 0.65; recipe.warmth = 0.25; recipe.look = .bluehour
        var edited = project; edited.recipe = recipe
        try await vault.save(edited)
        let loaded = try await vault.load()
        try require(loaded.0.count == 1 && loaded.0[0].recipe == recipe,"Saved recipe did not round trip")
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(edited)) as! [String: Any]
        var oldRecipe = legacy["recipe"] as! [String: Any]
        for key in ["whites","blacks","straighten","cropX","cropY","rgbCurves","selectiveColors","colorWheels","channelMixer","lut","lutAmount","input"] { oldRecipe.removeValue(forKey: key) }
        legacy["recipe"] = oldRecipe
        let migrated = try JSONDecoder().decode(Project.self,from: JSONSerialization.data(withJSONObject: legacy))
        try require(migrated.recipe == recipe,"Version 0.1 project migration failed")
        let decoded = try ImageEngine.open(sourceURL,maxDimension: 800)
        let context = ImageEngine.context()
        func pixels(_ image: CIImage) -> [UInt8] {
            let small = image.transformed(by: .init(scaleX: 32/image.extent.width,y: 32/image.extent.height))
            var bytes = [UInt8](repeating: 0,count: 32*32*4)
            context.render(small,toBitmap: &bytes,rowBytes: 32*4,bounds: CGRect(x: 0,y: 0,width: 32,height: 32),format: .RGBA8,colorSpace: ImageEngine.output)
            return bytes
        }
        let baseline = pixels(decoded.image)
        try require(pixels(ImageEngine.apply(decoded.image,recipe: Recipe())) == baseline,"Neutral recipe changed image")
        try require(pixels(ImageEngine.apply(decoded.image,recipe: recipe)) != baseline,"Adjustments did not change pixels")
        var controls = [String]()
        let keys: [(String,WritableKeyPath<Recipe,Double>)] = [("Exposure",\.exposure),("Contrast",\.contrast),("Highlights",\.highlights),("Shadows",\.shadows),("Whites",\.whites),("Blacks",\.blacks),("Warmth",\.warmth),("Tint",\.tint),("Saturation",\.saturation),("Vibrance",\.vibrance),("Fade",\.fade),("Grain",\.grain),("Bloom",\.bloom),("Vignette",\.vignette),("Sharpen",\.sharpen),("Noise",\.noise),("Dark curve",\.curveShadows),("Middle curve",\.curveMidtones),("Bright curve",\.curveHighlights)]
        for (name,key) in keys {
            var r = Recipe(); r[keyPath:key] = 0.7
            try require(pixels(ImageEngine.apply(decoded.image,recipe:r)) != baseline,"\(name) did not affect pixels")
            controls.append(name)
        }
        for look in FilmLook.allCases where look != .original {
            var r = Recipe(); r.look = look
            try require(pixels(ImageEngine.apply(decoded.image,recipe:r)) != baseline,"\(look.rawValue) did not affect pixels")
        }
        try require(Tool.allCases.allSatisfy { !Recipe().hasAdjustments(in: $0) },"Neutral recipe showed used dots")
        for tool in Tool.allCases {
            var marked = Recipe(); marked[keyPath: tool.valueKeys[0]] = 0.3
            try require(marked.hasAdjustments(in: tool),"Missing dot for \(tool.rawValue)")
            try require(Tool.allCases.filter { $0 != tool }.allSatisfy { !marked.hasAdjustments(in: $0) },"Dot appeared in unrelated section")
            marked.reset(tool); try require(!marked.hasAdjustments(in: tool),"Reset failed to clear dot")
        }
        var disabledLook = Recipe(); disabledLook.look = .silver; disabledLook.lookAmount = 0
        try require(!disabledLook.hasAdjustments(in: .film),"Zero-strength look showed an active dot")
        var position = Recipe(); position.crop = .square; position.cropY = 0
        let top = pixels(ImageEngine.apply(decoded.image,recipe:position)); position.cropY = 1
        try require(top != pixels(ImageEngine.apply(decoded.image,recipe:position)),"Crop repositioning did not change the frame")
        var framing = Recipe(); framing.crop = .portrait; framing.rotation = 1; framing.straighten = 3.7; framing.cropX = 0.1; framing.cropY = 0.8; framing.exposure = 1
        let preset = framing.colorPreset
        try require(!preset.hasAdjustments(in: .crop) && preset.hasAdjustments(in: .light),"Color preset carried geometry or lost color")
        var restored = preset; restored.copyFraming(from:framing); try require(restored == framing,"Applying preset lost framing")
        let numeric = NumericEdit(name:"Exposure",key:\.exposure,range:-3...3,unit:"EV")
        try require(numeric.parse("1,25") == 1.25 && numeric.parse("inf") == nil && numeric.parse("4") == nil && numeric.parse("hello") == nil,"Exact-value validation failed")
        var edgeChecks = 0
        for sourceSize in [CGSize(width:80,height:60),CGSize(width:81,height:61)] {
        let solid = CIImage(color: CIColor(red: 0.6,green: 0.2,blue: 0.1)).cropped(to: CGRect(origin:.zero,size:sourceSize))
        for turn in 0...3 {
            for angle in [-15.0,-4,0,4,15] {
                for crop in Crop.allCases {
                    for anchor in [0.0,1.0] {
                        var r = Recipe(); r.rotation = turn; r.straighten = angle; r.crop = crop; r.cropX = anchor; r.cropY = anchor
                        let image = PhotoFraming.apply(solid,recipe:r)
                        let width = Int(image.extent.width), height = Int(image.extent.height)
                        var rgba = [UInt8](repeating:0,count:width*height*4)
                        context.render(image,toBitmap:&rgba,rowBytes:width*4,bounds:image.extent,format:.RGBA8,colorSpace:ImageEngine.output)
                        try require(stride(from:3,to:rgba.count,by:4).allSatisfy { rgba[$0] >= 254 },"Transparent corners after straightening/crop: \(turn), \(angle), \(crop), \(anchor), extent \(image.extent), minimum alpha \(stride(from:3,to:rgba.count,by:4).map { rgba[$0] }.min() ?? 0)")
                        edgeChecks += 1
                    }
                }
            }
        }
        }
        recipe.crop = .square; recipe.rotation = 1; recipe.straighten = 3.7; recipe.cropX = 0.2; recipe.cropY = 0.8
        let cropped = ImageEngine.apply(decoded.image,recipe:recipe)
        try require(abs(cropped.extent.width-cropped.extent.height) <= 1,"Square crop failed")
        for format in ExportFormat.allCases {
            let result = try ImageEngine.export(source: sourceURL,recipe:recipe,format:format)
            defer { try? FileManager.default.removeItem(at: result.url) }
            let reopened = try ImageEngine.open(result.url)
            try require(reopened.width == result.width && reopened.height == result.height,"Export dimensions incorrect")
            try require(reopened.width == reopened.height,"Export lost crop")
        }
        try require(try Data(contentsOf:sourceURL) == before,"Original was modified")
        recipe.lut = try LUTVerification.example(); recipe.lutAmount = 0.4
        edited.recipe = recipe; try await vault.save(edited)
        let lutReloaded = try await vault.load(); try require(lutReloaded.0.first?.recipe == recipe,"Project LUT persistence failed")
        let looks = [SavedLook(name:"QA",recipe:recipe)]; try await vault.saveLooks(looks)
        let saved = try await vault.load(); try require(saved.1.count == 1 && saved.1[0].recipe == recipe,"Preset persistence failed")
        try await vault.remove(project); let empty = try await vault.load(); try require(empty.0.isEmpty,"Project removal failed")
        var largeFixtures: [[String: Any]] = []
        for dimensions in [(4000,3000),(6000,4000),(8000,6000)] {
            let fixtureURL = root.appendingPathComponent("large-\(dimensions.0).jpg")
            try autoreleasepool {
                let bounds = CGRect(x: 0,y: 0,width: dimensions.0,height: dimensions.1)
                let gradient = CIFilter(name: "CILinearGradient",parameters: ["inputPoint0": CIVector(x: 0,y: 0),"inputPoint1": CIVector(x: CGFloat(dimensions.0),y: CGFloat(dimensions.1)),"inputColor0": CIColor(red: 0.04,green: 0.15,blue: 0.3),"inputColor1": CIColor(red: 0.9,green: 0.65,blue: 0.3)])!.outputImage!.cropped(to: bounds)
                try context.writeJPEGRepresentation(of: gradient,to: fixtureURL,colorSpace: ImageEngine.output)
                let began = Date()
                let preview = try ImageEngine.open(fixtureURL,maxDimension: 1600)
                try require(max(preview.image.extent.width,preview.image.extent.height) <= 1600,"Large preview exceeded size bound")
                var largeRecipe = Recipe(); largeRecipe.rgbCurves.master.middle = 0.54; largeRecipe.selectiveColors.orange.saturation = -0.2; largeRecipe.colorWheels.shadows.hue = 220; largeRecipe.colorWheels.shadows.strength = 0.1; largeRecipe.channelMixer.redGreen = 0.02
                largeRecipe.lut = try LUTVerification.example(dimension:65)
                let exported = try ImageEngine.export(source: fixtureURL,recipe: largeRecipe,format: .jpeg)
                defer { try? FileManager.default.removeItem(at: exported.url) }
                try require(exported.width == dimensions.0 && exported.height == dimensions.1,"Large export lost dimensions")
                largeFixtures.append(["width":dimensions.0,"height":dimensions.1,"previewAndExportSeconds":Date().timeIntervalSince(began)])
            }
        }
        let began = Date()
        for n in 0..<120 {
            try autoreleasepool {
                var r = Recipe(); r.exposure = sin(Double(n)*0.1); r.look = .daylight
                let image = ImageEngine.apply(decoded.image,recipe:r)
                guard context.createCGImage(image,from: image.extent) != nil else { throw StudioError.render }
            }
        }
        return ["scopesGeometry":try ScopeGeometryVerification.run(),"logInput":logReport,"lutTools":lutReport,"gradingTools":gradingReport,"colorTools":colorReport,"passed":true,"legacyProjectMigration":true,"sectionIndicators":true,"cropRepositioning":true,"geometryEdgeFixtures":edgeChecks,"presetFraming":true,"numericValidation":true,"largeImageFixtures":largeFixtures,"testedControls":controls,"looks":5,"exportFormats":["JPEG","PNG"],"originalPreserved":true,"recipePersistence":true,"presetPersistence":true,"deletion":true,"stressRenders":120,"stressSeconds":Date().timeIntervalSince(began),"thermalState":ProcessInfo.processInfo.thermalState.rawValue]
    }
}
#endif

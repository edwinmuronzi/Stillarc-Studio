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
            report["undoRedo"] = true
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
        let keys: [(String,WritableKeyPath<Recipe,Double>)] = [("Exposure",\.exposure),("Contrast",\.contrast),("Highlights",\.highlights),("Shadows",\.shadows),("Warmth",\.warmth),("Tint",\.tint),("Saturation",\.saturation),("Vibrance",\.vibrance),("Fade",\.fade),("Grain",\.grain),("Bloom",\.bloom),("Vignette",\.vignette),("Sharpen",\.sharpen),("Noise",\.noise),("Dark curve",\.curveShadows),("Middle curve",\.curveMidtones),("Bright curve",\.curveHighlights)]
        for (name,key) in keys {
            var r = Recipe(); r[keyPath:key] = 0.7
            try require(pixels(ImageEngine.apply(decoded.image,recipe:r)) != baseline,"\(name) did not affect pixels")
            controls.append(name)
        }
        for look in FilmLook.allCases where look != .original {
            var r = Recipe(); r.look = look
            try require(pixels(ImageEngine.apply(decoded.image,recipe:r)) != baseline,"\(look.rawValue) did not affect pixels")
        }
        recipe.crop = .square; recipe.rotation = 1
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
                let exported = try ImageEngine.export(source: fixtureURL,recipe: Recipe(),format: .jpeg)
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
        return ["passed":true,"largeImageFixtures":largeFixtures,"testedControls":controls,"looks":5,"exportFormats":["JPEG","PNG"],"originalPreserved":true,"recipePersistence":true,"presetPersistence":true,"deletion":true,"stressRenders":120,"stressSeconds":Date().timeIntervalSince(began),"thermalState":ProcessInfo.processInfo.thermalState.rawValue]
    }
}
#endif

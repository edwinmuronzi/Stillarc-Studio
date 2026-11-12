#if DEBUG
import Foundation
import CoreImage
import AVFoundation

enum ColorBatchVerification {
    static func check(_ condition:Bool,_ message:String) throws { if !condition { throw NSError(domain:"ColorBatch",code:1,userInfo:[NSLocalizedDescriptionKey:message]) } }
    static func pixel(_ image:CIImage) -> [Float] {
        var output = [Float](repeating:0,count:4)
        ImageEngine.context().render(image,toBitmap:&output,rowBytes:16,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.output)
        return output
    }
    static func run() async throws -> [String:Any] {
        let references = try LogVerification.run()
        let identity = try ColorLUTExport.make(recipe:Recipe(),dimension:33,name:"Identity")
        let largest = try ColorLUTExport.make(recipe:Recipe(),dimension:65,name:"Identity fine")
        for asset in [identity,largest] {
            let n = asset.dimension
            try asset.cube.withUnsafeBytes { values in
                for (r,g,b) in [(0,0,0),(n-1,n-1,n-1),(n/2,n/3,n/4)] {
                    let i = ((b*n+g)*n+r)*16
                    try check(abs(values.loadUnaligned(fromByteOffset:i,as:Float.self)-Float(r)/Float(n-1))<0.0002 && abs(values.loadUnaligned(fromByteOffset:i+4,as:Float.self)-Float(g)/Float(n-1))<0.0002 && abs(values.loadUnaligned(fromByteOffset:i+8,as:Float.self)-Float(b)/Float(n-1))<0.0002,"Color LUT identity/order/gamma")
                }
            }
        }
        var recipe = Recipe();recipe.exposure = 0.25;recipe.contrast = 0.1;recipe.saturation = -0.1;recipe.look = .bluehour;recipe.levelGamma = 1.08;recipe.rgbCurves.red.middle = 0.53;recipe.lut = try LUTVerification.example();recipe.lutAmount = 0.65
        let asset = try ColorLUTExport.make(recipe:recipe,dimension:33,name:"QA color")
        var maxError:Float = 0
        for rgb in [[0.3,0.5,0.6],[0.12,0.18,0.24],[0.7,0.6,0.5]] {
            let source = CIImage(color:CIColor(red:rgb[0],green:rgb[1],blue:rgb[2],alpha:1,colorSpace:ImageEngine.output)!).cropped(to:CGRect(x:0,y:0,width:4,height:4))
            let expected = pixel(ImageEngine.apply(source,recipe:recipe)),actual = pixel(asset.apply(source,amount:1))
            for i in 0..<3 { maxError = max(maxError,abs(expected[i]-actual[i])) }
        }
        try check(maxError<0.012,"Exported color LUT differs from direct grade")
        var effects = recipe;effects.grain = 0.5;effects.bloom = 0.3;effects.vignette = 0.4;effects.noise = 0.2;effects.sharpen = 0.1;effects.dehaze = 0.2;effects.crop = .square;effects.masks = [LocalMask(kind:.radial)];effects.input.profile = .sonySLog3Cine
        try check(effects.lutCompatibleColor == recipe.lutCompatibleColor && effects.lutExcludedEdits.count>=4,"LUT silently retained spatial/source edits")
        let file = try ColorLUTExport.write(asset);defer { try? FileManager.default.removeItem(at:file.deletingLastPathComponent()) }
        let parsed = try LUTAsset.read(file)
        try check(parsed.dimension == 33 && parsed.name == "QA color","Cube text roundtrip")
        let neutral = Recipe();let original = neutral
        _ = try ColorLUTExport.make(recipe:neutral,dimension:33,name:"Immutable")
        try check(neutral == original,"LUT export mutated source recipe")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ColorLibraryQA-\(UUID())")
        defer { try? FileManager.default.removeItem(at:root) }
        let library = await StudioLibrary(vault:ProjectVault(root:root))
        let saved = await library.saveLook(name:"Before",recipe:recipe);try check(saved,"Save look")
        guard let look = await library.looks.first else { throw StudioError.render }
        let renamed = await library.renameLook(look,name:"Renamed")
        let looks = await library.looks;try check(renamed && looks.first?.id == look.id && looks.first?.name == "Renamed" && looks.first?.recipe == recipe.colorPreset,"Rename changed preset identity/grade")
        _ = await library.saveLook(name:"Renamed copy",recipe:look.recipe)
        let reloaded = try await library.vault.load();try check(reloaded.1.count == 2,"Duplicate persistence")
        return ["passed":true,"activeLUTBaked":true,"logReferences":references,"identity33And65":true,"cubeRedFastestAndGamma":true,"roundTrip":true,"colorMatchMaxError":maxError,"excludedEffects":true,"immutableRecipe":true,"renameDuplicatePersistence":true]
    }
    static func video() async throws -> [String:Any] {
        var count = 0
        for profile in [CameraLogProfile.sonySLog3Cine,.panasonicVLog] {
            let source = try await VideoFixtures.make(profile:profile,frames:6,audioTracks:1,width:128,height:72)
            defer { try? FileManager.default.removeItem(at:source.deletingLastPathComponent()) }
            let descriptor = try await VideoEngine.describe(source)
            var recipe = Recipe();recipe.input = InputConversion(profile:profile,softHighlights:false)
            let poster = try await VideoEngine.poster(source,descriptor:descriptor,maxDimension:128)
            let actual = pixel(ImageEngine.apply(poster.source(for:recipe),recipe:recipe))
            let values = VideoFixtures.scene,wantedLinear = profile.matrix.map { zip($0,values).map(*).reduce(0,+) }
            for i in 0..<3 {
                let v = max(0,wantedLinear[i]),wanted = v<=0.0031308 ? 12.92*v : 1.055*pow(v,1/2.4)-0.055
                try check(abs(Double(actual[i])-wanted)<0.025,"\(profile): encoded Log preview mismatch")
            }
            let result = try await VideoEngine.export(source:source,descriptor:descriptor,recipe:recipe,progress:{ _ in })
            defer { try? FileManager.default.removeItem(at:result.url) }
            let output = try await VideoEngine.describe(result.url),decoded = try await VideoEngine.poster(result.url,descriptor:output,maxDimension:128)
            let encoded = pixel(decoded.image)
            for i in 0..<3 { try check(abs(encoded[i]-actual[i])<0.025,"\(profile): encoded output differs from preview") }
            let audio = try await AVURLAsset(url:result.url).loadTracks(withMediaType:.audio)
            try check(audio.count == 1 && abs(output.duration-descriptor.duration)<0.04 && output.width == 128 && output.height == 72,"New Log export audio/timing/size")
            count += 1
        }
        return ["passed":true,"profiles":count,"previewExportMatch":true,"audioTimingSize":true]
    }
    @MainActor static func writeReport() async {
        let url = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("color-batch-verification.json")
        do {
            let report = try await Task.detached(priority:.utility) { () -> [String:Any] in
                var result:[String:Any] = ["version":"0.27.0","passed":true,"color":try await run()]
                #if !targetEnvironment(simulator)
                result["video"] = try await video()
                #endif
                return result
            }.value
            try JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:url,options:.atomic)
        } catch { try? JSONSerialization.data(withJSONObject:["version":"0.27.0","passed":false,"error":error.localizedDescription],options:.prettyPrinted).write(to:url,options:.atomic) }
    }
}
#endif

#if DEBUG
import Foundation
import CoreImage
import AVFoundation

enum RefinementVerification {
    static func check(_ condition:Bool,_ message:String) throws { if !condition { throw NSError(domain:"RefinementQA",code:1,userInfo:[NSLocalizedDescriptionKey:message]) } }
    static func bitmap(_ image:CIImage) -> [Float] {
        let e = image.extent;var values = [Float](repeating:0,count:Int(e.width*e.height)*4)
        ImageEngine.context().render(image,toBitmap:&values,rowBytes:Int(e.width)*16,bounds:e,format:.RGBAf,colorSpace:ImageEngine.working)
        return values
    }
    static func run() async throws -> [String:Any] {
        try LensRendering.prepare();try FilmRendering.prepare()
        let size = 256,bounds = CGRect(x:0,y:0,width:256,height:256)
        let base = CIImage(color:CIColor(red:0.18,green:0.18,blue:0.18,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:bounds)
        try check(LensRendering.apply(base,strength:0) === base,"Neutral lens did not bypass")
        try check(FilmRendering.apply(base,recipe:Recipe()) === base,"Neutral film did not bypass")
        // Coordinate-encoded pixels let the warp be tested against its radial equation.
        var ramp = [Float]();ramp.reserveCapacity(size*size*4)
        for y in 0..<size { for x in 0..<size { ramp += [Float(x)/Float(size-1),Float(y)/Float(size-1),0.2,1] } }
        let rampData = ramp.withUnsafeBytes { Data($0) }
        let grid = CIImage(bitmapData:rampData,bytesPerRow:size*16,size:CGSize(width:size,height:size),format:.RGBAf,colorSpace:ImageEngine.working)
        for k in [-0.25,0.25] {
            let corrected = LensRendering.apply(grid,strength:k),pixels = bitmap(corrected)
            try check(corrected.extent == bounds && pixels.allSatisfy(\.isFinite),"Lens bounds/finiteness")
            for (x,y) in [(1,1),(128,128),(240,120),(255,255)] {
                let qx = Double(x)+0.5-128,qy = Double(y)+0.5-128,r2 = (qx*qx+qy*qy)/(128*128*2),f = (1+k*r2)/max(1,1+k)
                let expectedX = (128+qx*f-0.5)/255,expectedY = (128+qy*f-0.5)/255,i = (y*size+x)*4
                try check(abs(Double(pixels[i])-expectedX)<0.012 && abs(Double(pixels[i+1])-expectedY)<0.012 && pixels[i+3]>0.99,"Lens mapping or filled edge")
            }
        }
        var grain = Recipe();grain.grain = 0.7;grain.grainSize = 0.6
        let first = bitmap(FilmRendering.apply(base,recipe:grain)),again = bitmap(FilmRendering.apply(base,recipe:grain))
        try check(first == again,"Still grain changed between identical renders")
        let values = stride(from:0,to:first.count,by:4).map { Double(first[$0]) },mean = values.reduce(0,+)/Double(values.count),variance = values.reduce(0) { $0+pow($1-mean,2) }/Double(values.count)
        try check(abs(mean-0.18)<0.006 && variance>0.00000001,"Grain mean/texture")
        let transparent = CIImage(color:CIColor(red:0,green:0,blue:0,alpha:0)).cropped(to:bounds)
        try check(bitmap(FilmRendering.apply(transparent,recipe:grain)).allSatisfy { abs($0)<0.00001 },"Grain alpha")
        let timed = MaskMotion.$frame.withValue(.init(time:1,framing:"QA")) { bitmap(FilmRendering.apply(base,recipe:grain)) }
        try check(timed != first,"Video grain did not follow timestamps")
        var halo = Recipe();halo.halation = 1
        let black = CIImage(color:.black).cropped(to:bounds)
        try check(bitmap(FilmRendering.apply(black,recipe:halo)).allSatisfy { $0.isFinite },"Halo black finiteness")
        let light = CIImage(color:CIColor(red:4,green:4,blue:4,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:CGRect(x:100,y:100,width:56,height:56)).composited(over:black)
        let glow = bitmap(FilmRendering.apply(light,recipe:halo))
        var outside = 0.0
        for y in 96..<160 { for x in 96..<160 where x<100 || x>=156 || y<100 || y>=156 { let i = (y*size+x)*4;outside = max(outside,Double(glow[i]));try check(glow[i]>=glow[i+1] && glow[i+1]>=glow[i+2],"Halation hue") } }
        try check(outside>0.0001 && abs(glow[(128*size+128)*4]-4)<0.001,"Halation edge/core separation")
        let old = try JSONDecoder().decode(Recipe.self,from:Data("{\"grain\":0.3}".utf8)),neutral = try JSONDecoder().decode(Recipe.self,from:Data("{}".utf8))
        try check(old.grainModel == 1 && neutral == Recipe(),"Legacy grain migration changed old edits/defaults")
        var recipe = grain;recipe.halation = 0.4;recipe.geometry.lensDistortion = 0.15
        let decoded = try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(recipe))
        try check(decoded == recipe,"Refinement persistence")
        try check(recipe.hasAdjustments(in:.film) && recipe.hasAdjustments(in:.crop),"Refinement edit dots")
        let signature = MaskMotion.signature(recipe)
        try check(MaskFramingRepair.snapshot(signature)?.geometry.lensDistortion == 0.15 && !MaskFramingRepair.sameField(Recipe(),recipe),"Lens mask-anchor compatibility")
        try check(PresetDocument(name:"QA",recipe:recipe.colorPreset).schema == 3,"New film preset schema")
        let pasted = Recipe().pasting(recipe,sections:[.texture])
        try check(pasted.grainModel == 2 && pasted.halation == 0.4 && pasted.grainSize == 0.6 && pasted.geometry.lensDistortion == 0,"Film transfer/source isolation")
        var reset = recipe;reset.reset(.film);reset.reset(.crop)
        try check(!reset.hasAdjustments(in:.film) && !reset.hasAdjustments(in:.crop),"Refinement reset")
        try check(recipe.lutCompatibleColor.halation == 0 && recipe.lutCompatibleColor.geometry.lensDistortion == 0,"Color LUT spatial exclusion")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("RefinementQA-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer { try? FileManager.default.removeItem(at:root) }
        let source = root.appendingPathComponent("source.png")
        try ImageEngine.context().writePNGRepresentation(of:light,to:source,format:.RGBA8,colorSpace:ImageEngine.output)
        let original = try Data(contentsOf:source),prepared = try ImageEngine.open(source)
        let preview = ImageEngine.apply(prepared.source(for:recipe),recipe:recipe)
        let export = try ImageEngine.export(source:source,recipe:recipe,format:.png)
        defer { try? FileManager.default.removeItem(at:export.url) }
        let reopened = try ImageEngine.open(export.url),a = bitmap(preview),b = bitmap(reopened.image)
        var maxError:Float = 0
        for i in stride(from:0,to:a.count,by:4) { for c in 0..<3 { maxError = max(maxError,abs(min(1,max(0,a[i+c]))-b[i+c])) } }
        try check(maxError<0.02 && export.width == 256 && export.height == 256,"Refinement preview/export mismatch")
        try check(try Data(contentsOf:source) == original,"Refinement changed source")
        return ["passed":true,"neutralBypass":true,"lensMappingFilledEdges":true,"grainDeterministicMean":mean,"grainVariance":variance,"timestampGrain":true,"halationEdges":true,"legacyMigration":true,"persistenceSchemaTransferReset":true,"maskAnchorSafety":true,"sourcePreserved":true,"exportMaxError":maxError]
    }
    static func video() async throws -> [String:Any] {
        let source = try await VideoFixtures.make(profile:.standard,frames:12,audioTracks:1,width:320,height:240)
        defer { try? FileManager.default.removeItem(at:source.deletingLastPathComponent()) }
        let before = try Data(contentsOf:source),descriptor = try await VideoEngine.describe(source)
        var recipe = Recipe();recipe.grain = 0.35;recipe.grainSize = 0.5;recipe.halation = 0.4;recipe.geometry.lensDistortion = 0.12
        let poster = try await VideoEngine.poster(source,descriptor:descriptor,maxDimension:320)
        let expected = MaskMotion.$frame.withValue(.init(time:0,framing:MaskMotion.signature(recipe))) { bitmap(ImageEngine.apply(poster.image,recipe:recipe)) }
        let file = try await VideoEngine.export(source:source,descriptor:descriptor,recipe:recipe,progress:{ _ in })
        defer { try? FileManager.default.removeItem(at:file.url) }
        let output = try await VideoEngine.describe(file.url),decoded = try await VideoEngine.poster(file.url,descriptor:output,maxDimension:320),actual = bitmap(decoded.image)
        var error = 0.0
        for i in stride(from:0,to:actual.count,by:4) { for c in 0..<3 { error += abs(Double(actual[i+c]-expected[i+c])) } }
        error /= Double(actual.count/4*3)
        try check(error<0.02,"Film/lens video preview-export match")
        let asset = AVURLAsset(url:file.url),tracks = try await asset.loadTracks(withMediaType:.video),audio = try await asset.loadTracks(withMediaType:.audio)
        guard let track = tracks.first else { throw StudioError.render }
        let reader = try AVAssetReader(asset:asset),samples = AVAssetReaderTrackOutput(track:track,outputSettings:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA]);reader.add(samples);try check(reader.startReading(),"Refinement reader")
        var count = 0,last = -1.0
        while let sample = samples.copyNextSampleBuffer() { let time = CMSampleBufferGetPresentationTimeStamp(sample).seconds;try check(time>last,"Video timestamps");last = time;count += 1 }
        try check(count == 12 && audio.count == 1 && output.width == 320 && output.height == 240 && abs(output.duration-descriptor.duration)<0.04,"Refinement video frames/audio/timing/size")
        try check(try Data(contentsOf:source) == before,"Video source changed")
        return ["passed":true,"frames":count,"previewExportMeanError":error,"audioTimingSize":true,"sourcePreserved":true]
    }
    @MainActor static func writeReport() async {
        let url = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("refinement-verification.json")
        do {
            let result = try await Task.detached(priority:.utility) { () -> [String:Any] in
                var report:[String:Any] = ["version":"0.28.0","passed":true,"refinement":try await run()]
                #if !targetEnvironment(simulator)
                report["video"] = try await video()
                #endif
                return report
            }.value
            try JSONSerialization.data(withJSONObject:result,options:.prettyPrinted).write(to:url,options:.atomic)
        } catch { try? JSONSerialization.data(withJSONObject:["version":"0.28.0","passed":false,"error":error.localizedDescription],options:.prettyPrinted).write(to:url,options:.atomic) }
    }
}
#endif

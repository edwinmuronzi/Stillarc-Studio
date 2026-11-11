#if DEBUG
import Foundation
import CoreImage
import ImageIO

enum ColorVerification {
    static func run() throws -> [String:Any] {
        func require(_ value: Bool,_ message: String) throws {
            if !value { throw NSError(domain:"ColorVerification",code:1,userInfo:[NSLocalizedDescriptionKey:message]) }
        }
        try ColorPipeline.prepare()
        let context = ImageEngine.context()
        func solid(_ rgb: [CGFloat],alpha: CGFloat = 1) -> CIImage {
            let color = CIColor(red:rgb[0],green:rgb[1],blue:rgb[2],alpha:alpha,colorSpace:ImageEngine.output)!
            return CIImage(color:color).cropped(to:CGRect(x:0,y:0,width:4,height:4))
        }
        func pixel(_ image: CIImage) -> [Float] {
            var result = [Float](repeating:0,count:4)
            context.render(image,toBitmap:&result,rowBytes:16,bounds:CGRect(x:1,y:1,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.output)
            return result
        }
        let source = solid([0.5,0.5,0.5])
        let baseline = pixel(source)
        func near(_ a: Float,_ b: Float,_ tolerance: Float = 0.006) -> Bool { abs(a-b) < tolerance }
        try require(pixel(ColorPipeline.applyCurves(source,curves:RGBCurves())) == baseline,"Neutral RGB curve changed pixels")
        var channelChecks = 0
        for channel in [CurveChannel.red,.green,.blue] {
            var curves = RGBCurves(); curves[keyPath:channel.key].middle = 0.65
            let result = pixel(ColorPipeline.applyCurves(source,curves:curves))
            let changed = channel == .red ? 0 : channel == .green ? 1 : 2
            try require(near(result[changed],0.65),"RGB curve failed to raise its own channel: \(channel), baseline \(baseline), result \(result)")
            for index in 0..<3 where index != changed { try require(near(result[index],baseline[index]),"RGB curve changed an unrelated channel") }
            channelChecks += 1
        }
        var master = RGBCurves(); master.master.middle = 0.65
        let raised = pixel(ColorPipeline.applyCurves(source,curves:master))
        try require((0..<3).allSatisfy { raised[$0] > baseline[$0]+0.08 },"Master curve did not affect all channels")
        var splineChecks = 0
        for sample in [ToneCurve(), { var c = ToneCurve(); c.shadows = 0.8; c.middle = 0.2; c.highlights = 0.9; return c }()] {
            let spline = CurveSpline(sample)
            for point in CurvePoint.allCases { try require(abs(spline.value(at:point.input)-sample[keyPath:point.key]) < 0.000001,"Spline missed control point") }
            for i in 0...1000 {
                let value = spline.value(at:Double(i)/1000)
                try require(value.isFinite && value >= -0.000001 && value <= 1.000001,"Curve overshot or became invalid")
                splineChecks += 1
            }
        }
        // A color swatch for each center, plus neutral gray; input/output use the same sRGB transform.
        func swatch(_ degrees: Double) -> [CGFloat] {
            let h = degrees/60, chroma = 0.6
            let shape = [0.0,4,2].map { component in min(1,max(0,abs((h+component).truncatingRemainder(dividingBy:6)-3)-1)) }
            return shape.map { CGFloat(0.2+chroma*$0) }
        }
        var rangeChecks = 0
        for band in ColorRange.allCases {
            let input = solid(swatch(band.degrees)), original = pixel(input)
            for key in [\ColorRangeAdjustment.hue,\.saturation,\.brightness] {
                var adjustments = SelectiveColors(); adjustments[keyPath:band.key][keyPath:key] = key == \ColorRangeAdjustment.hue ? 20 : -0.65
                let result = pixel(ColorPipeline.applySelective(input,adjustments:adjustments))
                try require((0..<3).contains { abs(result[$0]-original[$0]) > 0.015 },"Selective \(band.title) component did not affect its hue")
                let opposite = solid(swatch((band.degrees+180).truncatingRemainder(dividingBy:360)))
                let untouched = pixel(opposite), transformed = pixel(ColorPipeline.applySelective(opposite,adjustments:adjustments))
                try require((0..<3).allSatisfy { near(untouched[$0],transformed[$0]) },"Selective edit affected an unrelated hue")
                let gray = solid([0.45,0.45,0.45]), grayBefore = pixel(gray), grayAfter = pixel(ColorPipeline.applySelective(gray,adjustments:adjustments))
                try require((0..<3).allSatisfy { near(grayBefore[$0],grayAfter[$0]) },"Selective edit tinted neutral gray")
                rangeChecks += 1
            }
        }
        var saturated = SelectiveColors(); saturated.red.saturation = -1
        let desaturated = pixel(ColorPipeline.applySelective(solid(swatch(0)),adjustments:saturated))
        try require(near(desaturated[0],desaturated[1]) && near(desaturated[1],desaturated[2]),"Full selected desaturation did not produce gray")
        var negativeHue = SelectiveColors(); negativeHue.red.hue = -20
        var positiveHue = SelectiveColors(); positiveHue.red.hue = 20
        let negativeRed = pixel(ColorPipeline.applySelective(solid(swatch(0)),adjustments:negativeHue))
        let positiveRed = pixel(ColorPipeline.applySelective(solid(swatch(0)),adjustments:positiveHue))
        try require(negativeRed[2] > negativeRed[1]+0.1 && positiveRed[1] > positiveRed[2]+0.1,"Hue direction or negative hue wrap is incorrect")
        let semi = solid(swatch(0),alpha:0.5)
        try require(near(pixel(ColorPipeline.applySelective(semi,adjustments:saturated))[3],pixel(semi)[3]),"Selective color changed alpha")
        let green = solid(swatch(120))
        let mask = pixel(ImageEngine.apply(green,recipe:Recipe(),rangePreview:.red))
        try require(near(mask[0],mask[1]) && near(mask[1],mask[2]),"Range preview failed to dim unrelated colors")
        let regular = pixel(ImageEngine.apply(green,recipe:Recipe()))
        try require(!near(regular[0],regular[1]),"Range preview leaked into the normal render path")
        // Wrap around red smoothly and preserve signal beyond the ordinary SDR interval.
        let left = pixel(ColorPipeline.applySelective(solid(swatch(359.9)),adjustments:saturated))
        let right = pixel(ColorPipeline.applySelective(solid(swatch(0.1)),adjustments:saturated))
        try require(zip(left,right).allSatisfy { near($0.0,$0.1,0.015) },"Red range has a hue-wrap seam")
        var saved = Recipe(); saved.rgbCurves = master; saved.selectiveColors.orange.hue = 10
        saved.crop = .portrait; saved.cropY = 0.8
        let restored = try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(saved))
        try require(restored == saved,"New color controls did not round trip")
        let preset = PresetDocument(name:"Color QA",recipe:saved.colorPreset)
        let savedPreset = try JSONDecoder().decode(PresetDocument.self,from:JSONEncoder().encode(preset))
        try require(savedPreset.recipe.rgbCurves == saved.rgbCurves && savedPreset.recipe.selectiveColors == saved.selectiveColors && !savedPreset.recipe.hasAdjustments(in:.crop),"Preset lost color edits or carried framing")
        var legacy = try JSONSerialization.jsonObject(with:JSONEncoder().encode(saved)) as! [String:Any]
        legacy.removeValue(forKey:"rgbCurves"); legacy.removeValue(forKey:"selectiveColors")
        let old = try JSONDecoder().decode(Recipe.self,from:JSONSerialization.data(withJSONObject:legacy))
        try require(old.rgbCurves.isNeutral && old.selectiveColors.isNeutral && old.cropY == 0.8,"Old recipes did not get neutral color defaults")
        try require(saved.hasAdjustments(in:.curves) && saved.hasAdjustments(in:.color),"New controls failed to mark edited sections")
        var reset = saved; reset.reset(.color)
        try require(reset.selectiveColors.isNeutral && reset.rgbCurves == master && reset.cropY == 0.8,"Color reset disturbed curves or framing")
        reset.reset(.curves); try require(reset.rgbCurves.isNeutral,"Curve reset left new curves active")
        // Full-size exports use normal editing, never preview-only isolation.
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("StudioColorQA-\(UUID()).png")
        defer { try? FileManager.default.removeItem(at:file) }
        try context.writePNGRepresentation(of:solid([0.35,0.45,0.55]),to:file,format:.RGBA8,colorSpace:ImageEngine.output)
        var recipe = Recipe(); recipe.rgbCurves = master; recipe.selectiveColors.blue.brightness = -0.2
        let expected = pixel(ImageEngine.apply(try ImageEngine.open(file).image,recipe:recipe))
        for format in ExportFormat.allCases {
            let exported = try ImageEngine.export(source:file,recipe:recipe,format:format)
            defer { try? FileManager.default.removeItem(at:exported.url) }
            let actual = pixel(try ImageEngine.open(exported.url).image)
            try require((0..<3).allSatisfy { near(expected[$0],actual[$0],format == .jpeg ? 0.03 : 0.01) },"Color export differs from render")
        }
        return ["passed":true,"kernelBackend":ColorPipeline.backend,"compilationNote":ColorPipeline.compilationNote,"channelIsolation":channelChecks,"splineSamples":splineChecks,"selectiveComponents":rangeChecks,"neutralGray":true,"hueWrap":true,"hueDirections":true,"alphaPreserved":true,"rangePreviewNotExported":true,"oldRecipeMigration":true,"recipeRoundTrip":true,"presetColorRoundTrip":true,"resetIsolation":true,"exportColorMatch":true]
    }
}
#endif

#if DEBUG
import Foundation
import CoreImage

enum GradingVerification {
    static func run() throws -> [String:Any] {
        func require(_ value: Bool,_ message: String) throws {
            if !value { throw NSError(domain:"GradingVerification",code:1,userInfo:[NSLocalizedDescriptionKey:message]) }
        }
        try ColorPipeline.prepare()
        let context = ImageEngine.context()
        func solid(_ components: [CGFloat],alpha: CGFloat = 1) -> CIImage {
            CIImage(color:CIColor(red:components[0],green:components[1],blue:components[2],alpha:alpha,colorSpace:ImageEngine.output)!).cropped(to:CGRect(x:0,y:0,width:4,height:4))
        }
        func pixel(_ image: CIImage) -> [Float] {
            var data = [Float](repeating:0,count:4)
            context.render(image,toBitmap:&data,rowBytes:16,bounds:CGRect(x:1,y:1,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.output)
            return data
        }
        func near(_ a: Float,_ b: Float,_ tolerance: Float = 0.006) -> Bool { abs(a-b) < tolerance }
        func apply(_ image: CIImage,wheels: ColorWheels = ColorWheels(),mixer: ChannelMixer = ChannelMixer()) -> CIImage {
            ColorPipeline.applySelective(image,adjustments:SelectiveColors(),wheels:wheels,mixer:mixer)
        }
        let source = solid([0.25,0.45,0.65]), baseline = pixel(source)
        try require(pixel(apply(source)) == baseline,"Neutral grading changed pixels")
        var mixerChecks = 0
        for output in MixerChannel.allCases {
            for key in output.keys+[output.offsetKey] {
                var matrix = ChannelMixer(); matrix[keyPath:key] += key == output.offsetKey ? 0.05 : 0.2
                let result = pixel(apply(source,mixer:matrix))
                func row(_ channel: MixerChannel) -> CIVector {
                    let k = channel.keys
                    return CIVector(x:matrix[keyPath:k[0]],y:matrix[keyPath:k[1]],z:matrix[keyPath:k[2]],w:0)
                }
                let expected = pixel(source.applyingFilter("CIColorMatrix",parameters:["inputRVector":row(.red),"inputGVector":row(.green),"inputBVector":row(.blue),"inputBiasVector":CIVector(x:matrix.redOffset,y:matrix.greenOffset,z:matrix.blueOffset,w:0)]))
                try require((0..<4).allSatisfy { near(result[$0],expected[$0]) },"Mixer arithmetic differs from reference: \(output), \(key)")
                try require((0..<3).contains { abs(result[$0]-baseline[$0]) > 0.005 },"Mixer parameter had no effect")
                mixerChecks += 1
            }
        }
        var swap = ChannelMixer(); swap.swapRedAndBlue()
        let swapped = pixel(apply(source,mixer:swap))
        try require(near(swapped[0],baseline[2]) && near(swapped[1],baseline[1]) && near(swapped[2],baseline[0]),"Red/blue swap failed")
        var negative = ChannelMixer(); negative.redGreen = -0.2
        try require(pixel(apply(source,mixer:negative))[0] < baseline[0],"Negative coefficient did not subtract input")
        var mono = ChannelMixer(); mono.monochrome = true
        let monochrome = pixel(apply(source,mixer:mono))
        try require(near(monochrome[0],monochrome[1]) && near(monochrome[1],monochrome[2]),"Monochrome is not neutral gray")
        let semi = solid([0.25,0.45,0.65],alpha:0.4)
        try require(near(pixel(apply(semi,mixer:swap))[3],pixel(semi)[3]),"Mixer changed alpha")
        var wheelChecks = 0
        for zone in WheelZone.allCases {
            var wheels = ColorWheels(); wheels[keyPath:zone.key].hue = 0; wheels[keyPath:zone.key].strength = 0.4
            let tone: CGFloat = zone == .shadows ? 0.04 : zone == .highlights ? 0.96 : 0.5
            let gray = solid([tone,tone,tone]), before = pixel(gray), result = pixel(apply(gray,wheels:wheels))
            try require(result[0] > result[1]+0.008,"Wheel did not tint its range: \(zone)")
            let beforeY = before[0]*0.2126+before[1]*0.7152+before[2]*0.0722
            let afterY = result[0]*0.2126+result[1]*0.7152+result[2]*0.0722
            try require(abs(beforeY-afterY) < 0.003,"Keep brightness failed: \(zone)")
            for end: CGFloat in [0,1] {
                let endpoint = pixel(apply(solid([end,end,end]),wheels:wheels))
                try require((0..<3).allSatisfy { near(endpoint[$0],Float(end),0.003) },"Wheel tinted a protected black/white endpoint")
            }
            wheels[keyPath:zone.key].strength = 0; wheels[keyPath:zone.key].exposure = -0.4
            let darker = pixel(apply(gray,wheels:wheels))
            try require(darker[0] < before[0]-0.005,"Wheel brightness had no effect: \(zone)")
            if zone == .shadows || zone == .highlights {
                let far: CGFloat = zone == .shadows ? 0.96 : 0.04
                let unrelated = solid([far,far,far]), unchanged = pixel(unrelated), processed = pixel(apply(unrelated,wheels:wheels))
                try require((0..<3).allSatisfy { near(unchanged[$0],processed[$0]) },"Tonal wheel affected the opposite range")
            }
            wheelChecks += 1
        }
        var exposureOnly = ColorWheels(); exposureOnly.global.exposure = -0.5
        let wide = CIImage(color:CIColor(red:1.1,green:0.1,blue:0.02)).cropped(to:CGRect(x:0,y:0,width:4,height:4))
        let expectedExposure = pixel(wide.applyingFilter("CIExposureAdjust",parameters:["inputEV":-0.5]))
        let actualExposure = pixel(apply(wide,wheels:exposureOnly))
        try require((0..<3).allSatisfy { near(expectedExposure[$0],actualExposure[$0]) },"Brightness-only wheel altered color or highlight headroom")
        var balance = ColorWheels(); balance.shadows.hue = 220; balance.shadows.strength = 0.4
        let middle = solid([0.35,0.35,0.35])
        balance.balance = -0.6; let moreShadows = pixel(apply(middle,wheels:balance))
        balance.balance = 0.6; let lessShadows = pixel(apply(middle,wheels:balance))
        try require((0..<3).contains { abs(moreShadows[$0]-lessShadows[$0]) > 0.01 },"Wheel balance did not change tonal weighting")
        balance.balance = 0; balance.blend = 0; let tight = pixel(apply(middle,wheels:balance))
        balance.blend = 1; let soft = pixel(apply(middle,wheels:balance))
        try require((0..<3).contains { abs(tight[$0]-soft[$0]) > 0.005 },"Wheel blend did not change transitions")
        var hueOnly = ColorWheels(); hueOnly.global.hue = 220; hueOnly.balance = 0.4
        try require(hueOnly.isNeutral && pixel(apply(source,wheels:hueOnly)) == baseline,"Hue without strength introduced an edit")
        var saved = Recipe(); saved.colorWheels = balance; saved.colorWheels.global.hue = 123.456789; saved.colorWheels.global.strength = 0.12; saved.channelMixer = swap
        saved.rgbCurves.red.middle = 0.55; saved.selectiveColors.orange.hue = 8; saved.crop = .portrait; saved.cropY = 0.8
        let restored = try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(saved))
        try require(restored == saved,"Grading recipe did not round trip")
        let preset = try JSONDecoder().decode(PresetDocument.self,from:JSONEncoder().encode(PresetDocument(name:"Grading",recipe:saved.colorPreset)))
        try require(preset.recipe.colorWheels == saved.colorWheels && preset.recipe.channelMixer == saved.channelMixer && !preset.recipe.hasAdjustments(in:.crop),"Preset lost grading or carried framing")
        var legacy = try JSONSerialization.jsonObject(with:JSONEncoder().encode(saved)) as! [String:Any]
        legacy.removeValue(forKey:"colorWheels"); legacy.removeValue(forKey:"channelMixer")
        let migrated = try JSONDecoder().decode(Recipe.self,from:JSONSerialization.data(withJSONObject:legacy))
        try require(migrated.colorWheels.isNeutral && migrated.channelMixer.isNeutral && migrated.rgbCurves == saved.rgbCurves && migrated.cropY == 0.8,"Old grading migration changed existing edits")
        var reset = saved; reset.reset(.color)
        try require(reset.colorWheels.isNeutral && reset.channelMixer.isNeutral && reset.selectiveColors.isNeutral && reset.rgbCurves == saved.rgbCurves && reset.cropY == saved.cropY,"Color reset disturbed curves or framing")
        try require(saved.hasAdjustments(in:.color),"Grading did not mark the Color tab")
        var matrixReset = swap; matrixReset.greenRed = 0.2; matrixReset.reset(.green)
        try require(matrixReset.isNeutral(channel:.green) && matrixReset.redBlue == 1,"Reset output affected another channel")
        var constrained = saved; constrained.colorWheels.global.hue = -720; constrained.colorWheels.global.strength = 50; constrained.channelMixer.redBlue = 50
        constrained = constrained.validated()
        try require(constrained.colorWheels.global.hue == 0 && constrained.colorWheels.global.strength == 1 && constrained.channelMixer.redBlue == 2,"Invalid grading values were not bounded")
        let blue = solid([0.2,0.2,0.8])
        let normalPreview = pixel(ImageEngine.apply(blue,recipe:Recipe(),rangePreview:.blue))
        let gradingPreview = pixel(ImageEngine.apply(blue,recipe:saved.colorPreset,rangePreview:.blue))
        // Curves/selective color remain in range inspection, but wheels and mixer must be excluded.
        var preGrade = saved.colorPreset; preGrade.colorWheels = ColorWheels(); preGrade.channelMixer = ChannelMixer()
        let expectedPreview = pixel(ImageEngine.apply(blue,recipe:preGrade,rangePreview:.blue))
        try require((0..<4).allSatisfy { near(gradingPreview[$0],expectedPreview[$0]) } && normalPreview[2] > normalPreview[0],"Range inspection included later grading")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("StudioGradingQA-\(UUID()).png")
        defer { try? FileManager.default.removeItem(at:file) }
        try context.writePNGRepresentation(of:source,to:file,format:.RGBA8,colorSpace:ImageEngine.output)
        let expected = pixel(ImageEngine.apply(try ImageEngine.open(file).image,recipe:saved.colorPreset))
        for format in ExportFormat.allCases {
            let result = try ImageEngine.export(source:file,recipe:saved.colorPreset,format:format)
            defer { try? FileManager.default.removeItem(at:result.url) }
            let actual = pixel(try ImageEngine.open(result.url).image)
            try require((0..<3).allSatisfy { near(actual[$0],expected[$0],format == .jpeg ? 0.03 : 0.01) },"Grading export does not match normal render")
        }
        return ["passed":true,"mixerParameters":mixerChecks,"wheelZones":wheelChecks,"brightnessPreserved":true,"exposureOnlyMatchesReference":true,"tonalIsolation":true,"balanceBlend":true,"swap":true,"negativeMixing":true,"monochrome":true,"alphaPreserved":true,"recipePresetRoundTrip":true,"legacyMigration":true,"resetIsolation":true,"rangeInspectionExcludesGrading":true,"exportMatch":true]
    }
}
#endif

#if DEBUG
import Foundation

enum AdjustmentTransferVerification {
    static func run() async throws -> [String:Any] {
        func require(_ v:Bool,_ message:String) throws { if !v { throw NSError(domain:"AdjustmentTransfer",code:1,userInfo:[NSLocalizedDescriptionKey:message]) } }
        var source = Recipe()
        source.exposure = 1;source.contrast = 0.2;source.highlights = -0.3;source.shadows = 0.4;source.whites = 0.1;source.blacks = -0.2
        source.warmth = 0.3;source.tint = -0.1;source.saturation = 0.2;source.vibrance = 0.4;source.selectiveColors.blue.saturation = -0.2
        source.rgbCurves.red.middle = 0.6;source.curveShadows = 0.1;source.curveMidtones = -0.1;source.curveHighlights = 0.2
        source.colorWheels.shadows.hue = 220;source.colorWheels.shadows.strength = 0.2;source.channelMixer.redGreen = 0.1
        source.look = .daylight;source.lookAmount = 0.5;source.lut = try LUTVerification.example(dimension:33);source.lutAmount = 0.7
        source.grain = 0.2;source.bloom = 0.1;source.fade = 0.1;source.vignette = 0.2;source.sharpen = 0.3;source.noise = 0.2
        source.input.profile = .appleLog;source.crop = .square;source.video.start = 4;source.video.end = 8
        var destination = Recipe();destination.input.profile = .appleLog2;destination.input.exposure = -0.5;destination.crop = .free;destination.geometry.width = 0.7;destination.geometry.flipVertical = true;destination.geometry.horizontal = 0.1;destination.rotation = 1;destination.straighten = 2;destination.cropX = 0.2;destination.cropY = 0.8;destination.video.start = 0.5;destination.video.end = 3;destination.video.hdr = true
        let all = Set(AdjustmentSection.allCases),pasted = destination.pasting(source,sections:all)
        var expected = source.colorPreset;expected.copyFraming(from:destination);expected.input = destination.input;expected.video = destination.video
        try require(pasted == expected,"Full paste changed destination-specific settings or missed a grade section")
        let wb = pasted.pasting(Recipe(),sections:[.whiteBalance])
        var expectedWB = pasted;expectedWB.warmth = 0;expectedWB.tint = 0
        try require(wb == expectedWB,"White-balance paste changed unselected adjustments")
        let noLUT = pasted.pasting(Recipe(),sections:[.lut])
        try require(noLUT.lut == nil && noLUT.look == source.look && noLUT.grain == source.grain,"LUT Off did not clear only the destination LUT")
        try require(destination.pasting(source,sections:[]) == destination,"Empty paste changed the edit")
        var checks = 0
        for section in AdjustmentSection.allCases {
            let result = destination.pasting(source,sections:[section])
            try require(result.input == destination.input && result.video == destination.video && result.geometry == destination.geometry && result.crop == destination.crop && result.rotation == destination.rotation && result.straighten == destination.straighten && result.cropX == destination.cropX && result.cropY == destination.cropY,"A selected section leaked source-specific state")
            try require(result != destination,"Selected section did not apply")
            checks += 1
        }
        let partial = AdjustmentClipboard(name:"Photo source",recipe:source,sections:[.light,.whiteBalance])
        try require(partial.recipe.lut == nil && partial.recipe.input == InputConversion() && partial.recipe.video == VideoEdit() && partial.recipe.geometry.isNeutral && partial.recipe.crop == .original,"Partial copy retained unselected LUT/source state")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("StudioTransferQA-\(UUID())"),vault = ProjectVault(root:root)
        defer { try? FileManager.default.removeItem(at:root) }
        let clip = AdjustmentClipboard(name:"Photo source",recipe:source,sections:all)
        try await vault.saveClipboard(clip)
        let loaded = try await vault.loadClipboard()
        try require(loaded?.recipe == clip.recipe && loaded?.sections == clip.sections,"Internal clipboard did not reopen with the LUT")
        let index = try await vault.load();try require(index.0.isEmpty,"Clipboard appeared as a media project")
        let before = try Data(contentsOf:root.appendingPathComponent("adjustments-clipboard.json"))
        source.exposure = -1
        try require(try Data(contentsOf:root.appendingPathComponent("adjustments-clipboard.json")) == before,"Source edit mutated the copied snapshot")
        try await vault.saveClipboard(nil);try require(try await vault.loadClipboard() == nil,"Clear clipboard failed")
        return ["passed":true,"individualSections":checks,"fullPaste":true,"sourceSettingsPreserved":true,"unselectedRetained":true,"neutralLUTClears":true,"emptyNoOp":true,"partialCopyDropsLUT":true,"persistentLUTSnapshot":true,"immutableCopy":true,"clipboardNotProject":true,"clear":true]
    }
}
#endif

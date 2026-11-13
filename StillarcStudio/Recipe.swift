import Foundation

// Portable, versioned instructions. Source pixels are never changed.
struct Recipe: Codable, Equatable, Sendable {
    var masks = [LocalMask]()
    var background:PhotoBackground? = nil
    var rawDevelopment:RawDevelopment? = nil
    var optics:PhotoOptics? = nil
    var retouch:[RetouchSpot]? = nil
    var photoHDR:Bool? = nil
    var reference:PhotoReference? = nil
    var colorWarp:ColorWarp?
    var matchGrade:MatchGrade? = nil
    var geometry = GeometrySettings()
    var videoAnimation:VideoAnimation? = nil
    var video = VideoEdit()
    var input = InputConversion()
    var lut: LUTAsset?
    var lutEnabled:Bool?
    var lutLayers:[LUTLayer]?
    var lutAmount = 1.0
    var colorWheels = ColorWheels()
    var channelMixer = ChannelMixer()
    var rgbCurves = RGBCurves()
    var selectiveColors = SelectiveColors()
    var exposure = 0.0
    var contrast = 0.0
    var highlights = 0.0
    var shadows = 0.0
    var whites = 0.0
    var blacks = 0.0
    var warmth = 0.0
    var tint = 0.0
    var saturation = 0.0
    var vibrance = 0.0
    var fade = 0.0
    var grain = 0.0
    var grainSize = 0.5
    var grainModel = 2
    var halation = 0.0
    var bloom = 0.0
    var vignette = 0.0
    var levelBlack = 0.0
    var levelWhite = 1.0
    var levelGamma = 1.0
    var levelOutputBlack = 0.0
    var levelOutputWhite = 1.0
    var dehaze = 0.0
    var texture = 0.0
    var clarity = 0.0
    var sharpen = 0.0
    var noise = 0.0
    var curveShadows = 0.0
    var curveMidtones = 0.0
    var curveHighlights = 0.0
    var straighten = 0.0
    var cropX = 0.5
    var cropY = 0.5
    var rotation = 0
    var crop = Crop.original
    var look = FilmLook.original
    var lookAmount = 1.0
    init() {}
    private enum CodingKeys: String, CodingKey { case videoAnimation, colorWarp, reference, matchGrade, background, rawDevelopment, optics, retouch, photoHDR, grainSize, grainModel, halation, levelBlack, levelWhite, levelGamma, levelOutputBlack, levelOutputWhite, masks, geometry, video, input, lut, lutEnabled, lutLayers, lutAmount, colorWheels, channelMixer, rgbCurves, selectiveColors, exposure, contrast, highlights, shadows, whites, blacks, warmth, tint, saturation, vibrance, fade, grain, bloom, vignette, dehaze, texture, clarity, sharpen, noise, curveShadows, curveMidtones, curveHighlights, straighten, cropX, cropY, rotation, crop, look, lookAmount }
    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        levelBlack = try values.decodeIfPresent(Double.self,forKey:.levelBlack) ?? 0
        levelWhite = try values.decodeIfPresent(Double.self,forKey:.levelWhite) ?? 1
        levelGamma = try values.decodeIfPresent(Double.self,forKey:.levelGamma) ?? 1
        levelOutputBlack = try values.decodeIfPresent(Double.self,forKey:.levelOutputBlack) ?? 0
        levelOutputWhite = try values.decodeIfPresent(Double.self,forKey:.levelOutputWhite) ?? 1
        masks = Array((try values.decodeIfPresent([LocalMask].self,forKey:.masks) ?? []).prefix(4)).map { $0.validated() }
        reference=try values.decodeIfPresent(PhotoReference.self,forKey:.reference)
        videoAnimation=try values.decodeIfPresent(VideoAnimation.self,forKey:.videoAnimation)?.validated()
        colorWarp=try values.decodeIfPresent(ColorWarp.self,forKey:.colorWarp)?.validated()
        matchGrade=try values.decodeIfPresent(MatchGrade.self,forKey:.matchGrade)?.validated()
        background=try values.decodeIfPresent(PhotoBackground.self,forKey:.background)
        rawDevelopment=try values.decodeIfPresent(RawDevelopment.self,forKey:.rawDevelopment)
        optics=try values.decodeIfPresent(PhotoOptics.self,forKey:.optics)
        retouch=try values.decodeIfPresent([RetouchSpot].self,forKey:.retouch).map {Array($0.prefix(32))}
        photoHDR=try values.decodeIfPresent(Bool.self,forKey:.photoHDR)
        geometry = (try values.decodeIfPresent(GeometrySettings.self,forKey:.geometry) ?? GeometrySettings()).validated()
        video = try values.decodeIfPresent(VideoEdit.self,forKey:.video) ?? VideoEdit()
        input = try values.decodeIfPresent(InputConversion.self,forKey:.input) ?? InputConversion()
        lut = try values.decodeIfPresent(LUTAsset.self,forKey:.lut)
        lutEnabled = try values.decodeIfPresent(Bool.self,forKey:.lutEnabled)
        lutLayers = try values.decodeIfPresent([LUTLayer].self,forKey:.lutLayers).map { Array($0.prefix(2)).map { $0.validated() } }
        lutAmount = try values.decodeIfPresent(Double.self,forKey:.lutAmount) ?? 1
        colorWheels = try values.decodeIfPresent(ColorWheels.self,forKey:.colorWheels) ?? colorWheels
        channelMixer = try values.decodeIfPresent(ChannelMixer.self,forKey:.channelMixer) ?? channelMixer
        rgbCurves = try values.decodeIfPresent(RGBCurves.self,forKey:.rgbCurves) ?? rgbCurves
        selectiveColors = try values.decodeIfPresent(SelectiveColors.self,forKey:.selectiveColors) ?? selectiveColors
        exposure = try values.decodeIfPresent(Double.self, forKey: .exposure) ?? exposure
        contrast = try values.decodeIfPresent(Double.self, forKey: .contrast) ?? contrast
        highlights = try values.decodeIfPresent(Double.self, forKey: .highlights) ?? highlights
        shadows = try values.decodeIfPresent(Double.self, forKey: .shadows) ?? shadows
        whites = try values.decodeIfPresent(Double.self, forKey: .whites) ?? whites
        blacks = try values.decodeIfPresent(Double.self, forKey: .blacks) ?? blacks
        warmth = try values.decodeIfPresent(Double.self, forKey: .warmth) ?? warmth
        tint = try values.decodeIfPresent(Double.self, forKey: .tint) ?? tint
        saturation = try values.decodeIfPresent(Double.self, forKey: .saturation) ?? saturation
        vibrance = try values.decodeIfPresent(Double.self, forKey: .vibrance) ?? vibrance
        fade = try values.decodeIfPresent(Double.self, forKey: .fade) ?? fade
        grain = try values.decodeIfPresent(Double.self, forKey: .grain) ?? grain
        grainSize = try values.decodeIfPresent(Double.self,forKey:.grainSize) ?? 0.5
        grainModel = try values.decodeIfPresent(Int.self,forKey:.grainModel) ?? (grain>0 ? 1 : 2)
        halation = try values.decodeIfPresent(Double.self,forKey:.halation) ?? 0
        bloom = try values.decodeIfPresent(Double.self, forKey: .bloom) ?? bloom
        vignette = try values.decodeIfPresent(Double.self, forKey: .vignette) ?? vignette
        dehaze = try values.decodeIfPresent(Double.self,forKey:.dehaze) ?? 0
        texture = try values.decodeIfPresent(Double.self,forKey:.texture) ?? 0
        clarity = try values.decodeIfPresent(Double.self,forKey:.clarity) ?? 0
        sharpen = try values.decodeIfPresent(Double.self, forKey: .sharpen) ?? sharpen
        noise = try values.decodeIfPresent(Double.self, forKey: .noise) ?? noise
        curveShadows = try values.decodeIfPresent(Double.self, forKey: .curveShadows) ?? curveShadows
        curveMidtones = try values.decodeIfPresent(Double.self, forKey: .curveMidtones) ?? curveMidtones
        curveHighlights = try values.decodeIfPresent(Double.self, forKey: .curveHighlights) ?? curveHighlights
        straighten = try values.decodeIfPresent(Double.self, forKey: .straighten) ?? straighten
        cropX = try values.decodeIfPresent(Double.self, forKey: .cropX) ?? cropX
        cropY = try values.decodeIfPresent(Double.self, forKey: .cropY) ?? cropY
        rotation = try values.decodeIfPresent(Int.self, forKey: .rotation) ?? rotation
        crop = try values.decodeIfPresent(Crop.self, forKey: .crop) ?? crop
        look = try values.decodeIfPresent(FilmLook.self, forKey: .look) ?? look
        lookAmount = try values.decodeIfPresent(Double.self, forKey: .lookAmount) ?? lookAmount
        self = validated()
    }

}
enum Crop: String, CaseIterable, Codable, Sendable {
    case free = "Free", original = "Original", square = "1:1", portrait = "4:5", landscape = "3:2", cinema = "16:9"
    var ratio: Double? {
        switch self { case .original, .free: nil; case .square: 1; case .portrait: 0.8; case .landscape: 1.5; case .cinema: 16.0 / 9 }
    }
}
enum FilmLook: String, CaseIterable, Codable, Sendable {
    case original = "Original", daylight = "Daylight", bluehour = "Blue Hour", silver = "Silver", ember = "Ember", soft = "Soft Print"
    var subtitle: String {
        switch self {
        case .original: "A clean starting point."
        case .daylight: "Warm light. Gentle contrast."
        case .bluehour: "Cool shadows with a quiet warmth."
        case .silver: "Rich, timeless black and white."
        case .ember: "Warm color with softer highlights."
        case .soft: "Lifted blacks. Subtle, faded color."
        }
    }
}
enum Tool: String, CaseIterable, Identifiable {
    case light = "Light", color = "Color", film = "Film", curves = "Curves", detail = "Detail", crop = "Crop", masks = "Masks"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .light: "sun.max"; case .color: "circle.lefthalf.filled"; case .film: "camera.filters"; case .curves: "point.topleft.down.to.point.bottomright.curvepath"; case .detail: "triangle"; case .crop: "crop.rotate";case .masks:"circle.dashed.inset.filled" }
    }
    var help: String {
        switch self {
        case .light: "Shape brightness and contrast without changing your original."
        case .color: "Balance the whole photo or refine individual color ranges."
        case .film: "Build a look with texture, soft light and a film-inspired finish."
        case .curves: "Shape brightness or individual red, green and blue tones."
        case .detail: "Texture shapes fine details, Clarity adds definition and Dehaze reduces a pale veil."
        case .masks:"Adjust a chosen area with a soft linear, radial, brush, color or luminance mask."
        case .crop: "Drag crop corners to resize; drag inside the frame to move it. Fixed ratios stay locked."
        }
    }
}
struct Project: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var sourceName: String
    var created: Date
    var modified: Date
    var recipe: Recipe
    var width: Int
    var height: Int
    var isRAW: Bool
    var organization:ProjectOrganization? = nil
    var versions:[EditVersion]? = nil
    var video: VideoDescriptor? = nil
    var isVideo:Bool { video != nil }
}
struct SavedLook: Identifiable, Codable, Sendable {
    var id = UUID()
    var name: String
    var recipe: Recipe
    var organization:LookOrganization? = nil
}
struct PresetDocument: Codable, Sendable {
    var schema = 1
    var name: String
    var recipe: Recipe
    init(name: String, recipe: Recipe) { self.name = name; self.recipe = recipe; schema = (recipe.lutEnabled == false || !(recipe.lutLayers ?? []).isEmpty || CurveChannel.allCases.contains { recipe.rgbCurves[keyPath:$0.key].nodes != nil }) ? 6 : recipe.colorWarp?.isNeutral == false ? 5 : recipe.matchGrade != nil ? 4 : (recipe.halation>0 || (recipe.grain>0 && recipe.grainModel == 2) ? 3 : (recipe.lut == nil ? 1 : 2)) }
}

extension Recipe {
    func validated() -> Recipe {
        var copy = self
        let signed: [WritableKeyPath<Recipe, Double>] = [\.dehaze, \.texture, \.clarity, \.contrast, \.highlights, \.shadows, \.whites, \.blacks, \.warmth, \.tint, \.saturation, \.vibrance, \.curveShadows, \.curveMidtones, \.curveHighlights]
        let positive: [WritableKeyPath<Recipe, Double>] = [\.grainSize, \.halation, \.fade, \.grain, \.bloom, \.vignette, \.sharpen, \.noise, \.lookAmount, \.lutAmount]
        for key in signed { copy[keyPath: key] = copy[keyPath: key].isFinite ? min(1, max(-1, copy[keyPath: key])) : 0 }
        for key in positive { copy[keyPath: key] = copy[keyPath: key].isFinite ? min(1, max(0, copy[keyPath: key])) : 0 }
        copy.lutLayers=lutLayers.map {Array($0.prefix(2)).map {$0.validated()}}
        copy.grainSize = grainSize.isFinite ? min(1,max(0,grainSize)) : 0.5
        copy.grainModel = grainModel == 1 ? 1 : 2
        copy.exposure = copy.exposure.isFinite ? min(3,max(-3,copy.exposure)) : 0
        func bounded(_ v:Double,_ low:Double,_ high:Double,_ fallback:Double) -> Double { v.isFinite ? min(high,max(low,v)) : fallback }
        copy.levelBlack = bounded(levelBlack,0,0.95,0);copy.levelWhite = bounded(levelWhite,max(0.05,copy.levelBlack+0.01),1,1)
        copy.levelGamma = bounded(levelGamma,0.2,3,1)
        copy.levelOutputBlack = bounded(levelOutputBlack,0,0.95,0);copy.levelOutputWhite = bounded(levelOutputWhite,max(0.05,copy.levelOutputBlack+0.01),1,1)
        copy.geometry = copy.geometry.validated()
        copy.cropX = copy.cropX.isFinite ? min(1,max(0,copy.cropX)) : 0.5
        copy.cropY = copy.cropY.isFinite ? min(1,max(0,copy.cropY)) : 0.5
        copy.straighten = copy.straighten.isFinite ? min(15,max(-15,copy.straighten)) : 0
        copy.matchGrade=matchGrade?.validated()
        copy.input = input.validated()
        copy.colorWheels = colorWheels.validated()
        copy.channelMixer = channelMixer.validated()
        copy.rgbCurves = rgbCurves.validated()
        copy.videoAnimation=videoAnimation?.validated()
        copy.colorWarp = colorWarp?.validated()
        copy.selectiveColors = selectiveColors.validated()
        copy.rotation = ((copy.rotation % 4) + 4) % 4
        return copy
    }
}

extension Tool {
    var valueKeys: [WritableKeyPath<Recipe, Double>] {
        switch self {
        case .light: [\.exposure, \.contrast, \.highlights, \.shadows, \.whites, \.blacks]
        case .color: [\.warmth, \.tint, \.saturation, \.vibrance]
        case .film: [\.grain, \.grainSize, \.halation, \.bloom, \.fade, \.vignette]
        case .curves: [\.levelBlack, \.levelWhite, \.levelGamma, \.levelOutputBlack, \.levelOutputWhite, \.curveShadows, \.curveMidtones, \.curveHighlights]
        case .detail: [\.dehaze, \.texture, \.clarity, \.sharpen, \.noise]
        case .masks: []
        case .crop: [\.straighten]
        }
    }
}
extension Recipe {
    func hasAdjustments(in tool: Tool) -> Bool {
        if videoAnimation?.tracks.contains(where:{$0.enabled && !$0.points.isEmpty && ((tool == .light && $0.target == .exposure) || (tool == .film && ($0.target == .look || $0.target == .lut)))}) == true {return true}
        if tool == .masks { return !masks.isEmpty }
        if tool == .detail && (rawDevelopment != nil || optics.map {$0 != PhotoOptics()} == true || retouch?.isEmpty == false || photoHDR == true) {return true}
        let neutral = Recipe()
        if tool.valueKeys.contains(where: { key in if tool == .film && key == \.grainSize && grain == 0 { return false };return abs(self[keyPath:key]-neutral[keyPath:key])>0.000001 }) { return true }
        if tool == .curves && !rgbCurves.isNeutral { return true }
        if tool == .color && (colorWarp?.isNeutral == false || !selectiveColors.isNeutral || !colorWheels.isNeutral || !channelMixer.isNeutral || matchGrade?.isNeutral == false) { return true }
        if tool == .film { return (lutLayers ?? []).contains { $0.enabled && $0.amount > 0 } || (look != .original && lookAmount > 0.000001) || (lut != nil && lutEnabled != false && lutAmount > 0.000001) }
        if tool == .crop { return crop != .original || rotation % 4 != 0 || !geometry.isNeutral }
        return false
    }
    mutating func reset(_ tool: Tool) {
        if tool == .masks { masks = [];background=nil;return }
        if tool == .detail {rawDevelopment=nil;optics=nil;retouch=nil;photoHDR=nil}
        let neutral = Recipe()
        for key in tool.valueKeys { self[keyPath: key] = neutral[keyPath: key] }
        if tool == .curves { rgbCurves = RGBCurves() }
        if tool == .light {videoAnimation?.tracks.removeAll {$0.target == .exposure}}
        if tool == .film {videoAnimation?.tracks.removeAll {$0.target == .look || $0.target == .lut}}
        if tool == .masks {videoAnimation?.tracks.removeAll {if case .mask = $0.target {return true};return false}}
        if tool == .color { colorWarp=nil;matchGrade=nil;selectiveColors = SelectiveColors(); colorWheels = ColorWheels(); channelMixer = ChannelMixer() }
        if tool == .film { grainModel = 2;look = .original; lookAmount = 1; lutEnabled = nil; lutLayers = nil; lut = nil; lutAmount = 1 }
        if tool == .crop { geometry = GeometrySettings();crop = .original; rotation = 0; straighten = 0; cropX = 0.5; cropY = 0.5 }
    }
    mutating func copyFraming(from source: Recipe) {
        geometry = source.geometry;crop = source.crop; rotation = source.rotation; straighten = source.straighten; cropX = source.cropX; cropY = source.cropY
    }
    var colorPreset: Recipe { var copy = self; copy.reset(.crop); copy.input = InputConversion(); copy.video = VideoEdit();copy.masks = [];copy.videoAnimation=nil;copy.reference=nil;copy.background=nil;copy.rawDevelopment=nil;copy.optics=nil;copy.retouch=nil;copy.photoHDR=nil; return copy }
}

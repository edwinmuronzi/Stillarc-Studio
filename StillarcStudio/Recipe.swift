import Foundation

// Portable, versioned instructions. Source pixels are never changed.
struct Recipe: Codable, Equatable, Sendable {
    var video = VideoEdit()
    var input = InputConversion()
    var lut: LUTAsset?
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
    var bloom = 0.0
    var vignette = 0.0
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
    private enum CodingKeys: String, CodingKey { case video, input, lut, lutAmount, colorWheels, channelMixer, rgbCurves, selectiveColors, exposure, contrast, highlights, shadows, whites, blacks, warmth, tint, saturation, vibrance, fade, grain, bloom, vignette, sharpen, noise, curveShadows, curveMidtones, curveHighlights, straighten, cropX, cropY, rotation, crop, look, lookAmount }
    init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        video = try values.decodeIfPresent(VideoEdit.self,forKey:.video) ?? VideoEdit()
        input = try values.decodeIfPresent(InputConversion.self,forKey:.input) ?? InputConversion()
        lut = try values.decodeIfPresent(LUTAsset.self,forKey:.lut)
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
        bloom = try values.decodeIfPresent(Double.self, forKey: .bloom) ?? bloom
        vignette = try values.decodeIfPresent(Double.self, forKey: .vignette) ?? vignette
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
    case original = "Original", square = "1:1", portrait = "4:5", landscape = "3:2", cinema = "16:9"
    var ratio: Double? {
        switch self { case .original: nil; case .square: 1; case .portrait: 0.8; case .landscape: 1.5; case .cinema: 16.0 / 9 }
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
    case light = "Light", color = "Color", film = "Film", curves = "Curves", detail = "Detail", crop = "Crop"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .light: "sun.max"; case .color: "circle.lefthalf.filled"; case .film: "camera.filters"; case .curves: "point.topleft.down.to.point.bottomright.curvepath"; case .detail: "triangle"; case .crop: "crop.rotate" }
    }
    var help: String {
        switch self {
        case .light: "Shape brightness and contrast without changing your original."
        case .color: "Balance the whole photo or refine individual color ranges."
        case .film: "Build a look with texture, soft light and a film-inspired finish."
        case .curves: "Shape brightness or individual red, green and blue tones."
        case .detail: "Bring out edges or soften visible digital noise."
        case .crop: "Drag the photo to reframe it. Straighten a horizon without leaving black corners."
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
    var video: VideoDescriptor? = nil
    var isVideo:Bool { video != nil }
}
struct SavedLook: Identifiable, Codable, Sendable {
    var id = UUID()
    var name: String
    var recipe: Recipe
}
struct PresetDocument: Codable {
    var schema = 1
    var name: String
    var recipe: Recipe
    init(name: String, recipe: Recipe) { self.name = name; self.recipe = recipe; schema = recipe.lut == nil ? 1 : 2 }
}

extension Recipe {
    func validated() -> Recipe {
        var copy = self
        let signed: [WritableKeyPath<Recipe, Double>] = [\.contrast, \.highlights, \.shadows, \.whites, \.blacks, \.warmth, \.tint, \.saturation, \.vibrance, \.curveShadows, \.curveMidtones, \.curveHighlights]
        let positive: [WritableKeyPath<Recipe, Double>] = [\.fade, \.grain, \.bloom, \.vignette, \.sharpen, \.noise, \.lookAmount, \.lutAmount]
        for key in signed { copy[keyPath: key] = copy[keyPath: key].isFinite ? min(1, max(-1, copy[keyPath: key])) : 0 }
        for key in positive { copy[keyPath: key] = copy[keyPath: key].isFinite ? min(1, max(0, copy[keyPath: key])) : 0 }
        copy.exposure = copy.exposure.isFinite ? min(3,max(-3,copy.exposure)) : 0
        copy.cropX = copy.cropX.isFinite ? min(1,max(0,copy.cropX)) : 0.5
        copy.cropY = copy.cropY.isFinite ? min(1,max(0,copy.cropY)) : 0.5
        copy.straighten = copy.straighten.isFinite ? min(15,max(-15,copy.straighten)) : 0
        copy.input = input.validated()
        copy.colorWheels = colorWheels.validated()
        copy.channelMixer = channelMixer.validated()
        copy.rgbCurves = rgbCurves.validated()
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
        case .film: [\.grain, \.bloom, \.fade, \.vignette]
        case .curves: [\.curveShadows, \.curveMidtones, \.curveHighlights]
        case .detail: [\.sharpen, \.noise]
        case .crop: [\.straighten]
        }
    }
}
extension Recipe {
    func hasAdjustments(in tool: Tool) -> Bool {
        if tool.valueKeys.contains(where: { abs(self[keyPath: $0]) > 0.000001 }) { return true }
        if tool == .curves && !rgbCurves.isNeutral { return true }
        if tool == .color && (!selectiveColors.isNeutral || !colorWheels.isNeutral || !channelMixer.isNeutral) { return true }
        if tool == .film { return (look != .original && lookAmount > 0.000001) || (lut != nil && lutAmount > 0.000001) }
        if tool == .crop { return crop != .original || rotation % 4 != 0 }
        return false
    }
    mutating func reset(_ tool: Tool) {
        let neutral = Recipe()
        for key in tool.valueKeys { self[keyPath: key] = neutral[keyPath: key] }
        if tool == .curves { rgbCurves = RGBCurves() }
        if tool == .color { selectiveColors = SelectiveColors(); colorWheels = ColorWheels(); channelMixer = ChannelMixer() }
        if tool == .film { look = .original; lookAmount = 1; lut = nil; lutAmount = 1 }
        if tool == .crop { crop = .original; rotation = 0; straighten = 0; cropX = 0.5; cropY = 0.5 }
    }
    mutating func copyFraming(from source: Recipe) {
        crop = source.crop; rotation = source.rotation; straighten = source.straighten; cropX = source.cropX; cropY = source.cropY
    }
    var colorPreset: Recipe { var copy = self; copy.reset(.crop); copy.input = InputConversion(); copy.video = VideoEdit(); return copy }
}

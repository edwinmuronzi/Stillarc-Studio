import Foundation

enum AdjustmentSection:String,CaseIterable,Codable,Identifiable,Sendable {
    case light,whiteBalance,color,curves,wheels,mixer,look,lut,texture,detail
    var id:String { rawValue }
    var title:String { switch self { case .light:"Light";case .whiteBalance:"White balance";case .color:"Color & color mix";case .curves:"Curves";case .wheels:"Color wheels";case .mixer:"Channel mixer";case .look:"Built-in look";case .lut:"LUT";case .texture:"Film texture";case .detail:"Detail" } }
    var help:String { switch self { case .light:"Exposure, contrast and bright/dark tones";case .whiteBalance:"Warmth and tint";case .color:"Saturation, vibrance and individual color ranges";case .curves:"Levels, Master/RGB curves and tone shaping";case .wheels:"Shadows, midtones, highlights and global tint";case .mixer:"Channel mixing, offsets and monochrome";case .look:"Creative look and its strength";case .lut:"The LUT itself and its strength; Off clears the destination LUT";case .texture:"Grain, bloom, fade and vignette";case .detail:"Dehaze, texture, clarity, sharpening and noise reduction" } }
}
struct AdjustmentClipboard:Codable,Sendable {
    var schema = 1
    var sourceName:String
    var copied = Date()
    var sections:[AdjustmentSection]
    var recipe:Recipe
    init(name:String,recipe:Recipe,sections:Set<AdjustmentSection>) {
        sourceName = String(name.prefix(160));self.sections = AdjustmentSection.allCases.filter { sections.contains($0) }
        self.recipe = Recipe().pasting(recipe,sections:sections)
    }
}
extension Recipe {
    func pasting(_ source:Recipe,sections:Set<AdjustmentSection>) -> Recipe {
        var result = self
        for section in sections {
            switch section {
            case .light: for key in Tool.light.valueKeys { result[keyPath:key] = source[keyPath:key] }
            case .whiteBalance: result.warmth = source.warmth;result.tint = source.tint
            case .color: result.saturation = source.saturation;result.vibrance = source.vibrance;result.selectiveColors = source.selectiveColors
            case .curves: result.rgbCurves = source.rgbCurves;for key in Tool.curves.valueKeys { result[keyPath:key] = source[keyPath:key] }
            case .wheels: result.colorWheels = source.colorWheels
            case .mixer: result.channelMixer = source.channelMixer
            case .look: result.look = source.look;result.lookAmount = source.lookAmount
            case .lut: result.lut = source.lut;result.lutAmount = source.lutAmount
            case .texture: for key in Tool.film.valueKeys { result[keyPath:key] = source[keyPath:key] }
            case .detail: for key in Tool.detail.valueKeys { result[keyPath:key] = source[keyPath:key] }
            }
        }
        return result
    }
}

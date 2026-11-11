import Foundation

// Portable, versioned instructions. Source pixels are never changed.
struct Recipe: Codable, Equatable, Sendable {
    var exposure = 0.0
    var contrast = 0.0
    var highlights = 0.0
    var shadows = 0.0
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
    var rotation = 0
    var crop = Crop.original
    var look = FilmLook.original
    var lookAmount = 1.0
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
        case .color: "Warm the light, balance a color cast, or make colors richer."
        case .film: "Build a look with texture, soft light and a film-inspired finish."
        case .curves: "Fine-tune dark, middle and bright tones independently."
        case .detail: "Bring out edges or soften visible digital noise."
        case .crop: "Choose a centered frame or rotate the photograph."
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
}

extension Recipe {
    func validated() -> Recipe {
        var copy = self
        let signed: [WritableKeyPath<Recipe, Double>] = [\.contrast, \.highlights, \.shadows, \.warmth, \.tint, \.saturation, \.vibrance, \.curveShadows, \.curveMidtones, \.curveHighlights]
        let positive: [WritableKeyPath<Recipe, Double>] = [\.fade, \.grain, \.bloom, \.vignette, \.sharpen, \.noise, \.lookAmount]
        for key in signed { copy[keyPath: key] = copy[keyPath: key].isFinite ? min(1, max(-1, copy[keyPath: key])) : 0 }
        for key in positive { copy[keyPath: key] = copy[keyPath: key].isFinite ? min(1, max(0, copy[keyPath: key])) : 0 }
        copy.exposure = copy.exposure.isFinite ? min(3,max(-3,copy.exposure)) : 0
        copy.rotation = ((copy.rotation % 4) + 4) % 4
        return copy
    }
}

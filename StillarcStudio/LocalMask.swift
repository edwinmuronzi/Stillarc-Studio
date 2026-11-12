import Foundation

enum LocalMaskKind:String,Codable,CaseIterable,Identifiable,Sendable { case linear = "Linear",radial = "Radial",brush = "Brush",color = "Color",luminance = "Luminance",subject = "Subject",sky = "Sky";var id:String { rawValue };var isAutomatic:Bool { self == .subject || self == .sky } }
enum MaskCombination:String,Codable,CaseIterable,Identifiable,Sendable {
    case independent = "Separate",intersect = "Intersect",add = "Add",subtract = "Subtract"
    var id:String { rawValue }
}
struct LocalMask:Identifiable,Codable,Equatable,Sendable {
    var id = UUID()
    var kind:LocalMaskKind
    var region:MaskRegion? = nil
    var cutout:Bool? = nil
    var title:String {region?.rawValue ?? kind.rawValue}
    var brush:BrushDrawing? = nil
    var selection:MaskSelection? = nil
    var combination:MaskCombination? = nil
    var motion:MaskMotion? = nil
    var automatic:AutomaticMask? = nil
    var refinement:AutomaticRefinement? = nil
    var isRange:Bool { kind == .color || kind == .luminance }
    var enabled = true
    var inverted = false
    var centerX = 0.5
    var centerY = 0.5
    var width = 0.35
    var height = 0.35
    var angle = 0.0
    var feather = 0.6
    var amount = 1.0
    var exposure = 0.0
    var warmth = 0.0
    var saturation = 0.0
    var contrast = 0.0
    var localTint:Double? = nil
    var localHighlights:Double? = nil
    var localShadows:Double? = nil
    var localClarity:Double? = nil
    var localBlur:Double? = nil
    var tint:Double {get {localTint ?? 0} set {localTint=newValue}}
    var highlights:Double {get {localHighlights ?? 0} set {localHighlights=newValue}}
    var shadows:Double {get {localShadows ?? 0} set {localShadows=newValue}}
    var clarity:Double {get {localClarity ?? 0} set {localClarity=newValue}}
    var blur:Double {get {localBlur ?? 0} set {localBlur=newValue}}
    init(kind:LocalMaskKind) { self.kind = kind;angle = kind == .linear ? 90 : 0;if kind == .brush { width = 0.06;brush = BrushDrawing() };if isRange { selection = MaskSelection() } }
    var hasEffect:Bool {enabled && amount>0 && (cutout == true || hasColorEffect)}
    var hasColorEffect:Bool { enabled && amount>0 && (abs(exposure)>0.000001 || abs(warmth)>0.000001 || abs(saturation)>0.000001 || abs(contrast)>0.000001 || abs(tint)>0.000001 || abs(highlights)>0.000001 || abs(shadows)>0.000001 || abs(clarity)>0.000001 || blur>0.000001) }
    func validated() -> Self {
        var r = self
        func limit(_ v:Double,_ range:ClosedRange<Double>,_ fallback:Double) -> Double { v.isFinite ? min(range.upperBound,max(range.lowerBound,v)) : fallback }
        r.centerX = limit(centerX,0...1,0.5);r.centerY = limit(centerY,0...1,0.5)
        r.width = limit(width,kind == .brush ? 0.005...0.3 : 0.03...1,kind == .brush ? 0.06 : 0.35);r.height = limit(height,0.03...1,0.35)
        r.angle = limit(angle,-180...180,0);r.feather = limit(feather,0.02...1,0.6);r.amount = limit(amount,0...1,1)
        if let refinement { r.refinement = refinement.validated() }
        if isRange { r.selection = (selection ?? MaskSelection()).validated() }
        r.exposure = limit(exposure,-3...3,0);r.warmth = limit(warmth,-1...1,0);r.saturation = limit(saturation,-1...1,0);r.contrast = limit(contrast,-1...1,0)
        if localTint != nil {r.tint=limit(tint,-1...1,0)};if localHighlights != nil {r.highlights=limit(highlights,-1...1,0)};if localShadows != nil {r.shadows=limit(shadows,-1...1,0)};if localClarity != nil {r.clarity=limit(clarity,-1...1,0)};if localBlur != nil {r.blur=limit(blur,0...1,0)}
        return r
    }
}

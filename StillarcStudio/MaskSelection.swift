import Foundation

/// Source-specific selection, measured after global grading and before all local layers.
struct MaskSelection: Codable, Equatable, Sendable {
    var hue = 0.0
    var tolerance = 30.0
    var minimumSaturation = 0.1
    var lower = 0.25
    var upper = 0.75
    var softness = 0.1
    func validated() -> Self {
        var r = self
        func clamp(_ x:Double,_ a:Double,_ b:Double,_ fallback:Double) -> Double { x.isFinite ? min(b,max(a,x)) : fallback }
        r.hue = clamp(hue,0,360,0);r.tolerance = clamp(tolerance,1,180,30)
        r.minimumSaturation = clamp(minimumSaturation,0,1,0.1)
        let a = clamp(lower,0,1,0.25),b = clamp(upper,0,1,0.75)
        r.lower = min(a,b);r.upper = max(a,b);r.softness = clamp(softness,0.005,0.5,0.1)
        return r
    }
}

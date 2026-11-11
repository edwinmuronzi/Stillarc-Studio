import Foundation

enum LocalMaskKind:String,Codable,CaseIterable,Identifiable,Sendable { case linear = "Linear",radial = "Radial",brush = "Brush";var id:String { rawValue } }
struct LocalMask:Identifiable,Codable,Equatable,Sendable {
    var id = UUID()
    var kind:LocalMaskKind
    var brush:BrushDrawing? = nil
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
    init(kind:LocalMaskKind) { self.kind = kind;angle = kind == .linear ? 90 : 0;if kind == .brush { width = 0.06;brush = BrushDrawing() } }
    var hasEffect:Bool { enabled && amount>0 && (abs(exposure)>0.000001 || abs(warmth)>0.000001 || abs(saturation)>0.000001 || abs(contrast)>0.000001) }
    func validated() -> Self {
        var r = self
        func limit(_ v:Double,_ range:ClosedRange<Double>,_ fallback:Double) -> Double { v.isFinite ? min(range.upperBound,max(range.lowerBound,v)) : fallback }
        r.centerX = limit(centerX,0...1,0.5);r.centerY = limit(centerY,0...1,0.5)
        r.width = limit(width,kind == .brush ? 0.005...0.3 : 0.03...1,kind == .brush ? 0.06 : 0.35);r.height = limit(height,0.03...1,0.35)
        r.angle = limit(angle,-180...180,0);r.feather = limit(feather,0.02...1,0.6);r.amount = limit(amount,0...1,1)
        r.exposure = limit(exposure,-3...3,0);r.warmth = limit(warmth,-1...1,0);r.saturation = limit(saturation,-1...1,0);r.contrast = limit(contrast,-1...1,0)
        return r
    }
}

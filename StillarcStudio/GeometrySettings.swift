import Foundation

struct GeometrySettings:Codable,Equatable,Sendable {
    var width = 1.0
    var height = 1.0
    var flipHorizontal = false
    var flipVertical = false
    var horizontal = 0.0
    var vertical = 0.0
    var isNeutral:Bool { self == Self() }
    func validated() -> Self {
        var r = self
        r.width = width.isFinite ? min(1,max(0.1,width)) : 1
        r.height = height.isFinite ? min(1,max(0.1,height)) : 1
        r.horizontal = horizontal.isFinite ? min(0.3,max(-0.3,horizontal)) : 0
        r.vertical = vertical.isFinite ? min(0.3,max(-0.3,vertical)) : 0
        return r
    }
}

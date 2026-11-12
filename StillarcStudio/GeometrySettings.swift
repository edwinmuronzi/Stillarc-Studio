import Foundation

struct GeometrySettings:Codable,Equatable,Sendable {
    var cropScale = 1.0
    var width = 1.0
    var height = 1.0
    var flipHorizontal = false
    var flipVertical = false
    var lensDistortion = 0.0
    var horizontal = 0.0
    var vertical = 0.0
    var isNeutral:Bool { self == Self() }
    func validated() -> Self {
        var r = self
        r.cropScale = cropScale.isFinite ? min(1,max(0.1,cropScale)) : 1
        r.width = width.isFinite ? min(1,max(0.1,width)) : 1
        r.height = height.isFinite ? min(1,max(0.1,height)) : 1
        r.lensDistortion = lensDistortion.isFinite ? min(0.25,max(-0.25,lensDistortion)) : 0
        r.horizontal = horizontal.isFinite ? min(0.3,max(-0.3,horizontal)) : 0
        r.vertical = vertical.isFinite ? min(0.3,max(-0.3,vertical)) : 0
        return r
    }
}

extension GeometrySettings {
    init(from decoder:Decoder) throws {
        self.init();let c = try decoder.container(keyedBy:CodingKeys.self)
        cropScale = try c.decodeIfPresent(Double.self,forKey:.cropScale) ?? 1
        width = try c.decodeIfPresent(Double.self,forKey:.width) ?? 1;height = try c.decodeIfPresent(Double.self,forKey:.height) ?? 1
        flipHorizontal = try c.decodeIfPresent(Bool.self,forKey:.flipHorizontal) ?? false;flipVertical = try c.decodeIfPresent(Bool.self,forKey:.flipVertical) ?? false
        lensDistortion = try c.decodeIfPresent(Double.self,forKey:.lensDistortion) ?? 0
        horizontal = try c.decodeIfPresent(Double.self,forKey:.horizontal) ?? 0;vertical = try c.decodeIfPresent(Double.self,forKey:.vertical) ?? 0
        self = validated()
    }
}

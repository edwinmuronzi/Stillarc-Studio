import Foundation

struct MaskMotionPoint:Codable,Equatable,Sendable {
    var time:Double
    var x:Double
    var y:Double
}
struct MaskMotion:Codable,Equatable,Sendable {
    var framing:String
    var start:Double
    var end:Double
    var points:[MaskMotionPoint]
    struct Frame:Sendable { var time:Double;var framing:String }
    @TaskLocal static var frame:Frame?
    static func signature(_ r:Recipe) -> String {
        let g = r.geometry
        let suffix = (g.cropScale == 1 ? "" : ":cropScale=\(g.cropScale)")+(g.lensDistortion == 0 ? "" : ":lens=\(g.lensDistortion)")
        return r.crop.rawValue + ":" + [Double(r.rotation),r.straighten,r.cropX,r.cropY,g.width,g.height,g.flipHorizontal ? 1 : 0,g.flipVertical ? 1 : 0,g.horizontal,g.vertical].map { String($0) }.joined(separator:",") + suffix
    }
    var isValid:Bool {
        start.isFinite && end.isFinite && end>start && !points.isEmpty && points.count<=1802 && points.allSatisfy { $0.time.isFinite && $0.x.isFinite && $0.y.isFinite && abs($0.x)<=16 && abs($0.y)<=16 && $0.time>=start-0.001 && $0.time<=end+0.001 } && zip(points,points.dropFirst()).allSatisfy { $0.time < $1.time }
    }
    func offset(at time:Double) -> (x:Double,y:Double) {
        guard time.isFinite,let first = points.first,let last = points.last else { return (0,0) }
        if time<=first.time { return (first.x,first.y) }
        if time>=last.time { return (last.x,last.y) }
        var low = 0,high = points.count-1
        while high-low>1 { let mid = (low+high)/2;if points[mid].time<=time { low = mid } else { high = mid } }
        let a = points[low],b = points[high],f = (time-a.time)/(b.time-a.time)
        return (a.x+(b.x-a.x)*f,a.y+(b.y-a.y)*f)
    }
    func matches(_ recipe:Recipe,duration:Double) -> Bool {
        let range = recipe.video.range(duration:duration)
        return isValid && framing == Self.signature(recipe) && range.lowerBound>=start-0.002 && range.upperBound<=end+0.002
    }
    static func validateExport(_ recipe:Recipe,duration:Double) throws {
        for index in MaskEngine.requiredIndices(recipe.masks) {
            guard let track = recipe.masks[index].motion else { continue }
            guard track.matches(recipe,duration:duration) else {
                throw NSError(domain:"MaskTracking",code:1,userInfo:[NSLocalizedDescriptionKey:"A mask track no longer matches this crop or kept clip. Track it again or clear its tracking before exporting."])
            }
        }
    }
}

extension MaskMotion {
    init(from decoder:Decoder) throws {
        let c = try decoder.container(keyedBy:CodingKeys.self)
        framing = try c.decode(String.self,forKey:.framing);start = try c.decode(Double.self,forKey:.start);end = try c.decode(Double.self,forKey:.end);points = try c.decode([MaskMotionPoint].self,forKey:.points)
        if !isValid { points = [] }
    }
}

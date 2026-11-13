import Foundation
import CoreGraphics

struct MaskMotionPoint:Codable,Equatable,Sendable {
    var time:Double
    var x:Double
    var y:Double
    var scale:Double? = nil
    var rotation:Double? = nil
}
enum MaskCorrectionBlend:String,Codable,CaseIterable,Sendable {
    case linear, smooth, hold
    var title:String {switch self {case .linear:"Linear";case .smooth:"Smooth";case .hold:"Hold"}}
    func fraction(_ value:Double)->Double {
        let t=min(1,max(0,value))
        switch self {case .linear:return t;case .smooth:return t*t*(3-2*t);case .hold:return 0}
    }
}
struct MaskMotion:Codable,Equatable,Sendable {
    var framing:String
    var start:Double
    var end:Double
    var points:[MaskMotionPoint]
    var recoveryTime:Double? = nil
    var corrections:[MaskMotionPoint]? = nil
    var correctionBlend:MaskCorrectionBlend? = nil
    var pivotX:Double? = nil
    var pivotY:Double? = nil
    var sourceWidth:Double? = nil
    var sourceHeight:Double? = nil
    struct Frame:Sendable,Equatable { var time:Double;var framing:String }
    @TaskLocal static var frame:Frame?
    static func signature(_ r:Recipe) -> String {
        let g = r.geometry
        let suffix = (g.cropScale == 1 ? "" : ":cropScale=\(g.cropScale)")+(g.lensDistortion == 0 ? "" : ":lens=\(g.lensDistortion)")
        return r.crop.rawValue + ":" + [Double(r.rotation),r.straighten,r.cropX,r.cropY,g.width,g.height,g.flipHorizontal ? 1 : 0,g.flipVertical ? 1 : 0,g.horizontal,g.vertical].map { String($0) }.joined(separator:",") + suffix + (r.rawDevelopment?.lensProfile.map {":rawLens=\($0)"} ?? "")
    }
    var isValid:Bool {
        (recoveryTime == nil || (recoveryTime!.isFinite && recoveryTime!>=start && recoveryTime!<=end)) && validPivot && validSource && start.isFinite && end.isFinite && end>start && !points.isEmpty && points.count<=1802 && points.allSatisfy { $0.time.isFinite && $0.x.isFinite && $0.y.isFinite && abs($0.x)<=16 && abs($0.y)<=16 && $0.time>=start-0.001 && $0.time<=end+0.001 && ($0.scale == nil || ($0.scale!.isFinite && (0.25...4).contains($0.scale!))) && ($0.rotation == nil || ($0.rotation!.isFinite && abs($0.rotation!)<=3600)) } && zip(points,points.dropFirst()).allSatisfy { $0.time < $1.time }
    }
    private var validPivot:Bool {
        [pivotX,pivotY].allSatisfy {$0 == nil || ($0!.isFinite && abs($0!)<=64)}
    }
    private var validSource:Bool {
        if sourceWidth == nil && sourceHeight == nil {return true}
        guard let w=sourceWidth,let h=sourceHeight else {return false}
        return w.isFinite && h.isFinite && w>0 && h>0 && w<=32768 && h<=32768
    }
    func pose(at time:Double)->(scale:Double,rotation:Double) {
        let measured=Self.pose(points,at:time,blend:.linear),manual=manualPose(at:time)
        return (measured.scale*manual.scale,measured.rotation+manual.rotation)
    }
    func manualPose(at time:Double)->(scale:Double,rotation:Double) {Self.pose(corrections ?? [],at:time,blend:correctionBlend ?? .linear)}
    private static func pose(_ values:[MaskMotionPoint],at time:Double,blend:MaskCorrectionBlend)->(scale:Double,rotation:Double) {
        guard time.isFinite,let first=values.first,let last=values.last else {return (1,0)}
        func result(_ p:MaskMotionPoint)->(Double,Double) {(p.scale ?? 1,p.rotation ?? 0)}
        if time<=first.time {return result(first)};if time>=last.time {return result(last)}
        var low=0,high=values.count-1
        while high-low>1 {let mid=(low+high)/2;if values[mid].time<=time {low=mid} else {high=mid}}
        let a=values[low],b=values[high],f=blend.fraction((time-a.time)/(b.time-a.time))
        return ((a.scale ?? 1)+((b.scale ?? 1)-(a.scale ?? 1))*f,(a.rotation ?? 0)+((b.rotation ?? 0)-(a.rotation ?? 0))*f)
    }
    func affine(at time:Double,extent:CGRect,center:CGPoint)->CGAffineTransform {
        let offset=offset(at:time),pose=pose(at:time),dx=offset.x*extent.width,dy = -offset.y*extent.height
        guard validPivot,pose.scale.isFinite,(0.0625...16).contains(pose.scale),pose.rotation.isFinite,abs(pose.rotation)<=3780,dx.isFinite,dy.isFinite else {return .identity}
        if pose.scale==1 && pose.rotation==0 {return .init(translationX:dx,y:dy)}
        let x=extent.minX+extent.width*(pivotX ?? center.x),y=extent.minY+extent.height*(1-(pivotY ?? center.y))
        let angle=pose.rotation * .pi/180,a=pose.scale*cos(angle),b = -pose.scale*sin(angle),c=pose.scale*sin(angle),d=a
        return .init(a:a,b:b,c:c,d:d,tx:x+dx-a*x-c*y,ty:y+dy-b*x-d*y)
    }
    func offset(at time:Double) -> (x:Double,y:Double) {
        let base = baseOffset(at:time), correction = correction(at:time)
        return (base.x+correction.x,base.y+correction.y)
    }
    func correction(at time:Double) -> (x:Double,y:Double) {
        Self.interpolate(corrections ?? [],at:time,blend:correctionBlend ?? .linear)
    }
    func baseOffset(at time:Double) -> (x:Double,y:Double) { Self.interpolate(points,at:time) }
    private static func interpolate(_ points:[MaskMotionPoint],at time:Double,blend:MaskCorrectionBlend = .linear) -> (x:Double,y:Double) {
        guard time.isFinite,let first = points.first,let last = points.last else { return (0,0) }
        if time<=first.time { return (first.x,first.y) }
        if time>=last.time { return (last.x,last.y) }
        var low = 0,high = points.count-1
        while high-low>1 { let mid = (low+high)/2;if points[mid].time<=time { low = mid } else { high = mid } }
        let a = points[low],b = points[high],f = blend.fraction((time-a.time)/(b.time-a.time))
        return (a.x+(b.x-a.x)*f,a.y+(b.y-a.y)*f)
    }
    // Corrections are independent of the measured path, so clearing them restores the analysis exactly.
    var validCorrections:Bool {
        guard let corrections else {return true}
        return corrections.count<=32 && corrections.allSatisfy {$0.time.isFinite && $0.time>=start && $0.time<=end && $0.x.isFinite && $0.y.isFinite && abs($0.x)<=16 && abs($0.y)<=16 && ($0.scale == nil || ($0.scale!.isFinite && (0.25...4).contains($0.scale!))) && ($0.rotation == nil || ($0.rotation!.isFinite && abs($0.rotation!)<=180))} && zip(corrections,corrections.dropFirst()).allSatisfy {$0.time<$1.time}
    }
    mutating func setCorrection(time:Double,x:Double,y:Double,tolerance:Double,scale:Double? = nil,rotation:Double? = nil) {
        guard time.isFinite,x.isFinite,y.isFinite,tolerance.isFinite,tolerance>=0,(scale?.isFinite ?? true),(rotation?.isFinite ?? true) else {return}
        let t=min(end,max(start,time))
        let current=manualPose(at:t),s=min(4,max(0.25,scale ?? current.scale)),r=min(180,max(-180,rotation ?? current.rotation))
        let point=MaskMotionPoint(time:t,x:min(16,max(-16,x)),y:min(16,max(-16,y)),scale:s==1 ? nil:s,rotation:r==0 ? nil:r)
        var values=corrections ?? []
        if values.isEmpty && t>start+tolerance {values.append(.init(time:start,x:0,y:0))}
        if let i=values.firstIndex(where:{abs($0.time-t)<=tolerance}) {values[i] = point}
        else if values.count<32 {values.append(point)}
        corrections=values.sorted {$0.time<$1.time}
    }
    func matches(_ recipe:Recipe,duration:Double) -> Bool {
        let range = recipe.video.range(duration:duration)
        return isValid && validCorrections && framing == Self.signature(recipe) && range.lowerBound>=start-0.002 && range.upperBound<=end+0.002
    }
    static func validateExport(_ recipe:Recipe,duration:Double) throws {
        for index in MaskEngine.requiredIndices(recipe.masks) {
            if let matte=recipe.masks[index].automatic?.temporal {
                guard matte.matches(recipe),abs(matte.sourceDuration-duration)<0.003,recipe.masks[index].motion==nil else {throw PeopleVideoMatteError.invalid}
            }
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
        recoveryTime=try c.decodeIfPresent(Double.self,forKey:.recoveryTime)
        pivotX=try c.decodeIfPresent(Double.self,forKey:.pivotX);pivotY=try c.decodeIfPresent(Double.self,forKey:.pivotY)
        sourceWidth=try c.decodeIfPresent(Double.self,forKey:.sourceWidth);sourceHeight=try c.decodeIfPresent(Double.self,forKey:.sourceHeight)
        correctionBlend = try c.decodeIfPresent(MaskCorrectionBlend.self,forKey:.correctionBlend)
        corrections = try c.decodeIfPresent([MaskMotionPoint].self,forKey:.corrections)
        if !isValid { points = [] }
        if !validCorrections { corrections = nil }
    }
}

enum PeopleVideoMatteError:LocalizedError {case invalid;var errorDescription:String? {"Rebuild the People video matte for this input/kept clip and remove any additional rigid track before exporting."}}

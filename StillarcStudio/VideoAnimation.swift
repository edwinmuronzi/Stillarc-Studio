import Foundation
import Observation

// Source-time scalar controls; no per-frame inference, bitmap generation or extra render pass.
enum AnimationTarget:Codable,Hashable,Sendable,Identifiable {
    case exposure,look,lut,mask(UUID)
    var id:String {switch self {case .exposure:"exposure";case .look:"look";case .lut:"lut";case .mask(let id):"mask-"+id.uuidString}}
    var neutral:Double {self == .exposure ? 0:1}
    var range:ClosedRange<Double> {self == .exposure ? -3...3:0...1}
}
enum AnimationBlend:String,Codable,CaseIterable,Sendable {case smooth="Smooth",linear="Linear"}
struct AnimationPoint:Codable,Equatable,Identifiable,Sendable {var id=UUID();var time:Double;var value:Double}
struct AnimationTrack:Codable,Equatable,Identifiable,Sendable {
    var id=UUID()
    var target:AnimationTarget
    var enabled=true
    var blend=AnimationBlend.smooth
    var points:[AnimationPoint]=[]
    func value(at time:Double)->Double {
        guard enabled,time.isFinite,let first=points.first,let last=points.last else {return target.neutral}
        if time<=first.time {return first.value};if time>=last.time {return last.value}
        var lower=0,upper=points.count-1
        while upper-lower>1 {let mid=(lower+upper)/2;if points[mid].time<=time {lower=mid} else {upper=mid}}
        let a=points[lower],b=points[upper],raw=min(1,max(0,(time-a.time)/max(0.000001,b.time-a.time)))
        let t=blend == .smooth ? raw*raw*(3-2*raw):raw
        return a.value+(b.value-a.value)*t
    }
    func validated()->Self {
        var t=self
        t.points=points.filter {$0.time.isFinite && $0.value.isFinite && $0.time>=0 && $0.time<=604800}.sorted {$0.time<$1.time}.prefix(32).map {p in var p=p;p.value=min(target.range.upperBound,max(target.range.lowerBound,p.value));return p}
        var times=Set<Double>(),ids=Set<UUID>();t.points=t.points.filter {times.insert($0.time).inserted && ids.insert($0.id).inserted}
        return t
    }
}
struct VideoAnimation:Codable,Equatable,Sendable {
    var tracks:[AnimationTrack]=[]
    func validated()->Self {var a=self;var targets=Set<AnimationTarget>();a.tracks=tracks.prefix(7).map {$0.validated()}.filter {targets.insert($0.target).inserted};return a}
    static func resolve(_ recipe:Recipe,time:Double?)->Recipe {
        guard let time,time.isFinite,let animation=recipe.videoAnimation,animation.tracks.contains(where:{$0.enabled && !$0.points.isEmpty}) else{return recipe}
        var r=recipe;r.videoAnimation=nil
        for track in animation.tracks where track.enabled && !track.points.isEmpty {
            let value=track.value(at:time)
            switch track.target {
            case .exposure:r.exposure=min(6,max(-6,r.exposure+value))
            case .look:r.lookAmount*=value
            case .lut:r.lutAmount*=value
            case .mask(let id):if let i=r.masks.firstIndex(where:{$0.id==id}) {r.masks[i].amount*=value}
            }
        }
        return r
    }
}
@MainActor @Observable final class ClipPosition {
    var time=0.0
    var playing=false
    var seekToken=UUID()
    var pauseToken=UUID()
    func seek(_ time:Double){self.time=time;seekToken=UUID()}
    func pause(){pauseToken=UUID()}
}

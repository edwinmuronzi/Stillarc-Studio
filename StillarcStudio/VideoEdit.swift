import Foundation

struct VideoEdit: Codable, Equatable, Sendable {
    var start = 0.0
    var end:Double? = nil
    var hdr = false
    func range(duration:Double) -> ClosedRange<Double> {
        let duration = max(0.001,duration)
        let lower = min(max(0,start.isFinite ? start : 0),max(0,duration-0.001))
        let upper = min(duration,max(lower+0.001,end.flatMap { $0.isFinite ? $0 : nil } ?? duration))
        return lower...upper
    }
    func isTrimmed(duration:Double) -> Bool { let r = range(duration:duration);return r.lowerBound>0 || r.upperBound<duration }
}

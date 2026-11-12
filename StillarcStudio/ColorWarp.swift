import Foundation

struct ColorWarpPoint:Codable,Equatable,Identifiable,Sendable {
    var id=UUID()
    var hue=210.0
    var saturation=0.6
    var hueShift=0.0
    var saturationShift=0.0
    var hueWidth=60.0
    var saturationWidth=0.5
    var isNeutral:Bool {abs(hueShift)<0.000001 && abs(saturationShift)<0.000001}
    func validated()->Self {
        var p=self
        func bound(_ x:Double,_ a:Double,_ b:Double,_ fallback:Double)->Double {x.isFinite ? min(b,max(a,x)):fallback}
        p.hue=bound(hue,0,360,210);p.saturation=bound(saturation,0,1,0.6)
        p.hueShift=bound(hueShift,-60,60,0);p.saturationShift=bound(saturationShift,-0.5,0.5,0)
        p.hueWidth=bound(hueWidth,5,120,60);p.saturationWidth=bound(saturationWidth,0.05,1,0.5)
        return p
    }
}
struct ColorWarp:Codable,Equatable,Sendable {
    var points:[ColorWarpPoint]=[]
    var amount=1.0
    var isNeutral:Bool {amount == 0 || points.allSatisfy(\.isNeutral)}
    func validated()->Self {var w=self;var ids=Set<UUID>();w.points=points.prefix(4).map {$0.validated()}.filter {ids.insert($0.id).inserted};w.amount=amount.isFinite ? min(1,max(0,amount)):1;return w}
}

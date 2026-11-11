import Foundation

enum BrushInteractionMode:String,CaseIterable,Identifiable { case paint = "Paint",erase = "Eraser",view = "View";var id:String { rawValue } }

struct BrushPoint:Codable,Equatable,Sendable {
    var x:Double;var y:Double
    func validated() -> Self { Self(x:x.isFinite ? min(1,max(0,x)) : 0.5,y:y.isFinite ? min(1,max(0,y)) : 0.5) }
}
struct BrushStroke:Identifiable,Codable,Equatable,Sendable {
    var id = UUID()
    var points:[BrushPoint]
    var radius:Double
    var feather:Double
    var erase:Bool
    func validated() -> Self {
        var r = self;r.points = Array(points.prefix(2048)).map { $0.validated() }
        r.radius = radius.isFinite ? min(0.3,max(0.005,radius)) : 0.06
        r.feather = feather.isFinite ? min(1,max(0.02,feather)) : 0.6
        return r
    }
}
struct BrushDrawing:Codable,Equatable,Sendable {
    var id = UUID()
    var revision = UUID()
    var strokes = [BrushStroke]()
    init() {}
    private enum CodingKeys:String,CodingKey { case id,revision,strokes }
    init(from decoder:Decoder) throws {
        let c = try decoder.container(keyedBy:CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self,forKey:.id) ?? UUID()
        revision = try c.decodeIfPresent(UUID.self,forKey:.revision) ?? UUID()
        strokes = Array((try c.decodeIfPresent([BrushStroke].self,forKey:.strokes) ?? []).prefix(64)).map { $0.validated() }
    }
    @discardableResult mutating func begin(point:BrushPoint,radius:Double,feather:Double,erase:Bool) -> UUID? {
        guard strokes.count<64 else { return nil }
        let stroke = BrushStroke(points:[point.validated()],radius:radius,feather:feather,erase:erase).validated()
        strokes.append(stroke);revision = UUID();return stroke.id
    }
    mutating func append(_ point:BrushPoint,stroke id:UUID) {
        guard let index = strokes.indices.last,strokes[index].id == id,strokes[index].points.count<2048 else { return }
        let point = point.validated()
        guard strokes[index].points.last != point else { return }
        strokes[index].points.append(point);revision = UUID()
    }
}

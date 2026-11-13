import Foundation

struct CurveNode:Codable,Equatable,Hashable,Sendable {
    var x:Double
    var y:Double
}
// Legacy five-point curves preserve their existing shape; flexible curves use nonuniform PCHIP.
struct ToneCurve: Codable, Equatable, Hashable, Sendable {
    var nodes:[CurveNode]?
    var black = 0.0
    var shadows = 0.25
    var middle = 0.5
    var highlights = 0.75
    var white = 1.0
    init() {}
    private enum CodingKeys: String, CodingKey { case nodes, black, shadows, middle, highlights, white }
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        nodes = try c.decodeIfPresent([CurveNode].self,forKey:.nodes)
        black = try c.decodeIfPresent(Double.self,forKey:.black) ?? black
        shadows = try c.decodeIfPresent(Double.self,forKey:.shadows) ?? shadows
        middle = try c.decodeIfPresent(Double.self,forKey:.middle) ?? middle
        highlights = try c.decodeIfPresent(Double.self,forKey:.highlights) ?? highlights
        white = try c.decodeIfPresent(Double.self,forKey:.white) ?? white
        self = validated()
    }
    var values: [Double] { [black,shadows,middle,highlights,white] }
    var points:[CurveNode] { nodes ?? values.enumerated().map {CurveNode(x:Double($0.offset)/4,y:$0.element)} }
    var isNeutral: Bool { points.allSatisfy {abs($0.x-$0.y)<0.000001} }
    func validated() -> ToneCurve {
        var result = self
        for point in CurvePoint.allCases {
            let value = result[keyPath:point.key]
            result[keyPath:point.key] = value.isFinite ? min(1,max(0,value)) : ToneCurve()[keyPath:point.key]
        }
        if let nodes {
            let sorted=nodes.filter {$0.x.isFinite && $0.y.isFinite}.sorted {$0.x<$1.x}
            var safe=[CurveNode]()
            for point in sorted.prefix(12) {
                let p=CurveNode(x:min(1,max(0,point.x)),y:min(1,max(0,point.y)))
                if let last=safe.last, p.x-last.x < 0.005 {continue}
                safe.append(p)
            }
            if safe.count>=2 {safe[0].x=0;safe[safe.count-1].x=1;result.nodes=safe} else {result.nodes=nil}
        }
        return result
    }
}
struct RGBCurves: Codable, Equatable, Hashable, Sendable {
    var master = ToneCurve()
    var red = ToneCurve()
    var green = ToneCurve()
    var blue = ToneCurve()
    init() {}
    private enum CodingKeys: String, CodingKey { case master, red, green, blue }
    init(from decoder: Decoder) throws {
        self.init(); let c = try decoder.container(keyedBy:CodingKeys.self)
        master = try c.decodeIfPresent(ToneCurve.self,forKey:.master) ?? master
        red = try c.decodeIfPresent(ToneCurve.self,forKey:.red) ?? red
        green = try c.decodeIfPresent(ToneCurve.self,forKey:.green) ?? green
        blue = try c.decodeIfPresent(ToneCurve.self,forKey:.blue) ?? blue
    }
    var isNeutral: Bool { master.isNeutral && red.isNeutral && green.isNeutral && blue.isNeutral }
    func validated() -> RGBCurves {
        var result = self
        result.master = master.validated(); result.red = red.validated(); result.green = green.validated(); result.blue = blue.validated()
        return result
    }
}
enum CurvePoint: Int, CaseIterable, Identifiable {
    case black, shadows, middle, highlights, white
    var id: Int { rawValue }
    var input: Double { Double(rawValue)/4 }
    var title: String { ["Black point","Dark tones","Middle tones","Bright tones","White point"][rawValue] }
    var key: WritableKeyPath<ToneCurve,Double> {
        switch self { case .black: \.black; case .shadows: \.shadows; case .middle: \.middle; case .highlights: \.highlights; case .white: \.white }
    }
}
enum CurveChannel: String, CaseIterable, Identifiable {
    case master = "Master", red = "Red", green = "Green", blue = "Blue"
    var id: String { rawValue }
    var key: WritableKeyPath<RGBCurves,ToneCurve> {
        switch self { case .master: \.master; case .red: \.red; case .green: \.green; case .blue: \.blue }
    }
    func recipeKey(_ point: CurvePoint) -> WritableKeyPath<Recipe,Double> { (\Recipe.rgbCurves).appending(path:key).appending(path:point.key) }
    var help: String {
        switch self {
        case .master: "Drag a point up to brighten that tone, down to darken it. Left is dark; right is bright."
        case .red: "Raise a point to add red to that tone; lower it to add cyan."
        case .green: "Raise a point to add green to that tone; lower it to add magenta."
        case .blue: "Raise a point to add blue to that tone; lower it to add yellow."
        }
    }
}
struct ColorRangeAdjustment: Codable, Equatable, Sendable {
    var hue = 0.0
    var saturation = 0.0
    var brightness = 0.0
    init() {}
    private enum CodingKeys: String, CodingKey { case hue, saturation, brightness }
    init(from decoder: Decoder) throws {
        self.init(); let c = try decoder.container(keyedBy:CodingKeys.self)
        hue = try c.decodeIfPresent(Double.self,forKey:.hue) ?? hue
        saturation = try c.decodeIfPresent(Double.self,forKey:.saturation) ?? saturation
        brightness = try c.decodeIfPresent(Double.self,forKey:.brightness) ?? brightness
        self = validated()
    }
    var isNeutral: Bool { abs(hue) < 0.000001 && abs(saturation) < 0.000001 && abs(brightness) < 0.000001 }
    func validated() -> ColorRangeAdjustment {
        var copy = self
        copy.hue = hue.isFinite ? min(30,max(-30,hue)) : 0
        copy.saturation = saturation.isFinite ? min(1,max(-1,saturation)) : 0
        copy.brightness = brightness.isFinite ? min(1,max(-1,brightness)) : 0
        return copy
    }
}
struct SelectiveColors: Codable, Equatable, Sendable {
    var red = ColorRangeAdjustment()
    var orange = ColorRangeAdjustment()
    var yellow = ColorRangeAdjustment()
    var green = ColorRangeAdjustment()
    var aqua = ColorRangeAdjustment()
    var blue = ColorRangeAdjustment()
    var purple = ColorRangeAdjustment()
    var magenta = ColorRangeAdjustment()
    init() {}
    private enum CodingKeys: String, CodingKey { case red, orange, yellow, green, aqua, blue, purple, magenta }
    init(from decoder: Decoder) throws {
        self.init(); let c = try decoder.container(keyedBy:CodingKeys.self)
        red = try c.decodeIfPresent(ColorRangeAdjustment.self,forKey:.red) ?? red
        orange = try c.decodeIfPresent(ColorRangeAdjustment.self,forKey:.orange) ?? orange
        yellow = try c.decodeIfPresent(ColorRangeAdjustment.self,forKey:.yellow) ?? yellow
        green = try c.decodeIfPresent(ColorRangeAdjustment.self,forKey:.green) ?? green
        aqua = try c.decodeIfPresent(ColorRangeAdjustment.self,forKey:.aqua) ?? aqua
        blue = try c.decodeIfPresent(ColorRangeAdjustment.self,forKey:.blue) ?? blue
        purple = try c.decodeIfPresent(ColorRangeAdjustment.self,forKey:.purple) ?? purple
        magenta = try c.decodeIfPresent(ColorRangeAdjustment.self,forKey:.magenta) ?? magenta
    }
    var isNeutral: Bool { ColorRange.allCases.allSatisfy { self[keyPath:$0.key].isNeutral } }
    func validated() -> SelectiveColors {
        var copy = self
        for band in ColorRange.allCases { copy[keyPath:band.key] = copy[keyPath:band.key].validated() }
        return copy
    }
}
enum ColorRange: Int, CaseIterable, Identifiable {
    case red, orange, yellow, green, aqua, blue, purple, magenta
    var id: Int { rawValue }
    var title: String { ["Reds","Oranges","Yellows","Greens","Aquas","Blues","Purples","Magentas"][rawValue] }
    var degrees: Double { [0,30,60,120,180,240,270,300][rawValue] }
    var key: WritableKeyPath<SelectiveColors,ColorRangeAdjustment> {
        switch self { case .red: \.red; case .orange: \.orange; case .yellow: \.yellow; case .green: \.green; case .aqua: \.aqua; case .blue: \.blue; case .purple: \.purple; case .magenta: \.magenta }
    }
    func recipeKey(_ component: WritableKeyPath<ColorRangeAdjustment,Double>) -> WritableKeyPath<Recipe,Double> { (\Recipe.selectiveColors).appending(path:key).appending(path:component) }
}

// Shape-preserving interpolation on an arbitrary, strictly increasing input grid.
struct CurveSpline {
    let values:[Double]
    let inputs:[Double]
    let slopes:[Double]
    init(_ curve:ToneCurve) {
        let p=curve.validated().points
        inputs=p.map(\.x);values=p.map(\.y)
        let h=(0..<p.count-1).map {p[$0+1].x-p[$0].x}
        let d=(0..<p.count-1).map {(p[$0+1].y-p[$0].y)/h[$0]}
        if p.count==2 {slopes=[d[0],d[0]];return}
        func end(_ a:Double,_ b:Double,_ ha:Double,_ hb:Double)->Double {
            let slope=((2*ha+hb)*a-ha*b)/(ha+hb)
            if slope*a<=0 {return 0}
            return a*b<0 && abs(slope)>abs(3*a) ? 3*a:slope
        }
        var m=[end(d[0],d[1],h[0],h[1])]
        for i in 1..<p.count-1 {
            let w1=2*h[i]+h[i-1],w2=h[i]+2*h[i-1]
            m.append(d[i-1]*d[i]<=0 ? 0:(w1+w2)/(w1/d[i-1]+w2/d[i]))
        }
        m.append(end(d[d.count-1],d[d.count-2],h[h.count-1],h[h.count-2]));slopes=m
    }
    func value(at input:Double)->Double {
        let x=min(1,max(0,input.isFinite ? input:0))
        let i=min(inputs.count-2,max(0,(inputs.firstIndex(where:{$0>x}) ?? inputs.count)-1))
        let h=inputs[i+1]-inputs[i],t=(x-inputs[i])/h,t2=t*t,t3=t2*t
        return (2*t3-3*t2+1)*values[i]+(t3-2*t2+t)*slopes[i]*h+(-2*t3+3*t2)*values[i+1]+(t3-t2)*slopes[i+1]*h
    }
}

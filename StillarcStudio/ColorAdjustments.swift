import Foundation

// Five evenly spaced control points, with shape-preserving interpolation.
struct ToneCurve: Codable, Equatable, Hashable, Sendable {
    var black = 0.0
    var shadows = 0.25
    var middle = 0.5
    var highlights = 0.75
    var white = 1.0
    init() {}
    private enum CodingKeys: String, CodingKey { case black, shadows, middle, highlights, white }
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        black = try c.decodeIfPresent(Double.self,forKey:.black) ?? black
        shadows = try c.decodeIfPresent(Double.self,forKey:.shadows) ?? shadows
        middle = try c.decodeIfPresent(Double.self,forKey:.middle) ?? middle
        highlights = try c.decodeIfPresent(Double.self,forKey:.highlights) ?? highlights
        white = try c.decodeIfPresent(Double.self,forKey:.white) ?? white
        self = validated()
    }
    var values: [Double] { [black,shadows,middle,highlights,white] }
    var isNeutral: Bool { zip(values,ToneCurve().values).allSatisfy { abs($0.0-$0.1) < 0.000001 } }
    func validated() -> ToneCurve {
        var result = self
        for point in CurvePoint.allCases {
            let value = result[keyPath:point.key]
            result[keyPath:point.key] = value.isFinite ? min(1,max(0,value)) : ToneCurve()[keyPath:point.key]
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

// Uniform-grid PCHIP: local extrema stay bounded instead of ringing past control points.
struct CurveSpline {
    let values: [Double]
    let slopes: [Double]
    init(_ curve: ToneCurve) {
        let points = curve.values
        values = points
        let d = (0..<4).map { (points[$0+1]-points[$0])*4 }
        func end(_ first: Double,_ second: Double) -> Double {
            let slope = (3*first-second)/2
            if slope*first <= 0 { return 0 }
            return first*second < 0 && abs(slope) > abs(3*first) ? 3*first : slope
        }
        slopes = [end(d[0],d[1])] + (1...3).map { i in d[i-1]*d[i] <= 0 ? 0 : 2*d[i-1]*d[i]/(d[i-1]+d[i]) } + [end(d[3],d[2])]
    }
    func value(at input: Double) -> Double {
        let x = min(1,max(0,input))*4, index = min(3,Int(x)), t = x-Double(index)
        let t2 = t*t, t3 = t2*t
        return (2*t3-3*t2+1)*values[index] + (t3-2*t2+t)*slopes[index]/4 + (-2*t3+3*t2)*values[index+1] + (t3-t2)*slopes[index+1]/4
    }
}

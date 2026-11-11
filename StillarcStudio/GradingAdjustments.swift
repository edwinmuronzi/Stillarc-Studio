import Foundation

struct WheelGrade: Codable, Equatable, Sendable {
    var hue = 0.0
    var strength = 0.0
    var exposure = 0.0
    init() {}
    private enum CodingKeys: String, CodingKey { case hue, strength, exposure }
    init(from decoder: Decoder) throws {
        self.init(); let c = try decoder.container(keyedBy:CodingKeys.self)
        hue = try c.decodeIfPresent(Double.self,forKey:.hue) ?? hue
        strength = try c.decodeIfPresent(Double.self,forKey:.strength) ?? strength
        exposure = try c.decodeIfPresent(Double.self,forKey:.exposure) ?? exposure
        self = validated()
    }
    var isNeutral: Bool { strength < 0.000001 && abs(exposure) < 0.000001 }
    func validated() -> WheelGrade {
        var copy = self
        let wrapped = hue.isFinite ? hue.truncatingRemainder(dividingBy:360) : 0
        copy.hue = wrapped < 0 ? wrapped+360 : wrapped
        copy.strength = strength.isFinite ? min(1,max(0,strength)) : 0
        copy.exposure = exposure.isFinite ? min(1,max(-1,exposure)) : 0
        return copy
    }
    var tint: [Double] {
        let h = hue/60
        let rgb = [0.0,4,2].map { shift in min(1,max(0,abs((h+shift).truncatingRemainder(dividingBy:6)-3)-1)) }
        let y = rgb[0]*0.2126 + rgb[1]*0.7152 + rgb[2]*0.0722
        return rgb.map { ($0-y)*strength*0.18 }
    }
}
struct ColorWheels: Codable, Equatable, Sendable {
    var shadows = WheelGrade()
    var midtones = WheelGrade()
    var highlights = WheelGrade()
    var global = WheelGrade()
    var balance = 0.0
    var blend = 0.5
    var preserveBrightness = true
    init() {}
    private enum CodingKeys: String, CodingKey { case shadows, midtones, highlights, global, balance, blend, preserveBrightness }
    init(from decoder: Decoder) throws {
        self.init(); let c = try decoder.container(keyedBy:CodingKeys.self)
        shadows = try c.decodeIfPresent(WheelGrade.self,forKey:.shadows) ?? shadows
        midtones = try c.decodeIfPresent(WheelGrade.self,forKey:.midtones) ?? midtones
        highlights = try c.decodeIfPresent(WheelGrade.self,forKey:.highlights) ?? highlights
        global = try c.decodeIfPresent(WheelGrade.self,forKey:.global) ?? global
        balance = try c.decodeIfPresent(Double.self,forKey:.balance) ?? balance
        blend = try c.decodeIfPresent(Double.self,forKey:.blend) ?? blend
        preserveBrightness = try c.decodeIfPresent(Bool.self,forKey:.preserveBrightness) ?? preserveBrightness
        self = validated()
    }
    var isNeutral: Bool { WheelZone.allCases.allSatisfy { self[keyPath:$0.key].isNeutral } }
    func validated() -> ColorWheels {
        var copy = self
        for zone in WheelZone.allCases { copy[keyPath:zone.key] = copy[keyPath:zone.key].validated() }
        copy.balance = balance.isFinite ? min(1,max(-1,balance)) : 0
        copy.blend = blend.isFinite ? min(1,max(0,blend)) : 0.5
        return copy
    }
}
enum WheelZone: String, CaseIterable, Identifiable {
    case shadows = "Shadows", midtones = "Midtones", highlights = "Highlights", global = "Global"
    var id: String { rawValue }
    var key: WritableKeyPath<ColorWheels,WheelGrade> {
        switch self { case .shadows: \.shadows; case .midtones: \.midtones; case .highlights: \.highlights; case .global: \.global }
    }
    func recipeKey(_ component: WritableKeyPath<WheelGrade,Double>) -> WritableKeyPath<Recipe,Double> { (\Recipe.colorWheels).appending(path:key).appending(path:component) }
    var help: String {
        switch self {
        case .shadows: "Tint the darker parts of the photo. Move toward a color; move back to the center for no tint."
        case .midtones: "Tint the middle tones, where much of your subject's detail lives."
        case .highlights: "Tint the brighter parts of the photo. Pure white stays neutral with Keep brightness enabled."
        case .global: "Tint the whole photo. Strength controls the amount; brightness changes the overall light."
        }
    }
}

struct ChannelMixer: Codable, Equatable, Sendable {
    var redRed = 1.0
    var redGreen = 0.0
    var redBlue = 0.0
    var greenRed = 0.0
    var greenGreen = 1.0
    var greenBlue = 0.0
    var blueRed = 0.0
    var blueGreen = 0.0
    var blueBlue = 1.0
    var redOffset = 0.0
    var greenOffset = 0.0
    var blueOffset = 0.0
    var monochrome = false
    init() {}
    private enum CodingKeys: String, CodingKey { case redRed, redGreen, redBlue, greenRed, greenGreen, greenBlue, blueRed, blueGreen, blueBlue, redOffset, greenOffset, blueOffset, monochrome }
    init(from decoder: Decoder) throws {
        self.init(); let c = try decoder.container(keyedBy:CodingKeys.self)
        redRed = try c.decodeIfPresent(Double.self,forKey:.redRed) ?? redRed
        redGreen = try c.decodeIfPresent(Double.self,forKey:.redGreen) ?? redGreen
        redBlue = try c.decodeIfPresent(Double.self,forKey:.redBlue) ?? redBlue
        greenRed = try c.decodeIfPresent(Double.self,forKey:.greenRed) ?? greenRed
        greenGreen = try c.decodeIfPresent(Double.self,forKey:.greenGreen) ?? greenGreen
        greenBlue = try c.decodeIfPresent(Double.self,forKey:.greenBlue) ?? greenBlue
        blueRed = try c.decodeIfPresent(Double.self,forKey:.blueRed) ?? blueRed
        blueGreen = try c.decodeIfPresent(Double.self,forKey:.blueGreen) ?? blueGreen
        blueBlue = try c.decodeIfPresent(Double.self,forKey:.blueBlue) ?? blueBlue
        redOffset = try c.decodeIfPresent(Double.self,forKey:.redOffset) ?? redOffset
        greenOffset = try c.decodeIfPresent(Double.self,forKey:.greenOffset) ?? greenOffset
        blueOffset = try c.decodeIfPresent(Double.self,forKey:.blueOffset) ?? blueOffset
        monochrome = try c.decodeIfPresent(Bool.self,forKey:.monochrome) ?? monochrome
        self = validated()
    }
    var isNeutral: Bool { !monochrome && MixerChannel.allCases.allSatisfy { isNeutral(channel:$0) } }
    func isNeutral(channel: MixerChannel) -> Bool {
        let original = ChannelMixer()
        return (channel.keys+[channel.offsetKey]).allSatisfy { abs(self[keyPath:$0]-original[keyPath:$0]) < 0.000001 }
    }
    mutating func reset(_ channel: MixerChannel) {
        let original = ChannelMixer()
        for key in channel.keys+[channel.offsetKey] { self[keyPath:key] = original[keyPath:key] }
    }
    mutating func swapRedAndBlue() {
        self = ChannelMixer(); redRed = 0; redBlue = 1; blueBlue = 0; blueRed = 1
    }
    func validated() -> ChannelMixer {
        var copy = self
        for channel in MixerChannel.allCases {
            for key in channel.keys {
                let value = copy[keyPath:key]
                copy[keyPath:key] = value.isFinite ? min(2,max(-2,value)) : ChannelMixer()[keyPath:key]
            }
            let value = copy[keyPath:channel.offsetKey]
            copy[keyPath:channel.offsetKey] = value.isFinite ? min(0.5,max(-0.5,value)) : 0
        }
        return copy
    }
}
enum MixerChannel: String, CaseIterable, Identifiable {
    case red = "Red", green = "Green", blue = "Blue"
    var id: String { rawValue }
    var keys: [WritableKeyPath<ChannelMixer,Double>] {
        switch self { case .red: [\.redRed,\.redGreen,\.redBlue]; case .green: [\.greenRed,\.greenGreen,\.greenBlue]; case .blue: [\.blueRed,\.blueGreen,\.blueBlue] }
    }
    var offsetKey: WritableKeyPath<ChannelMixer,Double> {
        switch self { case .red: \.redOffset; case .green: \.greenOffset; case .blue: \.blueOffset }
    }
    func recipeKey(_ input: MixerChannel) -> WritableKeyPath<Recipe,Double> {
        let index = MixerChannel.allCases.firstIndex(of:input)!
        return (\Recipe.channelMixer).appending(path:keys[index])
    }
    var recipeOffsetKey: WritableKeyPath<Recipe,Double> { (\Recipe.channelMixer).appending(path:offsetKey) }
}

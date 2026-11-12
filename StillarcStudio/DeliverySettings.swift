import SwiftUI
import CoreImage

enum DeliverySize:String,CaseIterable,Codable,Identifiable,Sendable {
    case original="Original",large="3840 px",medium="1920 px",small="1280 px"
    var id:String {rawValue}
    var limit:Double {switch self {case .original: .infinity;case .large:3840;case .medium:1920;case .small:1280}}
}
enum DeliveryQuality:String,CaseIterable,Codable,Identifiable,Sendable {
    case maximum="Maximum",balanced="Balanced",compact="Compact"
    var id:String {rawValue}
    var photo:Double {switch self {case .maximum:0.96;case .balanced:0.85;case .compact:0.7}}
    var video:Double {switch self {case .maximum:1;case .balanced:0.75;case .compact:0.5}}
}
struct DeliverySettings:Codable,Equatable,Sendable {
    var size=DeliverySize.original
    var quality=DeliveryQuality.maximum
    func dimensions(_ input:CGSize,video:Bool=false)->CGSize {
        let scale=min(1,size.limit/max(1,max(input.width,input.height)))
        let unit=video ? 2.0:1.0
        return CGSize(width:max(unit,floor(input.width*scale/unit)*unit),height:max(unit,floor(input.height*scale/unit)*unit))
    }
    func resize(_ image:CIImage,video:Bool=false)->CIImage {
        let rect=image.extent,target=dimensions(rect.size,video:video)
        guard target != rect.size || rect.origin != .zero else {return image}
        let normalized=image.transformed(by:.init(translationX:-rect.minX,y:-rect.minY))
        // Lanczos after full-source grading keeps masks/film scale and output independent of preview quality.
        let aspect=(target.width/rect.width)/(target.height/rect.height)
        return normalized.applyingFilter("CILanczosScaleTransform",parameters:[kCIInputScaleKey:target.height/rect.height,kCIInputAspectRatioKey:aspect]).cropped(to:CGRect(origin:.zero,size:target))
    }
    static func load(_ defaults:UserDefaults = .standard)->Self {Self(size:DeliverySize(rawValue:defaults.string(forKey:"delivery.size") ?? "") ?? .original,quality:DeliveryQuality(rawValue:defaults.string(forKey:"delivery.quality") ?? "") ?? .maximum)}
    func save(_ defaults:UserDefaults = .standard) {defaults.set(size.rawValue,forKey:"delivery.size");defaults.set(quality.rawValue,forKey:"delivery.quality")}
}
struct DeliveryControls:View {
    @Binding var settings:DeliverySettings
    var lossless=false
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            Picker("Export size",selection:$settings.size) {ForEach(DeliverySize.allCases) {Text($0.rawValue).tag($0)}}.pickerStyle(.menu).accessibilityIdentifier("deliverySize")
            Text("Longest edge after cropping. Smaller items stay their original size; Studio never enlarges them.").font(.caption).foregroundStyle(StudioStyle.secondary)
            if !lossless {Picker("Export quality",selection:$settings.quality) {ForEach(DeliveryQuality.allCases) {Text($0.rawValue).tag($0)}}.pickerStyle(.menu).accessibilityIdentifier("deliveryQuality")}
            Text(lossless ? "PNG stays lossless at every size." : "Maximum preserves the most detail. Balanced and Compact use stronger compression to make smaller files. They keep the chosen size and video frame timing.").font(.caption).foregroundStyle(StudioStyle.secondary)
        }.onChange(of:settings) {_,value in value.save()}
    }
}

import SwiftUI
import CoreImage
import AVFoundation
import VideoToolbox

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
enum VideoDeliveryCodec:String,CaseIterable,Codable,Identifiable,Sendable {
    case hevc="HEVC", h264="H.264", proRes422="ProRes 422"
    var id:String {rawValue}
    var avCodec:AVVideoCodecType {switch self {case .hevc:.hevc;case .h264:.h264;case .proRes422:.proRes422}}
    var fileType:AVFileType {self == .h264 ? .mp4:.mov}
    var fileExtension:String {self == .h264 ? "mp4":"mov"}
    static let proResHardware:Bool = {
        var list:CFArray?
        guard VTCopyVideoEncoderList(nil,&list)==noErr,let encoders=list as? [[String:Any]] else {return false}
        return encoders.contains {($0[kVTVideoEncoderList_CodecType as String] as? NSNumber)?.uint32Value==kCMVideoCodecType_AppleProRes422 && ($0[kVTVideoEncoderList_IsHardwareAccelerated as String] as? Bool)==true}
    }()
    var available:Bool {self != .proRes422 || Self.proResHardware}
    var help:String {switch self {
    case .hevc:"Smaller files with high detail. Supports SDR and 10-bit HLG HDR. Best everyday choice."
    case .h264:"8-bit SDR MP4 for broad compatibility. Sound is encoded as AAC. For HDR, choose HEVC or ProRes."
    case .proRes422:"10-bit MOV for further editing. Much larger files; compression quality is fixed. Uses supported hardware encoding. Save to Files for your editing app."
    }}
}
enum PhotoOutputSpace:String,Codable,CaseIterable,Identifiable,Sendable {
    case sRGB="sRGB",displayP3="Display P3"
    var id:String {rawValue}
    var colorSpace:CGColorSpace {CGColorSpace(name:self == .sRGB ? CGColorSpace.sRGB:CGColorSpace.displayP3)!}
}
struct DeliverySettings:Codable,Equatable,Sendable {
    var size=DeliverySize.original
    var quality=DeliveryQuality.maximum
    var photoSpace:PhotoOutputSpace? = nil
    var outputSpace:PhotoOutputSpace {get {photoSpace ?? .sRGB} set {photoSpace=newValue == .sRGB ? nil:newValue}}
    var videoCodec:VideoDeliveryCodec? = nil
    var codec:VideoDeliveryCodec {get {videoCodec ?? .hevc} set {videoCodec=newValue == .hevc ? nil:newValue}}
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
    static func load(_ defaults:UserDefaults = .standard)->Self {
        var result=Self(size:DeliverySize(rawValue:defaults.string(forKey:"delivery.size") ?? "") ?? .original,quality:DeliveryQuality(rawValue:defaults.string(forKey:"delivery.quality") ?? "") ?? .maximum)
        // Canonicalize explicit persisted defaults through the same setters as the UI.
        result.outputSpace=PhotoOutputSpace(rawValue:defaults.string(forKey:"delivery.photoSpace") ?? "") ?? .sRGB
        result.codec=VideoDeliveryCodec(rawValue:defaults.string(forKey:"delivery.codec") ?? "") ?? .hevc
        return result
    }
    func save(_ defaults:UserDefaults = .standard) {defaults.set(outputSpace.rawValue,forKey:"delivery.photoSpace");defaults.set(size.rawValue,forKey:"delivery.size");defaults.set(quality.rawValue,forKey:"delivery.quality");defaults.set(codec == .hevc ? nil:codec.rawValue,forKey:"delivery.codec")}
}
struct DeliveryControls:View {
    @Binding var settings:DeliverySettings
    var lossless=false
    var video=false
    var photos=false
    var hdr=false
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            if video {
                Picker("Video format",selection:$settings.codec) {ForEach(VideoDeliveryCodec.allCases) {codec in Text(codec.rawValue).tag(codec).disabled(!codec.available || (hdr && codec == .h264))}}.pickerStyle(.menu).accessibilityIdentifier("deliveryVideoCodec")
                Text(settings.codec.help).font(.caption).foregroundStyle(StudioStyle.secondary)
                if !VideoDeliveryCodec.proResHardware {Text("ProRes export requires a supported hardware encoder on this device.").font(.caption).foregroundStyle(StudioStyle.secondary)}
                if hdr {Text("This delivery includes HDR. H.264 is SDR-only; Studio keeps your HDR choice intact.").font(.caption).foregroundStyle(StudioStyle.secondary)}
            }
            if photos || !video {
                Picker("SDR photo colour space",selection:$settings.outputSpace) {ForEach(PhotoOutputSpace.allCases) {Text($0.rawValue).tag($0)}}.pickerStyle(.menu).accessibilityIdentifier("photoOutputSpace")
                Text("sRGB is the safest sharing choice. Display P3 preserves more wide-gamut colour on compatible displays. HDR HEIF stays HLG Rec.2020; video uses its chosen SDR/HDR encoding.").font(.caption).foregroundStyle(StudioStyle.secondary)
            }
            Picker("Export size",selection:$settings.size) {ForEach(DeliverySize.allCases) {Text($0.rawValue).tag($0)}}.pickerStyle(.menu).accessibilityIdentifier("deliverySize")
            Text("Longest edge after cropping. Smaller items stay their original size; Studio never enlarges them.").font(.caption).foregroundStyle(StudioStyle.secondary)
            if !lossless && (photos || !video || settings.codec != .proRes422) {Picker(photos && video && settings.codec == .proRes422 ? "Photo quality":"Export quality",selection:$settings.quality) {ForEach(DeliveryQuality.allCases) {Text($0.rawValue).tag($0)}}.pickerStyle(.menu).accessibilityIdentifier("deliveryQuality")}
            Text(video && settings.codec == .proRes422 ? "ProRes 422 uses its fixed mastering compression; the quality setting does not change it." : lossless ? "PNG stays lossless at every size." : "Maximum preserves the most detail. Balanced and Compact use stronger compression to make smaller files. They keep the chosen size and video frame timing.").font(.caption).foregroundStyle(StudioStyle.secondary)
        }.onChange(of:settings) {_,value in value.save()}
        .onAppear {normalize()}.onChange(of:hdr) {_,_ in normalize()}
    }
    private func normalize() {if video && ((!settings.codec.available) || (hdr && settings.codec == .h264)) {settings.codec = .hevc;settings.save()}}
}

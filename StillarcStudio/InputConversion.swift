import Foundation
import CoreImage
import Metal

enum CameraLogProfile: String, Codable, CaseIterable, Identifiable, Sendable {
    case standard, appleLog, appleLog2, sonySLog3Cine, panasonicVLog
    var id:String { rawValue }
    var title:String { switch self { case .standard:"Standard / already converted"; case .appleLog:"Apple Log · Rec.2020"; case .appleLog2:"Apple Log 2 · Apple Wide Gamut"; case .sonySLog3Cine:"Sony S-Log3 · S-Gamut3.Cine"; case .panasonicVLog:"Panasonic V-Log · V-Gamut" } }
    var shortTitle:String { switch self { case .standard:"STANDARD"; case .appleLog:"APPLE LOG"; case .appleLog2:"APPLE LOG 2"; case .sonySLog3Cine:"SONY S-LOG3"; case .panasonicVLog:"PANASONIC V-LOG" } }
    var matrix:[[Double]] {
        switch self {
        case .standard: [[1,0,0],[0,1,0],[0,0,1]]
        case .appleLog: [[1.660491002108,-0.587641138789,-0.072849863320],[-0.124550474522,1.132899897126,-0.008349422604],[-0.018150763355,-0.100578898008,1.118729661363]]
        case .appleLog2: [[1.707280377174,-0.519019919932,-0.188260457242],[-0.125010746108,1.314662365482,-0.189651619374],[-0.043624333388,-0.191214371733,1.234838705120]]
        case .sonySLog3Cine: [[1.626947409729,-0.540138538870,-0.086808870859],[-0.178515527115,1.417940927464,-0.239425400349],[-0.044436115009,-0.195919966172,1.240356081181]]
        case .panasonicVLog: [[1.806575883725,-0.695697274084,-0.110878609641],[-0.170090343102,1.305955216095,-0.135864872993],[-0.025205784017,-0.154468329361,1.179674113377]]
        }
    }
}
struct InputConversion: Codable, Equatable, Sendable {
    var profile = CameraLogProfile.standard
    var exposure = 0.0
    var softHighlights = true
    init(profile:CameraLogProfile = .standard,exposure:Double = 0,softHighlights:Bool = true) { self.profile = profile; self.exposure = exposure; self.softHighlights = softHighlights }
    private enum CodingKeys:String,CodingKey { case profile,exposure,softHighlights }
    init(from decoder:Decoder) throws {
        let c = try decoder.container(keyedBy:CodingKeys.self)
        self.init(profile:try c.decodeIfPresent(CameraLogProfile.self,forKey:.profile) ?? .standard,exposure:try c.decodeIfPresent(Double.self,forKey:.exposure) ?? 0,softHighlights:try c.decodeIfPresent(Bool.self,forKey:.softHighlights) ?? true)
        self = validated()
    }
    func validated() -> Self { var copy = self; copy.exposure = exposure.isFinite ? min(4,max(-4,exposure)) : 0; return copy }
}

/// Analytic input transform: no resampled 3D conversion table and no per-drag rebuild.
enum LogConversion {
    static func decode(_ code:Double,profile:CameraLogProfile = .appleLog) -> Double {
        if profile == .sonySLog3Cine { return code >= 171.2102946929/1023 ? pow(10,(code*1023-420)/261.5)*0.19-0.01 : (code*1023-95)*0.01125/(171.2102946929-95) }
        if profile == .panasonicVLog { return code >= 0.181 ? pow(10,(code-0.598206)/0.241514)-0.00873 : (code-0.125)/5.6 }
        return code >= 0.20855531595464202 ? pow(2,(code-0.69336945)/0.08550479)-0.00964052 : sqrt(max(0,code)/47.28711236)-0.05641088
    }
    static func encode(_ linear:Double,profile:CameraLogProfile = .appleLog) -> Double {
        if profile == .sonySLog3Cine { return linear >= 0.01125 ? (420+log10((linear+0.01)/0.19)*261.5)/1023 : (linear*(171.2102946929-95)/0.01125+95)/1023 }
        if profile == .panasonicVLog { return linear >= 0.01 ? 0.241514*log10(linear+0.00873)+0.598206 : 5.6*linear+0.125 }
        return linear >= 0.01 ? 0.08550479*log2(linear+0.00964052)+0.69336945 : linear >= -0.05641088 ? 47.28711236*pow(linear+0.05641088,2) : 0
    }
    private final class Compiled: @unchecked Sendable {
        let value:CIColorKernel?
        init() {
            let code = """
            float studioAppleLinear(float v, float profile) {
                if (profile > 1.5) {
                    if (v >= 0.181) return pow(10.0,(v-0.598206)/0.241514)-0.00873;
                    return (v-0.125)/5.6;
                }
                if (profile > 0.5) {
                    if (v >= 171.2102946929/1023.0) return pow(10.0,(v*1023.0-420.0)/261.5)*0.19-0.01;
                    return (v*1023.0-95.0)*0.01125/(171.2102946929-95.0);
                }
                if (v >= 0.20855531595464202) return exp2((v-0.69336945)/0.08550479)-0.00964052;
                return sqrt(max(v,0.0)/47.28711236)-0.05641088;
            }
            kernel vec4 studioInput(__sample pixel, vec3 rowR, vec3 rowG, vec3 rowB, float exposure, float soft, float profile) {
                vec4 p = unpremultiply(pixel);
                if (p.a <= 0.000001) return vec4(0.0);
                vec3 linear = vec3(studioAppleLinear(p.r,profile),studioAppleLinear(p.g,profile),studioAppleLinear(p.b,profile));
                vec3 rgb = vec3(dot(linear,rowR),dot(linear,rowG),dot(linear,rowB))*exp2(exposure);
                if (soft > 0.5) {
                    float y = dot(rgb,vec3(0.2126,0.7152,0.0722));
                    if (y <= 0.0) rgb = vec3(0.0);
                    else {
                        float mapped = y <= 0.6 ? y : 0.6+0.4*(1.0-exp(-(y-0.6)/0.4));
                        rgb *= mapped/y;
                        vec3 chroma = rgb-vec3(mapped);
                        float low = min(chroma.r,min(chroma.g,chroma.b));
                        float high = max(chroma.r,max(chroma.g,chroma.b));
                        float strength = 1.0;
                        if (low < 0.0) strength = min(strength,mapped/-low);
                        if (high > 0.0) strength = min(strength,(1.0-mapped)/high);
                        rgb = vec3(mapped)+chroma*max(0.0,strength);
                    }
                }
                return premultiply(vec4(rgb,p.a));
            }
            """
            if MTLCreateSystemDefaultDevice()?.supportsDynamicLibraries == true {
                let metal = "#include <metal_stdlib>\n#include <CoreImage/CoreImage.h>\nusing namespace metal;\nusing namespace coreimage;\n" + code.replacingOccurrences(of:"vec3",with:"float3").replacingOccurrences(of:"vec4",with:"float4").replacingOccurrences(of:"kernel float4",with:"[[stitchable]] float4").replacingOccurrences(of:"__sample",with:"coreimage::sample_t")
                if let kernels = try? CIKernel.kernels(withMetalString:metal), let kernel = kernels.first as? CIColorKernel { value = kernel; return }
            }
            value = CIColorKernel(source:code)
        }
    }
    private static let compiled = Compiled()
    static func prepare() throws { guard compiled.value != nil else { throw StudioError.render } }
    static func apply(_ source:CIImage,input:InputConversion) -> CIImage {
        guard input.profile != .standard else { return source }
        let matrix = input.profile.matrix
        let rows = matrix.map { CIVector(x:$0[0],y:$0[1],z:$0[2]) }
        return compiled.value?.apply(extent:source.extent,arguments:[source,rows[0],rows[1],rows[2],input.exposure,input.softHighlights ? 1.0 : 0.0,input.profile == .sonySLog3Cine ? 1.0 : (input.profile == .panasonicVLog ? 2.0 : 0.0)]) ?? source
    }
}

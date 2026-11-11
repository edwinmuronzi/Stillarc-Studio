import CoreImage
import Metal

/// Keeps scene headroom outside display-referred creative tools, then restores it.
enum HDRPipeline {
    static let hlg = CGColorSpace(name:CGColorSpace.itur_2100_HLG)!
    private final class Kernels: @unchecked Sendable {
        let scale:CIColorKernel?
        let divide:CIColorKernel?
        let multiply:CIColorKernel?
        init() {
            func compile(_ name:String,_ body:String) -> CIColorKernel? {
                let source = "kernel vec4 \(name)(__sample p, __sample q) { \(body) }"
                if MTLCreateSystemDefaultDevice()?.supportsDynamicLibraries == true {
                    let metal = "#include <metal_stdlib>\n#include <CoreImage/CoreImage.h>\nusing namespace metal;using namespace coreimage;\n"+source.replacingOccurrences(of:"kernel vec4",with:"[[stitchable]] float4").replacingOccurrences(of:"vec4",with:"float4").replacingOccurrences(of:"vec3",with:"float3").replacingOccurrences(of:"__sample",with:"coreimage::sample_t")
                    if let value = try? CIKernel.kernels(withMetalString:metal).first as? CIColorKernel { return value }
                }
                return CIColorKernel(source:source)
            }
            scale = compile("studioHDRScale","vec4 c=unpremultiply(p);float s=max(1.0,max(c.r,max(c.g,c.b)));return vec4(s,s,s,1.0);")
            divide = compile("studioHDRDivide","return vec4(p.rgb/max(q.r,1.0),p.a);")
            multiply = compile("studioHDRRestore","return vec4(p.rgb*q.r,p.a);")
        }
    }
    private static let kernels = Kernels()
    static func prepare() throws { guard kernels.scale != nil,kernels.divide != nil,kernels.multiply != nil else { throw StudioError.render } }
    /// Same globally graded, framed selection input used inside MaskEngine, without local layers.
    static func maskReference(_ source:CIImage,recipe:Recipe,hdr:Bool) -> CIImage {
        var base = recipe;base.masks = []
        guard hdr else { return ImageEngine.apply(source,recipe:base,preview:true) }
        var input = recipe.input;input.softHighlights = false
        let decoded = LogConversion.apply(source,input:input)
        guard let scale = kernels.scale?.apply(extent:decoded.extent,arguments:[decoded,decoded]),let normalized = kernels.divide?.apply(extent:decoded.extent,arguments:[decoded,scale]) else { return decoded }
        base.input = InputConversion()
        return ImageEngine.apply(normalized,recipe:base,preview:true)
    }
    static func grade(_ source:CIImage,recipe:Recipe,hdr:Bool,rangePreview:ColorRange? = nil,preview:Bool = false) -> CIImage {
        guard hdr else { return ImageEngine.apply(source,recipe:recipe,rangePreview:rangePreview,preview:preview) }
        var input = recipe.input;input.softHighlights = false
        let decoded = LogConversion.apply(source,input:input)
        guard let scale = kernels.scale?.apply(extent:decoded.extent,arguments:[decoded,decoded]),let normalized = kernels.divide?.apply(extent:decoded.extent,arguments:[decoded,scale]) else { return decoded }
        var grade = recipe;grade.input = InputConversion()
        let adjusted = ImageEngine.apply(normalized,recipe:grade,rangePreview:rangePreview,preview:preview)
        let framedScale = PhotoFraming.apply(scale,recipe:grade)
        return kernels.multiply?.apply(extent:adjusted.extent,arguments:[adjusted,framedScale]) ?? adjusted
    }
}

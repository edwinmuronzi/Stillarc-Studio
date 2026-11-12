import CoreImage
import Metal

/// Manual, dark-channel-weighted veil correction; no scene analysis or extra image blur.
enum DehazeRendering {
    private final class Compiled:@unchecked Sendable {
        let kernel:CIColorKernel?
        init() {
            let code = """
            kernel vec4 studioDehaze(__sample source, float amount) {
                vec4 p = unpremultiply(source);
                float headroom = max(1.0,max(p.r,max(p.g,p.b)));
                vec3 c = p.rgb/headroom;
                float dark = clamp(min(c.r,min(c.g,c.b)),0.0,1.0);
                float protection = 1.0-smoothstep(0.85,1.0,dark);
                float veil = amount*protection*(amount > 0.0 ? dark*0.65 : 0.18);
                vec3 result = max(vec3(0.0),(c-vec3(veil))/max(0.25,1.0-veil));
                return premultiply(vec4(result*headroom,p.a));
            }
            """
            if MTLCreateSystemDefaultDevice()?.supportsDynamicLibraries == true {
                let metal = "#include <metal_stdlib>\n#include <CoreImage/CoreImage.h>\nusing namespace metal;using namespace coreimage;\n"+code.replacingOccurrences(of:"kernel vec4",with:"[[stitchable]] float4").replacingOccurrences(of:"vec4",with:"float4").replacingOccurrences(of:"vec3",with:"float3").replacingOccurrences(of:"__sample",with:"coreimage::sample_t")
                if let value = try? CIKernel.kernels(withMetalString:metal).first as? CIColorKernel { kernel = value;return }
            }
            kernel = CIColorKernel(source:code)
        }
    }
    private static let compiled = Compiled()
    static func prepare() throws { guard compiled.kernel != nil else { throw StudioError.render } }
    static func apply(_ source:CIImage,amount:Double) -> CIImage {
        guard amount != 0 else { return source }
        return compiled.kernel?.apply(extent:source.extent,arguments:[source,amount.isFinite ? min(1,max(-1,amount)) : 0]) ?? source
    }
}

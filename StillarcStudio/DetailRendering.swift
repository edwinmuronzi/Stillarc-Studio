import CoreImage
import Metal

/// Bounded, luminance-only detail contrast. Neutral settings bypass both blurs.
enum DetailRendering {
    private final class Compiled:@unchecked Sendable {
        let kernel:CIColorKernel?
        init() {
            let code = """
            kernel vec4 studioDetail(__sample source, __sample fine, __sample broad, float texture, float clarity) {
                vec4 p = unpremultiply(source);
                vec3 weights = vec3(0.2126,0.7152,0.0722);
                float y = max(0.0,dot(p.rgb,weights));
                float a = max(0.0,dot(unpremultiply(fine).rgb,weights));
                float b = max(0.0,dot(unpremultiply(broad).rgb,weights));
                float changed = max(0.0,y+(y-a)*texture*0.7+(y-b)*clarity*0.45);
                float gain = clamp(changed/max(y,0.00001),0.25,4.0);
                return premultiply(vec4(p.rgb*gain,p.a));
            }
            """
            if MTLCreateSystemDefaultDevice()?.supportsDynamicLibraries == true {
                let metal = "#include <metal_stdlib>\n#include <CoreImage/CoreImage.h>\nusing namespace metal;using namespace coreimage;\n"+code.replacingOccurrences(of:"kernel vec4",with:"[[stitchable]] float4").replacingOccurrences(of:"vec4",with:"float4").replacingOccurrences(of:"vec3",with:"float3").replacingOccurrences(of:"__sample",with:"coreimage::sample_t")
                if let k = try? CIKernel.kernels(withMetalString:metal).first as? CIColorKernel { kernel = k;return }
            }
            kernel = CIColorKernel(source:code)
        }
    }
    private static let compiled = Compiled()
    static func prepare() throws { guard compiled.kernel != nil else { throw StudioError.render } }
    static func apply(_ source:CIImage,texture:Double,clarity:Double) -> CIImage {
        guard texture != 0 || clarity != 0 else { return source }
        let extent = source.extent,unit = max(extent.width,extent.height)/1600
        func blurred(_ radius:Double) -> CIImage { source.clampedToExtent().applyingFilter("CIGaussianBlur",parameters:[kCIInputRadiusKey:radius*unit]).cropped(to:extent) }
        let fine = texture == 0 ? source : blurred(2),broad = clarity == 0 ? source : blurred(24)
        return compiled.kernel?.apply(extent:extent,arguments:[source,fine,broad,texture,clarity]) ?? source
    }
}

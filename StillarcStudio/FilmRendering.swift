import CoreImage
import Metal

/// On-demand highlight halo and deterministic, luminance-aware monochrome grain.
enum FilmRendering {
    private final class Compiled:@unchecked Sendable {
        let highlight:CIColorKernel?
        let halo:CIColorKernel?
        let grain:CIColorKernel?
        init() {
            let code = """
            float studioFilmHash(vec2 p,float seed) { return fract(sin(dot(p,vec2(127.1,311.7))+seed*74.7)*43758.5453); }
            kernel vec4 studioFilmHighlight(__sample source) {
                vec4 p = unpremultiply(source);
                float y = max(0.0,dot(p.rgb,vec3(0.2126,0.7152,0.0722))-0.65);
                float energy = y/(1.0+y);
                return premultiply(vec4(vec3(energy),p.a));
            }
            kernel vec4 studioFilmHalo(__sample source,__sample sharp,__sample soft,float strength) {
                vec4 p = unpremultiply(source);
                if (p.a <= 0.000001) return vec4(0.0);
                float glow = max(0.0,unpremultiply(soft).r-unpremultiply(sharp).r)*strength*0.7;
                return premultiply(vec4(p.rgb+vec3(1.0,0.18,0.035)*glow,p.a));
            }
            kernel vec4 studioFilmGrain(__sample source,float amount,float cell,float seed) {
                vec4 p = unpremultiply(source);
                if (p.a <= 0.000001) return vec4(0.0);
                float y = dot(p.rgb,vec3(0.2126,0.7152,0.0722));
                if (y <= 0.000001) return source;
                vec2 q = POSITION/max(0.25,cell),i = floor(q),f = fract(q);
                f = f*f*(3.0-2.0*f);
                float n = mix(mix(studioFilmHash(i,seed),studioFilmHash(i+vec2(1.0,0.0),seed),f.x),mix(studioFilmHash(i+vec2(0.0,1.0),seed),studioFilmHash(i+vec2(1.0,1.0),seed),f.x),f.y)-0.5;
                float changed = max(0.0,y+n*amount*0.10*sqrt(y)/(1.0+y*0.8));
                return premultiply(vec4(p.rgb*(changed/y),p.a));
            }
            """
            let parts = code.components(separatedBy:"kernel vec4 ")
            func compile(_ index:Int) -> CIColorKernel? {
                guard parts.count>index else { return nil }
                let source = parts[0]+"kernel vec4 "+parts[index]
                if MTLCreateSystemDefaultDevice()?.supportsDynamicLibraries == true {
                    var metal = "#include <metal_stdlib>\n#include <CoreImage/CoreImage.h>\nusing namespace metal;using namespace coreimage;\n"+source.replacingOccurrences(of:"vec4",with:"float4").replacingOccurrences(of:"vec3",with:"float3").replacingOccurrences(of:"vec2",with:"float2").replacingOccurrences(of:"kernel float4",with:"[[stitchable]] float4").replacingOccurrences(of:"__sample",with:"coreimage::sample_t")
                    metal = metal.replacingOccurrences(of:"float cell,float seed)",with:"float cell,float seed,destination dest)").replacingOccurrences(of:"POSITION",with:"dest.coord()")
                    if let kernel = try? CIKernel.kernels(withMetalString:metal).first as? CIColorKernel { return kernel }
                }
                return CIColorKernel(source:source.replacingOccurrences(of:"POSITION",with:"destCoord()"))
            }
            highlight = compile(1);halo = compile(2);grain = compile(3)
        }
    }
    private static let compiled = Compiled()
    static func prepare() throws { guard compiled.highlight != nil,compiled.halo != nil,compiled.grain != nil else { throw StudioError.render } }
    static func apply(_ source:CIImage,recipe:Recipe) -> CIImage {
        guard recipe.halation>0 || (recipe.grain>0 && recipe.grainModel == 2) else { return source }
        let e = source.extent,unit = max(e.width,e.height)/1600
        var image = source
        if recipe.halation>0,let mask = compiled.highlight?.apply(extent:e,arguments:[source]) {
            let blur = mask.clampedToExtent().applyingFilter("CIGaussianBlur",parameters:[kCIInputRadiusKey:6*unit]).cropped(to:e)
            image = compiled.halo?.apply(extent:e,arguments:[source,mask,blur,recipe.halation]) ?? source
        }
        if recipe.grain>0 && recipe.grainModel == 2 {
            let seed = floor((MaskMotion.frame?.time ?? 0)*24)
            image = compiled.grain?.apply(extent:e,arguments:[image,recipe.grain,(0.65+recipe.grainSize*1.75)*unit,seed]) ?? image
        }
        return image
    }
}

import CoreImage

enum PhotoChromaNoise {
    private static let kernel=CIColorKernel(source:"""
    kernel vec4 studioChromaNoise(__sample original,__sample blurred,float amount) {
        vec4 a=unpremultiply(original),b=unpremultiply(blurred);
        vec3 weights=vec3(0.2126,0.7152,0.0722);
        float ya=dot(a.rgb,weights),yb=dot(b.rgb,weights);
        float edge=abs(ya-yb)/max(0.02,abs(ya));
        float weight=amount*(1.0-smoothstep(0.03,0.25,edge));
        return premultiply(vec4(mix(a.rgb,vec3(ya)+b.rgb-vec3(yb),weight),a.a));
    }
    """)
    static func apply(_ image:CIImage,amount:Double)->CIImage {
        guard amount.isFinite,amount>0 else {return image}
        let a=min(1,amount),radius=min(8,max(0.3,max(image.extent.width,image.extent.height)/1000*1.5*a))
        let blurred=image.clampedToExtent().applyingFilter("CIGaussianBlur",parameters:[kCIInputRadiusKey:radius]).cropped(to:image.extent)
        return kernel?.apply(extent:image.extent,arguments:[image,blurred,a]) ?? image
    }
}

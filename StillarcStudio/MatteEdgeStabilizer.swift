import CoreImage

/// One-frame lookahead during preparation only. Image-guided, motion-aligned
/// probability consensus suppresses single-frame contour flashes without a trailing average.
enum MatteEdgeStabilizer {
    struct Frame {let time:Double;let mask:CGImage;let source:CGImage;let box:CGRect?}
    private static let kernel=CIColorKernel(source:"""
    kernel vec4 stableMatte(__sample c, __sample p, __sample n, __sample g, __sample a, __sample b) {
        float median = max(min(c.r,p.r),min(max(c.r,p.r),n.r));
        vec3 da=abs(g.rgb-a.rgb), db=abs(g.rgb-b.rgb);
        float difference=max(max(max(da.r,da.g),da.b),max(max(db.r,db.g),db.b));
        float agreement=1.0-smoothstep(0.025,0.12,difference);
        float value=mix(c.r,median,agreement*0.85);
        return vec4(value,value,value,1.0);
    }
    """)
    static func frame(time:Double,mask:CIImage,source:CGImage,context:CIContext) throws ->Frame {
        guard let cg=context.createCGImage(mask,from:mask.extent,format:.L8,colorSpace:CGColorSpace(name:CGColorSpace.linearGray)) else {throw StudioError.render}
        let e=CGRect(x:0,y:0,width:96,height:96),small=mask.transformed(by:.init(scaleX:96/mask.extent.width,y:96/mask.extent.height))
        var pixels=[UInt8](repeating:0,count:9216);context.render(small,toBitmap:&pixels,rowBytes:96,bounds:e,format:.L8,colorSpace:CGColorSpace(name:CGColorSpace.linearGray))
        var x0=96,y0=96,x1 = -1,y1 = -1
        for y in 0..<96 {for x in 0..<96 where pixels[y*96+x]>96 {x0=min(x0,x);x1=max(x1,x);y0=min(y0,y);y1=max(y1,y)}}
        let box=x1>=x0 && y1>=y0 ? CGRect(x:Double(x0)/96,y:Double(y0)/96,width:Double(x1-x0+1)/96,height:Double(y1-y0+1)/96):nil
        return Frame(time:time,mask:cg,source:source,box:box)
    }
    static func image(previous:Frame?,current:Frame,next:Frame?)->CIImage {
        let e=CGRect(x:0,y:0,width:current.mask.width,height:current.mask.height)
        let raw=CIImage(cgImage:current.mask,options:[.colorSpace:NSNull()])
        guard let previous,let next,let cb=current.box,let pb=previous.box,let nb=next.box,
              ObjectVideoMatteTracker.overlap(cb,pb)>0.45,ObjectVideoMatteTracker.overlap(cb,nb)>0.45,
              current.time-previous.time<0.1,next.time-current.time<0.1,let kernel else {return raw}
        func aligned(_ cg:CGImage,_ from:CGRect)->CIImage {
            let normalized=CIImage(cgImage:cg,options:[.colorSpace:NSNull()]).transformed(by:.init(scaleX:1/Double(cg.width),y:1/Double(cg.height)))
            return normalized.clampedToExtent().transformed(by:.init(translationX:cb.midX-from.midX,y:cb.midY-from.midY)).transformed(by:.init(scaleX:e.width,y:e.height)).cropped(to:e)
        }
        let guide=CIImage(cgImage:current.source,options:[.colorSpace:NSNull()]).transformed(by:.init(scaleX:e.width/Double(current.source.width),y:e.height/Double(current.source.height)))
        return kernel.apply(extent:e,arguments:[raw,aligned(previous.mask,pb),aligned(next.mask,nb),guide,aligned(previous.source,pb),aligned(next.source,nb)]) ?? raw
    }
}

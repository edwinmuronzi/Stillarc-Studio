import CoreImage
import Vision

/// Landmark contours plus per-face sampled colour. A guided selection, not a semantic skin classifier.
enum FaceSelection {
    private static let skinKernel=CIColorKernel(source:"""
    kernel vec4 adaptiveSkin(__sample s, vec4 a, vec4 b, vec4 c) {
        vec3 rgb=max(s.rgb,vec3(0.0));float total=max(0.00001,rgb.r+rgb.g+rgb.b);vec2 chroma=rgb.rg/total;
        float distance=min(length(chroma-a.xy),min(length(chroma-b.xy),length(chroma-c.xy)));
        float y=dot(rgb,vec3(0.2126,0.7152,0.0722));float relative=y/max(0.0001,(a.z+b.z+c.z)/3.0);
        float weight=(1.0-smoothstep(0.065,0.20,distance))*smoothstep(0.035,0.18,relative);
        return vec4(weight,weight,weight,1.0);
    }
    """)
    static func make(_ image:CGImage,skin:Bool) throws ->CIImage {
        try Task.checkCancellation()
        let request=VNDetectFaceLandmarksRequest();request.preferBackgroundProcessing=true
        try VNImageRequestHandler(cgImage:image,orientation:.up).perform([request])
        guard let faces=request.results,!faces.isEmpty else {throw AutomaticSelectionEngine.error("No clear face was found. Try a closer photo or use a brush selection.")}
        let scale=min(1,1024/Double(max(image.width,image.height))),width=max(1,Int(Double(image.width)*scale)),height=max(1,Int(Double(image.height)*scale)),extent=CGRect(x:0,y:0,width:width,height:height)
        let source=CIImage(cgImage:image).transformed(by:.init(scaleX:Double(width)/Double(image.width),y:Double(height)/Double(image.height)))
        guard let context=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:0) else {throw StudioError.render}
        var result=CIImage(color:.black).cropped(to:extent)
        for face in faces.prefix(12) {
            try Task.checkCancellation();context.setFillColor(gray:0,alpha:1);context.fill(extent)
            let b=face.boundingBox,box=CGRect(x:b.minX*Double(width),y:b.minY*Double(height),width:b.width*Double(width),height:b.height*Double(height))
            context.setFillColor(gray:1,alpha:1)
            if let contour=face.landmarks?.faceContour,contour.pointCount>=6 {
                var points=(0..<contour.pointCount).map {i in CGPoint(x:box.minX+Double(contour.normalizedPoints[i].x)*box.width,y:box.minY+Double(contour.normalizedPoints[i].y)*box.height)}
                points += [CGPoint(x:box.minX+box.width*0.2,y:box.minY+box.height*0.94),CGPoint(x:box.minX+box.width*0.8,y:box.minY+box.height*0.94)]
                let center=CGPoint(x:box.midX,y:box.midY)
                points.sort {atan2($0.y-center.y,$0.x-center.x)<atan2($1.y-center.y,$1.x-center.x)}
                let path=CGMutablePath();path.addLines(between:points);path.closeSubpath();context.addPath(path);context.fillPath()
            } else {context.fillEllipse(in:box.insetBy(dx:box.width*(skin ? 0.08:0),dy:box.height*(skin ? 0.04:0)))}
            if skin,let landmarks=face.landmarks {
                context.setFillColor(gray:0,alpha:1)
                for region in [landmarks.leftEye,landmarks.rightEye,landmarks.leftEyebrow,landmarks.rightEyebrow,landmarks.outerLips].compactMap({$0}) {
                    guard region.pointCount>=2 else {continue}
                    let points=(0..<region.pointCount).map {i in CGPoint(x:box.minX+Double(region.normalizedPoints[i].x)*box.width,y:box.minY+Double(region.normalizedPoints[i].y)*box.height)}
                    let cx=points.map(\.x).reduce(0,+)/Double(points.count),cy=points.map(\.y).reduce(0,+)/Double(points.count)
                    let path=CGMutablePath();path.addLines(between:points.map {CGPoint(x:cx+($0.x-cx)*1.25,y:cy+($0.y-cy)*1.5)});path.closeSubpath();context.addPath(path);context.fillPath()
                }
            }
            guard let cg=context.makeImage() else {throw StudioError.render};var guide=CIImage(cgImage:cg,options:[.colorSpace:NSNull()])
            if skin,let skinKernel {
                func sample(_ u:Double,_ v:Double)->CIVector {
                    let area=CGRect(x:box.minX+box.width*(u-0.04),y:box.minY+box.height*(v-0.04),width:box.width*0.08,height:box.height*0.08).intersection(extent)
                    var p=[Float](repeating:0,count:4)
                    ImageEngine.context().render(source.applyingFilter("CIAreaAverage",parameters:["inputExtent":CIVector(cgRect:area)]),toBitmap:&p,rowBytes:16,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working)
                    let r=max(0,Double(p[0])),g=max(0,Double(p[1])),b=max(0,Double(p[2])),sum=max(0.00001,r+g+b)
                    return CIVector(x:r/sum,y:g/sum,z:0.2126*r+0.7152*g+0.0722*b,w:1)
                }
                if let color=skinKernel.apply(extent:extent,arguments:[source,sample(0.3,0.45),sample(0.7,0.45),sample(0.5,0.75)]) {guide=guide.applyingFilter("CIMultiplyCompositing",parameters:[kCIInputBackgroundImageKey:color])}
            }
            result=result.applyingFilter("CIMaximumCompositing",parameters:[kCIInputBackgroundImageKey:guide])
        }
        return result.clampedToExtent().applyingFilter("CIGaussianBlur",parameters:[kCIInputRadiusKey:Double(max(width,height))*0.002]).cropped(to:extent)
    }
}

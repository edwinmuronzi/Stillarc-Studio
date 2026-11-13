import CoreImage
import Vision

/// A face-landmark guided starting selection, not a semantic skin classifier.
enum FaceSelection {
    static func make(_ image:CGImage,skin:Bool) throws ->CIImage {
        try Task.checkCancellation()
        let request=VNDetectFaceLandmarksRequest();request.preferBackgroundProcessing=true
        try VNImageRequestHandler(cgImage:image,orientation:.up).perform([request])
        guard let faces=request.results,!faces.isEmpty else {throw AutomaticSelectionEngine.error("No clear face was found. Try a closer photo or use a brush selection.")}
        let scale=min(1,1024/Double(max(image.width,image.height))),width=max(1,Int(Double(image.width)*scale)),height=max(1,Int(Double(image.height)*scale))
        guard let context=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:0) else {throw StudioError.render}
        context.setFillColor(gray:0,alpha:1);context.fill(CGRect(x:0,y:0,width:width,height:height))
        for face in faces.prefix(12) {
            try Task.checkCancellation()
            let b=face.boundingBox,box=CGRect(x:b.minX*Double(width),y:b.minY*Double(height),width:b.width*Double(width),height:b.height*Double(height))
            context.setFillColor(gray:1,alpha:1)
            context.fillEllipse(in:box.insetBy(dx:box.width*(skin ? 0.08:0),dy:box.height*(skin ? 0.04:0)))
            if skin,let landmarks=face.landmarks {
                context.setFillColor(gray:0,alpha:1)
                for region in [landmarks.leftEye,landmarks.rightEye,landmarks.leftEyebrow,landmarks.rightEyebrow,landmarks.outerLips].compactMap({$0}) {
                    guard region.pointCount>=2 else {continue}
                    let points=(0..<region.pointCount).map {i in CGPoint(x:box.minX+Double(region.normalizedPoints[i].x)*box.width,y:box.minY+Double(region.normalizedPoints[i].y)*box.height)}
                    let cx=points.map(\.x).reduce(0,+)/Double(points.count),cy=points.map(\.y).reduce(0,+)/Double(points.count)
                    let path=CGMutablePath();path.addLines(between:points.map {CGPoint(x:cx+($0.x-cx)*1.25,y:cy+($0.y-cy)*1.5)});path.closeSubpath()
                    context.addPath(path);context.fillPath()
                }
            }
        }
        guard let cg=context.makeImage() else {throw StudioError.render}
        return CIImage(cgImage:cg,options:[.colorSpace:NSNull()]).clampedToExtent().applyingFilter("CIGaussianBlur",parameters:[kCIInputRadiusKey:Double(max(width,height))*0.003]).cropped(to:CGRect(x:0,y:0,width:width,height:height))
    }
}

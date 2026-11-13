import CoreImage
import Foundation

enum SamplingStage {case whiteBalance,levels}
enum PointSampleTool:String,CaseIterable,Identifiable {
    case whiteBalance,blackPoint,whitePoint
    var id:String {rawValue}
    var title:String {switch self {case .whiteBalance:"White balance picker";case .blackPoint:"Pick black point";case .whitePoint:"Pick white point"}}
    var stage:SamplingStage {self == .whiteBalance ? .whiteBalance:.levels}
}
enum PointSampling {
    struct Result:Sendable {var warmth:Double?;var tint:Double?;var black:Double?;var white:Double?}
    static func failure(_ text:String)->NSError {NSError(domain:"PointSample",code:1,userInfo:[NSLocalizedDescriptionKey:text])}
    static func reference(_ source:CIImage,recipe:Recipe,stage:SamplingStage,hdr:Bool)->CIImage {
        var r=recipe;r.masks=[];r.background=nil
        if !hdr {return ImageEngine.apply(source,recipe:r,stopBefore:stage)}
        return HDRPipeline.samplingReference(source,recipe:r,stage:stage)
    }
    static func mean(_ image:CIImage,point:CGPoint)->[Double] {
        let e=image.extent
        let x=e.minX+min(1,max(0,point.x))*e.width,y=e.maxY-min(1,max(0,point.y))*e.height
        let radius=min(12,max(2,max(e.width,e.height)*0.006))
        let patch=CGRect(x:x-radius,y:y-radius,width:radius*2,height:radius*2).intersection(e)
        let average=image.applyingFilter("CIAreaAverage",parameters:["inputExtent":CIVector(cgRect:patch)])
        var p=[Float](repeating:0,count:4)
        ImageEngine.context().render(average,toBitmap:&p,rowBytes:16,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working)
        return p.map(Double.init)
    }
    static func solve(_ p:[Double],tool:PointSampleTool,recipe:Recipe) throws ->Result {
        try Task.checkCancellation()
        guard p.count==4,p.allSatisfy(\.isFinite),p[3]>=0.98 else {throw failure("Choose an opaque area inside the image.")}
        let rgb=p.prefix(3).map {$0/p[3]}
        if tool == .whiteBalance {
            guard rgb.min()!>0.004,rgb.max()!<0.98,rgb.max()!/rgb.min()!<4 else {throw failure("Choose a mid-brightness grey or white area, away from clipped highlights and deep shadows.")}
            let source=CIImage(color:CIColor(red:rgb[0],green:rgb[1],blue:rgb[2],colorSpace:ImageEngine.working)!).cropped(to:CGRect(x:0,y:0,width:8,height:8))
            let context=ImageEngine.context()
            func error(_ w:Double,_ t:Double)->(Double,Double) {
                let image=source.applyingFilter("CITemperatureAndTint",parameters:["inputNeutral":CIVector(x:6500,y:0),"inputTargetNeutral":CIVector(x:6500+w*2400,y:t*100)])
                var out=[Float](repeating:0,count:4)
                context.render(image,toBitmap:&out,rowBytes:16,bounds:CGRect(x:1,y:1,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working)
                let green=max(1e-6,Double(out[1]))
                return (log(max(1e-6,Double(out[0]))/green),log(max(1e-6,Double(out[2]))/green))
            }
            var w=recipe.warmth,t=recipe.tint
            for _ in 0..<10 {
                try Task.checkCancellation()
                let e=error(w,t)
                if max(abs(e.0),abs(e.1))<0.012 {break}
                // Temperature matrices are internally quantized; tiny forward differences can be zero.
                let wp=error(w+0.1,t),wm=error(w-0.1,t),tp=error(w,t+0.02),tm=error(w,t-0.02)
                let a=(wp.0-wm.0)/0.2,b=(tp.0-tm.0)/0.04,c=(wp.1-wm.1)/0.2,d=(tp.1-tm.1)/0.04,det=a*d-b*c
                guard det.isFinite,abs(det)>1e-8 else {throw failure("This area cannot provide a reliable white balance. Try a different neutral area.")}
                w=min(1,max(-1,w-min(0.5,max(-0.5,(d*e.0-b*e.1)/det))))
                t=min(1,max(-1,t-min(0.5,max(-0.5,(-c*e.0+a*e.1)/det))))
            }
            let e=error(w,t)
            guard w.isFinite,t.isFinite,max(abs(e.0),abs(e.1))<0.02 else {throw failure("This colour is outside the Warmth/Tint adjustment range. Try a more neutral area.")}
            return Result(warmth:w,tint:t)
        }
        let peak=max(1,rgb.max()!),tone=(0.2126*rgb[0]+0.7152*rgb[1]+0.0722*rgb[2])/peak
        guard tone.isFinite else {throw failure("Choose another area.")}
        if tool == .blackPoint {
            let black=min(0.95,max(0,tone))
            guard black<=recipe.levelWhite-0.01 else {throw failure("The black point must be darker than the white point. Choose a darker area or reset Levels.")}
            return Result(black:black)
        }
        let white=min(1,max(0.05,tone))
        guard white>=recipe.levelBlack+0.01 else {throw failure("The white point must be brighter than the black point. Choose a brighter area or reset Levels.")}
        return Result(white:white)
    }
    static func apply(_ result:Result,to recipe:inout Recipe) {
        if let v=result.warmth {recipe.warmth=v};if let v=result.tint {recipe.tint=v}
        if let v=result.black {recipe.levelBlack=v};if let v=result.white {recipe.levelWhite=v}
    }
}

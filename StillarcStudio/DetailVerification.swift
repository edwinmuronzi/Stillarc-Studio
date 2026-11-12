#if DEBUG
import CoreImage
import Foundation

enum DetailVerification {
    static func run() throws -> [String:Any] {
        func check(_ v:Bool,_ text:String) throws { if !v { throw NSError(domain:"DetailQA",code:1,userInfo:[NSLocalizedDescriptionKey:text]) } }
        try DetailRendering.prepare()
        let context = ImageEngine.context(),rect = CGRect(x:0,y:0,width:1600,height:900)
        let low = CIColor(red:0.2,green:0.2,blue:0.2,alpha:1,colorSpace:ImageEngine.working)!,high = CIColor(red:0.4,green:0.4,blue:0.4,alpha:1,colorSpace:ImageEngine.working)!
        let pattern = CIFilter(name:"CICheckerboardGenerator",parameters:["inputColor0":low,"inputColor1":high,"inputWidth":8])!.outputImage!.cropped(to:rect)
        func pixels(_ image:CIImage,_ x:Int,_ y:Int) -> [Float] { var p = [Float](repeating:0,count:4);context.render(image,toBitmap:&p,rowBytes:16,bounds:CGRect(x:x,y:y,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p }
        let p = pixels(pattern,803,452)[0],neutral = DetailRendering.apply(pattern,texture:0,clarity:0)
        try check(neutral === pattern,"Neutral detail did not bypass filters")
        let more = pixels(DetailRendering.apply(pattern,texture:1,clarity:0),803,452)[0],less = pixels(DetailRendering.apply(pattern,texture:-1,clarity:0),803,452)[0]
        try check(abs(more-p)>0.005 && abs(less-p)>0.005 && (more-p)*(less-p)<0,"Texture controls did not change fine contrast in both directions")
        let clear = pixels(DetailRendering.apply(pattern,texture:0,clarity:1),803,452)[0]
        try check(abs(clear-p)>0.005,"Clarity did not affect broad contrast")
        let hdr = CIImage(color:CIColor(red:4,green:2,blue:1,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:rect)
        let values = pixels(DetailRendering.apply(hdr,texture:1,clarity:1),800,450)
        try check(abs(values[0]-4)<0.02 && abs(values[1]-2)<0.02 && values[3]>0.99,"Uniform HDR colors/alpha changed or clipped")
        let large = pattern.transformed(by:.init(scaleX:2,y:2))
        let doubled = pixels(DetailRendering.apply(large,texture:0.7,clarity:0.4),1606,904)[0]
        let small = pixels(DetailRendering.apply(pattern,texture:0.7,clarity:0.4),803,452)[0]
        try check(abs(doubled-small)<0.03,"Preview/export detail scale mismatch")
        var r = Recipe();r.texture = 0.6;r.clarity = -0.3
        try check(r.hasAdjustments(in:.detail),"Detail indicator")
        let saved = try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(r));try check(saved == r,"Detail persistence")
        let pasted = Recipe().pasting(r,sections:[.detail]);try check(pasted.texture == 0.6 && pasted.clarity == -0.3,"Detail copy/paste")
        r.reset(.detail);try check(!r.hasAdjustments(in:.detail),"Detail reset")
        let legacy = try JSONDecoder().decode(Recipe.self,from:Data("{}".utf8));try check(legacy.texture == 0 && legacy.clarity == 0,"Legacy detail defaults")
        return ["passed":true,"bothDirections":true,"neutralBypass":true,"hdrHeadroom":true,"resolutionScale":true,"persistenceAndCopyPaste":true,"legacyDefaults":true]
    }
}
#endif

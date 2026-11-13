#if DEBUG
import Foundation
import CoreImage

enum OneDLUTVerification {
    static func example(dimension:Int=1024) throws ->LUTAsset {
        var text="TITLE \"1D gentle contrast\"\nLUT_1D_SIZE \(dimension)\n"
        for i in 0..<dimension {let x=Double(i)/Double(dimension-1);text+="\(pow(x,0.94)) \(x) \(x*0.96)\n"}
        return try LUTAsset.parse(text,name:"1D example")
    }
    static func run() async throws ->[String:Any] {
        func check(_ b:Bool,_ s:String) throws {if !b {throw NSError(domain:"OneDLUTQA",code:1,userInfo:[NSLocalizedDescriptionKey:s])}}
        _ = try LUTVerification.run()
        let context=ImageEngine.context()
        func image(_ rgb:[Double],alpha:Double=1)->CIImage {CIImage(color:CIColor(red:rgb[0],green:rgb[1],blue:rgb[2],alpha:alpha,colorSpace:ImageEngine.output)!).cropped(to:CGRect(x:0,y:0,width:8,height:8))}
        func pixel(_ image:CIImage)->[Float] {var v=[Float](repeating:0,count:4);context.render(image,toBitmap:&v,rowBytes:16,bounds:CGRect(x:1,y:1,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.output);return v}
        let rows:[[Double]]=[[0,0,0.1],[0.2,0.1,0.3],[0.8,0.4,0.2],[0.6,0.9,0.5],[1,1,0.9]]
        let text="LUT_1D_SIZE 5\n"+rows.map {$0.map {String($0)}.joined(separator:" ")}.joined(separator:"\n")
        let lut=try LUTAsset.parse(text,name:"Independent channels")
        func value(_ x:Double,_ channel:Int)->Double {let scaled=min(1,max(0,x))*4,i=min(3,Int(scaled)),t=scaled-Double(i);return rows[i][channel]*(1-t)+rows[i+1][channel]*t}
        var vectors=0,maxError=0.0
        for i in 0...32 {
            let rgb=[Double(i)/32,Double(32-i)/32,Double((i*7)%33)/32]
            let result=pixel(lut.apply(image(rgb),amount:1))
            for c in 0..<3 {let error=abs(Double(result[c])-value(rgb[c],c));maxError=max(maxError,error);try check(error<0.003,"1D interpolation/channel mapping \(rgb) \(result) \(error)")}
            vectors+=1
        }
        let source=image([0.3,0.5,0.7]),before=pixel(source)
        try check(lut.apply(source,amount:0) === source,"Zero strength not bypassed")
        let half=pixel(lut.apply(source,amount:0.5)),reference=pixel(source.applyingFilter("CIDissolveTransition",parameters:[kCIInputTargetImageKey:lut.apply(source,amount:1),kCIInputTimeKey:0.5]))
        try check(zip(half,reference).allSatisfy {abs($0-$1)<0.001},"1D strength not linear-light blend")
        let alpha=pixel(lut.apply(image([0.3,0.5,0.7],alpha:0.4),amount:1))
        for c in 0..<3 {try check(abs(Double(alpha[c])-value([0.3,0.5,0.7][c],c)*0.4)<0.004,"1D alpha")}
        try check(abs(alpha[3]-0.4)<0.001,"Alpha changed")
        let domain=try LUTAsset.parse("LUT_1D_SIZE 2\nDOMAIN_MIN 0.1 0.2 0.3\nDOMAIN_MAX 0.9 0.8 0.7\n0 0 0\n1 1 1\n",name:"Domain")
        let range=try LUTAsset.parse("TITLE \"Range #1\" # comment\nLUT_1D_INPUT_RANGE 0.1 0.9\nLUT_1D_SIZE 2\n0 0 0\n1 1 1\n",name:"Range")
        let rangePixel=pixel(range.apply(image([0.3,0.5,0.7]),amount:1))
        try check(range.name=="Range #1" && zip(rangePixel,[Float(0.25),0.5,0.75,1]).allSatisfy {abs($0-$1)<0.004},"Range header or quoted comment")
        let mapped=pixel(domain.apply(image([0.3,0.5,0.6]),amount:1))
        try check(zip(mapped,[Float(0.25),0.5,0.75,1]).allSatisfy {abs($0-$1)<0.004},"1D per-channel domains")
        let edges=pixel(domain.apply(image([0,0.5,1]),amount:1));try check(abs(edges[0])<0.003 && abs(edges[2]-1)<0.003,"1D endpoint clamping")
        for n in [2,4096] {let asset=try example(dimension:n);let output=pixel(asset.apply(source,amount:1));try check(output.allSatisfy(\.isFinite) && output[2]<before[2],"1D supported size \(n)")}
        for invalid in ["LUT_1D_SIZE 1\n0 0 0","LUT_1D_SIZE 4097\n0 0 0","LUT_1D_SIZE 2\n0 0 0","LUT_1D_SIZE 2\n0 0 0\n1 1 1\n2 2 2","LUT_1D_SIZE 2\nLUT_3D_SIZE 2\n0 0 0","LUT_1D_SIZE 2\nLUT_3D_INPUT_RANGE 0 1\n0 0 0\n1 1 1","LUT_1D_SIZE 2\nLUT_1D_INPUT_RANGE 0 1\nDOMAIN_MIN 0 0 0\n0 0 0\n1 1 1","LUT_1D_SIZE 2\nNaN 0 0\n1 1 1","LUT_1D_SIZE 2\nDOMAIN_MIN 1 1 1\nDOMAIN_MAX 0 0 0\n0 0 0\n1 1 1"] {
            do {_ = try LUTAsset.parse(invalid,name:"Bad");throw NSError(domain:"OneDLUTQA",code:2,userInfo:[NSLocalizedDescriptionKey:"Invalid 1D LUT accepted"])} catch is LUTError {}
        }
        let three=try LUTVerification.example()
        let old=try JSONSerialization.jsonObject(with:JSONEncoder().encode(three)) as! [String:Any];var oldFields=old;oldFields.removeValue(forKey:"kind")
        let legacy=try JSONDecoder().decode(LUTAsset.self,from:JSONSerialization.data(withJSONObject:oldFields))
        try check(legacy==three && legacy.kind == .cube3D && legacy.fingerprint==three.fingerprint,"Legacy 3D identity changed")
        let decoded=try JSONDecoder().decode(LUTAsset.self,from:JSONEncoder().encode(lut));try check(decoded==lut && decoded.kind == .curve1D,"1D persistence")
        let written=try ColorLUTExport.write(lut);defer {try? FileManager.default.removeItem(at:written.deletingLastPathComponent())}
        try check(try LUTAsset.read(written)==lut,"1D text roundtrip")
        var recipe=Recipe();recipe.lut=lut;recipe.lutAmount=0.7;recipe.lutLayers=[LUTLayer(asset:three,amount:0.3)]
        let direct=three.apply(lut.apply(source,amount:0.7),amount:0.3)
        try check(zip(pixel(direct),pixel(ImageEngine.apply(source,recipe:recipe))).allSatisfy {abs($0-$1)<0.001},"Mixed stack order")
        let preset=PresetDocument(name:"1D preset",recipe:recipe.colorPreset)
        try check(preset.schema==7,"1D preset schema")
        let package=LookLibraryPackage(entries:[LookLibraryEntry(id:UUID(),preset:preset,organization:nil)])
        let reopened=try JSONDecoder().decode(LookLibraryPackage.self,from:JSONEncoder().encode(package)).validated()
        try check(reopened.first?.recipe==recipe.colorPreset,"1D look library package")
        let transfer=Recipe().pasting(recipe,sections:[.lut]);try check(transfer.lut==lut && transfer.lutLayers==recipe.lutLayers,"Copy/paste 1D stack")
        let baked=try ColorLUTExport.make(recipe:recipe,dimension:65,name:"Mixed baked")
        try check(zip(pixel(baked.apply(source,amount:1)),pixel(direct)).allSatisfy {abs($0-$1)<0.015},"Mixed colour LUT export")
        return ["passed":true,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","vectors":vectors,"maxInterpolationError":maxError,"domainsAndClamping":true,"rangeHeadersAndQuotedTitles":true,"alphaStrength":true,"max4096":true,"legacy3DPreserved":true,"mixedStackAndColorExport":true,"presetLibraryTransfer":true,"malformedRejected":true]
    }
    @MainActor static func writeReport() async {
        let url=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("one-d-lut-verification.json")
        do {let report=try await Task.detached(priority:.utility){try await run()}.value;try JSONSerialization.data(withJSONObject:report,options:.prettyPrinted).write(to:url,options:.atomic)}
        catch {try? JSONSerialization.data(withJSONObject:["passed":false,"version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "unknown","error":error.localizedDescription],options:.prettyPrinted).write(to:url,options:.atomic)}
    }
}
#endif

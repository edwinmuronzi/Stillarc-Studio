#if DEBUG
import Foundation
import CoreImage

enum CombinedLUTVerification {
    static func example(one:Int=1024,three:Int=33) throws ->LUTAsset {
        var text="TITLE \"Combined gentle look\"\nLUT_1D_SIZE \(one)\nLUT_1D_INPUT_RANGE 0 1\nLUT_3D_SIZE \(three)\nLUT_3D_INPUT_RANGE 0 1\n"
        for i in 0..<one {let x=Double(i)/Double(one-1);text+="\(pow(x,0.94)) \(x) \(x*0.96)\n"}
        for b in 0..<three {for g in 0..<three {for r in 0..<three {
            let x=Double(r)/Double(three-1),y=Double(g)/Double(three-1),z=Double(b)/Double(three-1)
            text+="\(x*0.98+y*0.02) \(y*0.98+z*0.02) \(z*0.98+x*0.02)\n"
        }}}
        return try LUTAsset.parse(text,name:"Combined gentle look")
    }
    static func run() throws ->[String:Any] {
        func check(_ value:Bool,_ message:String) throws {if !value {throw NSError(domain:"CombinedLUTQA",code:1,userInfo:[NSLocalizedDescriptionKey:message])}}
        let context=ImageEngine.context()
        func image(_ rgb:[Double],_ alpha:Double=1)->CIImage {CIImage(color:CIColor(red:rgb[0],green:rgb[1],blue:rgb[2],alpha:alpha,colorSpace:ImageEngine.output)!).cropped(to:CGRect(x:0,y:0,width:8,height:8))}
        func pixel(_ image:CIImage)->[Float] {var p=[Float](repeating:0,count:4);context.render(image,toBitmap:&p,rowBytes:16,bounds:CGRect(x:1,y:1,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.output);return p}
        let rows:[[Double]]=[[0.2,0.2,0.2],[0.275,0.35,0.3125],[0.5,0.5,0.5],[0.725,0.65,0.6875],[0.8,0.8,0.8]]
        let header="TITLE \"Shaper # test\"\nLUT_1D_SIZE 5\nLUT_1D_INPUT_RANGE 0.1 0.9\nLUT_3D_SIZE 3\nLUT_3D_INPUT_RANGE 0.2 0.8\n"
        var table=rows.map {$0.map {String($0)}.joined(separator:" ")}.joined(separator:"\n")+"\n"
        for b in 0..<3 {for g in 0..<3 {for r in 0..<3 {let x=Double(r)/2,y=Double(g)/2,z=Double(b)/2;table+="\(y) \(0.5*x+0.25*z) \(1-z)\n"}}}
        let lut=try LUTAsset.parse(header+table,name:"Combined")
        try check(lut.shaper?.dimension==5 && lut.dimension==3 && lut.detail.contains("1D + 3D"),"Combined type details")
        func shape(_ x:Double,_ c:Int)->Double {let v=min(1,max(0,(x-0.1)/0.8))*4,i=min(3,Int(v)),f=v-Double(i);return min(1,max(0,(rows[i][c]*(1-f)+rows[i+1][c]*f-0.2)/0.6))}
        var maxError=0.0
        for i in 0...32 {
            let rgb=[Double(i)/32,Double(32-i)/32,Double((i*7)%33)/32],a=shape(rgb[0],0),b=shape(rgb[1],1),c=shape(rgb[2],2)
            let expected=[b,0.5*a+0.25*c,1-c,1],result=pixel(lut.apply(image(rgb),amount:1))
            for j in 0..<4 {maxError=max(maxError,abs(Double(result[j])-expected[j]))}
        }
        try check(maxError<0.004,"Separate domains / stage order / transfers: \(maxError)")
        let source=image([0.3,0.5,0.7]),full=lut.apply(source,amount:1)
        try check(lut.apply(source,amount:0) === source,"Combined bypass")
        let half=pixel(lut.apply(source,amount:0.5)),expectedHalf=pixel(source.applyingFilter("CIDissolveTransition",parameters:[kCIInputTargetImageKey:full,kCIInputTimeKey:0.5]))
        try check(zip(half,expectedHalf).allSatisfy {abs($0-$1)<0.001},"Combined strength applied twice")
        let alpha=pixel(lut.apply(image([0.3,0.5,0.7],0.4),amount:1)),opaque=pixel(full)
        try check(abs(alpha[3]-0.4)<0.001 && (0..<3).allSatisfy {abs(alpha[$0]-opaque[$0]*0.4)<0.004},"Combined alpha")
        let decoded=try JSONDecoder().decode(LUTAsset.self,from:JSONEncoder().encode(lut));try check(decoded==lut && decoded.shaper != nil,"Combined persistence")
        let bare=try LUTAsset(name:lut.name,dimension:lut.dimension,domainMin:lut.domainMin,domainMax:lut.domainMax,cube:lut.cube)
        try check(bare.fingerprint != lut.fingerprint,"Shaper missing from identity")
        let written=try ColorLUTExport.write(lut);defer {try? FileManager.default.removeItem(at:written.deletingLastPathComponent())}
        try check(try LUTAsset.read(written)==lut,"Combined text round trip")
        let dense=try example(one:4096,three:2),denseFile=try ColorLUTExport.write(dense)
        defer {try? FileManager.default.removeItem(at:denseFile.deletingLastPathComponent())}
        try check(try LUTAsset.read(denseFile)==dense,"4096-sample text precision")
        var recipe=Recipe();recipe.lut=lut;recipe.lutAmount=0.7
        let preset=PresetDocument(name:"Combined",recipe:recipe.colorPreset)
        try check(preset.schema==8,"Combined preset reader protection")
        let package=LookLibraryPackage(entries:[LookLibraryEntry(id:UUID(),preset:preset,organization:nil)])
        let reopened=try JSONDecoder().decode(LookLibraryPackage.self,from:JSONEncoder().encode(package)).validated()
        try check(reopened.first?.recipe.lut==lut && Recipe().pasting(recipe,sections:[.lut]).lut==lut,"Library/copy-paste")
        let baked=try ColorLUTExport.make(recipe:recipe,dimension:65,name:"Combined baked")
        try check(zip(pixel(baked.apply(source,amount:1)),pixel(lut.apply(source,amount:0.7))).allSatisfy {abs($0-$1)<0.015},"Combined colour-only export")
        var invalidFiles=[String]()
        invalidFiles.append(header+table+"0 0 0\n")
        invalidFiles.append(header+String(table.dropLast(8)))
        invalidFiles.append(header+"LUT_1D_SIZE 5\n"+table)
        invalidFiles.append(header.replacingOccurrences(of:"0.1 0.9",with:"0.9 0.1")+table)
        for extra in ["DOMAIN_MIN 0 0 0\n","LUT_2D_SIZE 5\n","NaN 0 0\n"] {invalidFiles.append(header+extra+table)}
        for invalid in invalidFiles {
            do {_ = try LUTAsset.parse(invalid,name:"Invalid");throw NSError(domain:"CombinedLUTQA",code:2,userInfo:[NSLocalizedDescriptionKey:"Malformed combined LUT accepted"])} catch is LUTError {}
        }
        let tiny="LUT_1D_SIZE 2\nLUT_3D_SIZE 2\n0 0 0\n1 1 1\n"+(0..<8).map {"\($0%2) \(($0/2)%2) \($0/4)\n"}.joined()
        let defaults=try LUTAsset.parse(tiny,name:"Defaults");try check(defaults.shaper?.domainMin == [0,0,0] && defaults.domainMax == [1,1,1],"Default ranges")
        do {_ = try LUTAsset.parse("DOMAIN_MIN 0 0 0\n"+tiny,name:"Ambiguous");throw NSError(domain:"CombinedLUTQA",code:3)} catch LUTError.ambiguousDomain {}
        return ["passed":true,"vectors":33,"maxError":maxError,"alphaStrengthBypass":true,"separateDomains":true,"identityPersistence":true,"presetLibraryTransfer":true,"textRoundtripAndBake":true,"malformedRejected":true]
    }
}
#endif

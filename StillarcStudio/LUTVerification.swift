#if DEBUG
import Foundation
import CoreImage

enum LUTVerification {
    static func example(dimension: Int = 33) throws -> LUTAsset {
        var values = [Float](); values.reserveCapacity(dimension*dimension*dimension*4)
        for b in 0..<dimension { for g in 0..<dimension { for r in 0..<dimension {
            let red = Float(r)/Float(dimension-1), green = Float(g)/Float(dimension-1), blue = Float(b)/Float(dimension-1)
            values += [red*0.95+green*0.05,green*0.97+blue*0.03,blue*0.9+red*0.02,1]
        } } }
        return try values.withUnsafeBytes { try LUTAsset(name:"Studio cool · test LUT",dimension:dimension,domainMin:[0,0,0],domainMax:[1,1,1],cube:Data($0)) }
    }
    static func run() throws -> [String:Any] {
        func require(_ value: Bool,_ text: String) throws { if !value { throw NSError(domain:"LUTVerification",code:1,userInfo:[NSLocalizedDescriptionKey:text]) } }
        let context = ImageEngine.context()
        func image(_ rgb:[CGFloat], alpha:CGFloat = 1) -> CIImage { CIImage(color:CIColor(red:rgb[0],green:rgb[1],blue:rgb[2],alpha:alpha,colorSpace:ImageEngine.output)!).cropped(to:CGRect(x:0,y:0,width:4,height:4)) }
        func pixel(_ image: CIImage) -> [Float] { var data = [Float](repeating:0,count:4); context.render(image,toBitmap:&data,rowBytes:16,bounds:CGRect(x:1,y:1,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.output); return data }
        func near(_ a:[Float],_ b:[Float],tolerance:Float = 0.008) -> Bool { zip(a,b).allSatisfy { abs($0-$1)<tolerance } }
        let header = "# LUT test\nTITLE \"Test LUT\"\nLUT_3D_SIZE 2\n"
        var rows = "", swapRows = ""
        for b in 0...1 { for g in 0...1 { for r in 0...1 { rows += "\(r) \(g) \(b)\n"; swapRows += "\(b) \(g) \(r)\n" } } }
        let identity = try LUTAsset.parse(header+rows,name:"fallback"), swap = try LUTAsset.parse(header+swapRows,name:"fallback")
        let source = image([0.23,0.47,0.71]), before = pixel(source)
        try require(identity.name == "Test LUT" && near(pixel(identity.apply(source,amount:1)),before),"Identity LUT or sRGB transfer failed")
        let expected:[Float] = [before[2],before[1],before[0],before[3]]
        try require(near(pixel(swap.apply(source,amount:1)),expected),"LUT channel ordering or encoded color mapping failed")
        try require(swap.apply(source,amount:0) === source,"Zero LUT strength did not bypass work")
        let half = pixel(swap.apply(source,amount:0.5))
        let reference = pixel(source.applyingFilter("CIDissolveTransition",parameters:[kCIInputTargetImageKey:image([0.71,0.47,0.23]),kCIInputTimeKey:0.5]))
        try require(near(half,reference),"LUT strength is not a linear-light blend")
        let semi = image([0.23,0.47,0.71],alpha:0.4)
        try require(near(pixel(swap.apply(semi,amount:1)),[0.71*0.4,0.47*0.4,0.23*0.4,0.4],tolerance:0.01),"LUT changed transparent colors or alpha")
        let domain = try LUTAsset.parse(header+"DOMAIN_MIN 0.1 0.1 0.1\nDOMAIN_MAX 0.9 0.9 0.9\n"+rows,name:"domain")
        try require(near(pixel(domain.apply(image([0.3,0.5,0.7]),amount:1)),[0.25,0.5,0.75,1]),"LUT domain normalization failed")
        let clamp = pixel(identity.apply(image([0,0.5,1]),amount:1))
        try require(near(clamp,[0,0.5,1,1]),"LUT endpoints changed")
        let fixtures = ["LUT_1D_SIZE 2\n0 0 0\n1 1 1", "LUT_3D_SIZE 66\n",header+rows+"0 0 0",header+"NaN 0 0\n"+rows,header+rows+"DOMAIN_MIN 0 0 0",header+"DOMAIN_MIN 1 0 0\nDOMAIN_MAX 0 1 1\n"+rows,header+"DOMAIN_MIN 0 0 0\nDOMAIN_MAX 0 1 1\n"+rows,header+"LUT_1D_SIZE 2\n"+rows,header+String(rows.dropLast(6)),header+"BOGUS 1\n"+rows,"LUT_3D_SIZE 1\n0 0 0"]
        for text in fixtures {
            do { _ = try LUTAsset.parse(text,name:"bad"); throw NSError(domain:"LUTVerification",code:2,userInfo:[NSLocalizedDescriptionKey:"Malformed LUT accepted"]) }
            catch is LUTError {} // Other failures must propagate.
        }
        let large = try example(dimension:65)
        var recipe = Recipe(); recipe.lut = large; recipe.lutAmount = 0.63; recipe.crop = .square
        let preset = PresetDocument(name:"Portable LUT",recipe:recipe.colorPreset)
        let encoded = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(PresetDocument.self,from:encoded)
        try require(decoded.schema == 2 && decoded.recipe.lut == large && decoded.recipe.lutAmount == 0.63 && decoded.recipe.crop == .original,"Embedded LUT preset lost content or included framing")
        try require(encoded.count < 8_000_000,"65-point LUT preset exceeds import bound")
        try require(recipe.hasAdjustments(in:.film),"LUT did not activate Film dot")
        var off = Recipe(); off.lut = swap; off.lutAmount = 0
        try require(!off.hasAdjustments(in:.film),"Zero LUT strength activates Film dot")
        var reset = recipe; reset.reset(.film)
        try require(reset.lut == nil && reset.lutAmount == 1 && reset.crop == .square,"Film reset did not isolate LUT and framing")
        var malformed = try JSONSerialization.jsonObject(with:JSONEncoder().encode(swap)) as! [String:Any]
        malformed["cube"] = Data(repeating:0,count:16).base64EncodedString()
        do { _ = try JSONDecoder().decode(LUTAsset.self,from:JSONSerialization.data(withJSONObject:malformed)); throw NSError(domain:"LUTVerification",code:3,userInfo:[NSLocalizedDescriptionKey:"Malformed embedded cube accepted"]) } catch is LUTError {}
        var active = Recipe(); active.lut = swap
        let inspection = pixel(ImageEngine.apply(source,recipe:active,rangePreview:.orange))
        try require(near(inspection,pixel(ImageEngine.apply(source,recipe:Recipe(),rangePreview:.orange))),"Range inspection included LUT")
        let cubeFile = FileManager.default.temporaryDirectory.appendingPathComponent("LUT-Read-\(UUID()).cube")
        defer { try? FileManager.default.removeItem(at:cubeFile) }
        try (header+swapRows).write(to:cubeFile,atomically:true,encoding:.utf8)
        try require(try LUTAsset.read(cubeFile) == swap,"LUT file import lost table data")
        let fixture = FileManager.default.temporaryDirectory.appendingPathComponent("LUT-QA-\(UUID()).png")
        defer { try? FileManager.default.removeItem(at:fixture) }
        try context.writePNGRepresentation(of:source,to:fixture,format:.RGBA8,colorSpace:ImageEngine.output)
        let reopenedSource = try ImageEngine.open(fixture)
        let wanted = pixel(ImageEngine.apply(reopenedSource.image,recipe:active))
        for format in ExportFormat.allCases {
            let result = try ImageEngine.export(source:fixture,recipe:active,format:format)
            defer { try? FileManager.default.removeItem(at:result.url) }
            let reopened = try ImageEngine.open(result.url)
            try require(near(pixel(reopened.image),wanted,tolerance:format == .jpeg ? 0.025 : 0.01),"LUT export color differs from preview")
        }
        return ["passed":true,"identity":true,"channelOrdering":true,"strengthLinearBlend":true,"alpha":true,"domain":true,"malformedRejected":fixtures.count,"portable65PointPreset":true,"resetIndicators":true,"rangeInspectionExcludesLUT":true,"exportMatch":true]
    }
}
#endif

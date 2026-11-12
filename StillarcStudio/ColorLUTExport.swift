import Foundation
import CoreImage

extension Recipe {
    var lutCompatibleColor:Recipe {
        var copy = colorPreset
        copy.highlights = 0;copy.shadows = 0;copy.dehaze = 0
        copy.texture = 0;copy.clarity = 0;copy.noise = 0;copy.sharpen = 0
        copy.grain = 0;copy.bloom = 0;copy.vignette = 0
        return copy
    }
    var lutExcludedEdits:[String] {
        var names:[String] = []
        if input.profile != .standard { names.append("Input conversion") }
        if highlights != 0 || shadows != 0 { names.append("Highlights/Shadows") }
        if dehaze != 0 || texture != 0 || clarity != 0 || noise != 0 || sharpen != 0 { names.append("Detail tools") }
        if grain != 0 || bloom != 0 || vignette != 0 { names.append("Grain, bloom or vignette") }
        if !masks.isEmpty { names.append("Masks") }
        if hasAdjustments(in:.crop) { names.append("Framing") }
        if video.hdr { names.append("HDR output") }
        return names
    }
}
enum ColorLUTExport {
    static func make(recipe:Recipe,dimension:Int = 33,name:String) throws -> LUTAsset {
        guard dimension == 33 || dimension == 65 else { throw LUTError.invalid }
        try Task.checkCancellation();try ColorPipeline.prepare();try LevelsRendering.prepare()
        let width = dimension*dimension,height = dimension,count = width*height
        var lattice = [Float]();lattice.reserveCapacity(count*4)
        for b in 0..<dimension { for g in 0..<dimension { for r in 0..<dimension { lattice.append(Float(r)/Float(dimension-1));lattice.append(Float(g)/Float(dimension-1));lattice.append(Float(b)/Float(dimension-1));lattice.append(1) } } }
        let data = lattice.withUnsafeBytes { Data($0) }
        let source = CIImage(bitmapData:data,bytesPerRow:width*16,size:CGSize(width:width,height:height),format:.RGBAf,colorSpace:ImageEngine.output)
        let image = ImageEngine.apply(source,recipe:recipe.lutCompatibleColor)
        var output = [Float](repeating:0,count:count*4)
        ImageEngine.context().render(image,toBitmap:&output,rowBytes:width*16,bounds:CGRect(x:0,y:0,width:width,height:height),format:.RGBAf,colorSpace:ImageEngine.output)
        try Task.checkCancellation()
        for i in stride(from:0,to:output.count,by:4) {
            guard output[i].isFinite,output[i+1].isFinite,output[i+2].isFinite else { throw StudioError.render }
            for c in 0..<3 { output[i+c] = min(1,max(0,output[i+c])) };output[i+3] = 1
        }
        return try output.withUnsafeBytes { try LUTAsset(name:name,dimension:dimension,domainMin:[0,0,0],domainMax:[1,1,1],cube:Data($0)) }
    }
    static func write(_ asset:LUTAsset) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("StudioColorLUT-\(UUID())")
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        var success = false;defer { if !success { try? FileManager.default.removeItem(at:folder) } }
        let cleaned = String(asset.name.unicodeScalars.filter { CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn:"-_")).contains($0) }.prefix(60))
        let file = folder.appendingPathComponent(cleaned.isEmpty ? "Stillarc Color" : cleaned).appendingPathExtension("cube")
        let title = asset.name.replacingOccurrences(of:"\"",with:"'").replacingOccurrences(of:"\n",with:" ").replacingOccurrences(of:"\r",with:" ")
        var text = "# Stillarc Studio color-only LUT. Display sRGB input/output, SDR 0...1.\n# Apply after input conversion. Spatial effects, masks, HDR and framing excluded.\nTITLE \"\(title)\"\nLUT_3D_SIZE \(asset.dimension)\nDOMAIN_MIN 0 0 0\nDOMAIN_MAX 1 1 1\n"
        text.reserveCapacity(asset.dimension*asset.dimension*asset.dimension*32+256)
        let locale = Locale(identifier:"en_US_POSIX")
        try asset.cube.withUnsafeBytes { values in
            for i in stride(from:0,to:asset.cube.count,by:16) {
                if i % 65536 == 0 { try Task.checkCancellation() }
                let r = values.loadUnaligned(fromByteOffset:i,as:Float.self),g = values.loadUnaligned(fromByteOffset:i+4,as:Float.self),b = values.loadUnaligned(fromByteOffset:i+8,as:Float.self)
                text += String(format:"%.7f %.7f %.7f\n",locale:locale,r,g,b)
            }
        }
        try Task.checkCancellation();try text.write(to:file,atomically:true,encoding:.utf8);try Task.checkCancellation();success = true
        return file
    }
}

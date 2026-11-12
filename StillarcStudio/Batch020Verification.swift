#if DEBUG
import CoreImage
import Foundation

enum Batch020Verification {
    static func run() async throws -> [String:Any] {
        func check(_ v:Bool,_ text:String) throws { if !v { throw NSError(domain:"Batch020",code:1,userInfo:[NSLocalizedDescriptionKey:text]) } }
        try LevelsRendering.prepare()
        let context = ImageEngine.context(),extent = CGRect(x:0,y:0,width:32,height:16)
        let image = CIImage(color:CIColor(red:0.25,green:0.25,blue:0.25,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:extent)
        func pixel(_ image:CIImage) -> [Float] { var p = [Float](repeating:0,count:4);context.render(image,toBitmap:&p,rowBytes:16,bounds:CGRect(x:8,y:8,width:1,height:1),format:.RGBAf,colorSpace:ImageEngine.working);return p }
        try check(LevelsRendering.apply(image,recipe:Recipe()) === image,"Neutral Levels did not bypass")
        var r = Recipe();r.levelBlack = 0.1;r.levelWhite = 0.9;r.levelGamma = 2;r.levelOutputBlack = 0.1;r.levelOutputWhite = 0.9
        let reference = Float(0.1+sqrt((0.25-0.1)/0.8)*0.8),actual = pixel(LevelsRendering.apply(image,recipe:r))
        try check(abs(actual[0]-reference)<0.003 && actual[3]>0.99,"Levels numeric reference")
        let hdr = CIImage(color:CIColor(red:4,green:4,blue:4,alpha:1,colorSpace:ImageEngine.working)!).cropped(to:extent)
        var full = r;full.levelOutputBlack = 0;full.levelOutputWhite = 1
        try check(abs(pixel(LevelsRendering.apply(hdr,recipe:full))[0]-4)<0.01,"Levels clipped HDR headroom")
        let alpha = CIImage(color:CIColor(red:0.25,green:0.25,blue:0.25,alpha:0.5,colorSpace:ImageEngine.working)!).cropped(to:extent)
        try check(abs(pixel(LevelsRendering.apply(alpha,recipe:r))[3]-0.5)<0.001,"Levels alpha")
        let decoded = try JSONDecoder().decode(Recipe.self,from:JSONEncoder().encode(r))
        try check(decoded == r && r.colorPreset.levelGamma == 2,"Levels persistence/preset")
        try check(Recipe().pasting(r,sections:[.curves]).levelOutputBlack == 0.1,"Levels clipboard")
        var reset = r;reset.reset(.curves);try check(reset == Recipe() && !reset.hasAdjustments(in:.curves),"Levels reset/default indicator")
        let old = try JSONDecoder().decode(Recipe.self,from:Data("{}".utf8));try check(old == Recipe(),"Legacy Levels defaults")
        var bad = r;bad.levelBlack = 0.9;bad.levelWhite = 0.1;bad.levelGamma = .nan;bad = bad.validated()
        try check(bad.levelWhite-bad.levelBlack>=0.0099 && bad.levelGamma == 1,"Crossed points/numeric safety")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Batch020-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer { try? FileManager.default.removeItem(at:root) }
        let file = root.appendingPathComponent("source.png");try context.writePNGRepresentation(of:image,to:file,format:.RGBA8,colorSpace:ImageEngine.output)
        let bytes = try Data(contentsOf:file),opened = try ImageEngine.open(file)
        let expected = pixel(ImageEngine.apply(opened.image,recipe:r))[0],exported = try ImageEngine.export(source:file,recipe:r,format:.png)
        defer { try? FileManager.default.removeItem(at:exported.url) }
        try check(abs(pixel(try ImageEngine.open(exported.url).image)[0]-expected)<0.008,"Levels photo export mismatch")
        let vault = ProjectVault(root:root.appendingPathComponent("vault")),p = try await vault.importPhoto(file)
        let marked = try await vault.updateOrganization(p.id,favorite:true,rating:4)
        try check(marked.organization == ProjectOrganization(favorite:true,rating:4) && marked.modified == p.modified && marked.recipe == p.recipe,"Metadata changed render state")
        var stale = p;stale.recipe = r
        let readsBefore = await vault.organizationSaveReads
        let saved = try await vault.save(stale)
        let readsAfter = await vault.organizationSaveReads
        try check(readsBefore == readsAfter,"Normal autosave unnecessarily reparsed the project index")
        try check(saved.organization == marked.organization && saved.recipe == r,"Autosave overwrote rating/favorite")
        let loaded = try await vault.load();try check(loaded.0.first == saved,"Organization did not survive restart")
        let cleared = try await vault.updateOrganization(p.id,favorite:false,rating:0)
        try check(cleared.organization?.favorite == false && cleared.organization?.rating == 0,"Clear organization")
        try check(try Data(contentsOf:file) == bytes,"Organization changed original")
        var a = p,b = p,c = p,d = p
        a.id = UUID();a.name = "Alpha";a.organization = .init(favorite:true,rating:5)
        b.id = UUID();b.name = "Beta";b.isRAW = true;b.organization = .init(favorite:true,rating:3)
        c.id = UUID();c.name = "Café";c.video = .init(width:32,height:16,duration:1,frameRate:30,transform:[1,0,0,1,0,0],detectedLog:nil);c.organization = .init(rating:4)
        d.id = UUID();d.name = "Delta"
        let items = [d,c,b,a]
        try check(LibraryQuery.projects(items,query:"",filter:.favorites,sort:.name).map(\.id) == [a.id,b.id],"Favorite filtering")
        try check(LibraryQuery.projects(items,query:"CAFE",filter:.videos,sort:.name).map(\.id) == [c.id],"Search/media filtering")
        try check(LibraryQuery.projects(items,query:"",filter:.raw,sort:.name).map(\.id) == [b.id],"RAW filter")
        try check(LibraryQuery.projects(items,query:"",filter:.topRated,sort:.rating).map(\.id) == [a.id,c.id],"Rating filtering/sorting")
        try check(LibraryQuery.projects(items,query:"",filter:.photos,sort:.name).map(\.id) == [a.id,b.id,d.id],"Photos filter")
        let large = (0..<2000).map { i in var q = p;q.id = UUID();q.name = "Photo\(i)";q.organization = .init(favorite:i%3 == 0,rating:i%6);q.created = Date(timeIntervalSince1970:Double(i));return q }
        let start = Date()
        for _ in 0..<10 { _ = LibraryQuery.projects(large,query:"Photo",filter:.favorites,sort:.rating) }
        let elapsed = Date().timeIntervalSince(start)
        try check(LibraryQuery.projects(large,query:"Photo1999",filter:.all,sort:.newest).count == 1,"Large library search")
        return ["passed":true,"levelsNumericHDRAlpha":true,"levelsNeutralMigrationAndReset":true,"levelsPresetCopyPasteAndPNG":true,"organizationPersists":true,"staleAutosavePreservesMetadata":true,"metadataKeepsRenderTimestamp":true,"autosaveAvoidsExtraIndexDecode":true,"filtersSearchSort":true,"largeLibraryItems":2000,"tenQueriesSeconds":elapsed]
    }
}
#endif

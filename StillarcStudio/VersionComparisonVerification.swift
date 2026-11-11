#if DEBUG
import CoreImage
import Foundation

enum VersionComparisonVerification {
    static func run() async throws -> [String:Any] {
        func require(_ value:Bool,_ message:String) throws { if !value { throw NSError(domain:"VersionComparison",code:1,userInfo:[NSLocalizedDescriptionKey:message]) } }
        let context = ImageEngine.context(),extent = CGRect(x:0,y:0,width:8,height:2)
        let before = CIImage(color:CIColor(red:1,green:0,blue:0)).cropped(to:extent),after = CIImage(color:CIColor(red:0,green:0,blue:1)).cropped(to:extent)
        for fraction in [0.0,0.25,0.5,1] {
            let image = ComparisonRender.combine(original:before,edited:after,fraction:fraction)
            var pixels = [Float](repeating:0,count:8*2*4)
            context.render(image,toBitmap:&pixels,rowBytes:8*16,bounds:extent,format:.RGBAf,colorSpace:ImageEngine.working)
            for x in 0..<8 { try require(pixels[x*4+(Double(x)<fraction*8 ? 0 : 2)]>0.99,"Split divider pixels incorrect") }
        }
        try require(ComparisonRender.combine(original:before,edited:after,fraction:nil) === after,"Disabled split did not bypass rendering")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("StudioVersionsQA-\(UUID())"),vault = ProjectVault(root:root)
        defer { try? FileManager.default.removeItem(at:root) }
        var recipe = Recipe();recipe.exposure = 0.6;recipe.lut = try LUTVerification.example();recipe.geometry.flipHorizontal = true;recipe.input.profile = .appleLog2;recipe.video.start = 0.2;recipe.video.end = 1
        var project = Project(id:UUID(),name:"Version QA",sourceName:"original.dat",created:Date(),modified:Date(),recipe:recipe,width:8,height:2,isRAW:false)
        let source = await vault.source(project);try FileManager.default.createDirectory(at:source.deletingLastPathComponent(),withIntermediateDirectories:true);let original = Data("unchanged-source".utf8);try original.write(to:source)
        let first = EditVersion(name:"First")
        try await vault.saveVersion(project,version:first,recipe:recipe);project.versions = [first];try await vault.save(project)
        let metadata = try Data(contentsOf:root.appendingPathComponent(project.id.uuidString+".json"))
        let loaded = try await vault.load();try require(loaded.0.first?.versions == [first],"Version index did not reopen")
        var later = recipe;later.exposure = -1;project.recipe = later;try await vault.save(project)
        let restored = try await vault.loadVersion(project,version:first)
        try require(restored == recipe,"Autosave changed the saved version")
        try require(try Data(contentsOf:source) == original,"Version modified the source")
        try await vault.removeVersion(project,version:first)
        do { _ = try await vault.loadVersion(project,version:first);throw NSError(domain:"VersionComparison",code:2,userInfo:[NSLocalizedDescriptionKey:"Deleted version remained readable"]) } catch let error as NSError { try require(error.domain != "VersionComparison","Deleted version remained readable") }
        var legacy = try JSONSerialization.jsonObject(with:metadata) as! [String:Any];legacy.removeValue(forKey:"versions")
        let old = try JSONDecoder().decode(Project.self,from:JSONSerialization.data(withJSONObject:legacy));try require(old.versions == nil,"Legacy project version defaults changed")
        return ["passed":true,"splitPositions":4,"neutralBypass":true,"sourcePreserved":true,"snapshotImmutable":true,"fullRecipeRoundTrip":true,"legacyProject":true,"delete":true]
    }
}
#endif

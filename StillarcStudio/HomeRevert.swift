import Foundation

extension Project {
    var originalRecipe:Recipe {
        var recipe = Recipe()
        recipe.input.profile = video?.detectedLog ?? .standard
        recipe.video.hdr = video?.hdrTransfer != nil
        return recipe
    }
}
extension ProjectVault {
    func revertToOriginal(_ id:UUID) throws -> Project {
        let url = root.appendingPathComponent(id.uuidString+".json")
        var project = try JSONDecoder().decode(Project.self,from:Data(contentsOf:url))
        let original = project.originalRecipe
        guard project.recipe != original else { return project }
        guard (project.versions ?? []).count<20 else { throw NSError(domain:"Revert",code:1,userInfo:[NSLocalizedDescriptionKey:"This project already has 20 versions. Remove a version first so the current edit can be preserved before reverting."]) }
        let version = EditVersion(name:"Before revert to original")
        try saveVersion(project,version:version,recipe:project.recipe)
        project.versions = (project.versions ?? [])+[version]
        project.recipe = original;project.modified = Date()
        do { return try save(project) }
        catch { try? removeVersion(project,version:version);throw error }
    }
}

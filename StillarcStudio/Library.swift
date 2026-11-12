import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CoreImage

struct PhotoTransfer: Transferable {
    let url: URL
    static func copied(_ file:URL) throws -> PhotoTransfer {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("StudioImport-"+UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let name = file.lastPathComponent
        let target = directory.appendingPathComponent(name.isEmpty || name == "." || name == ".." ? "Imported media" : name)
        do { try FileManager.default.copyItem(at:file,to:target);return PhotoTransfer(url:target) }
        catch { try? FileManager.default.removeItem(at:directory);throw error }
    }
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType:.image) { try copied($0.file) }
        FileRepresentation(importedContentType:.movie) { try copied($0.file) }
    }
}
actor ProjectVault {
    private struct OrganizationSnapshot { let value:ProjectOrganization? }
    private var organizations:[UUID:OrganizationSnapshot] = [:]
    #if DEBUG
    private(set) var organizationSaveReads = 0
    #endif
    var recoveryMessages:[String] = []
    let root: URL
    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("StillarcStudio", isDirectory: true)
    }
    func load() throws -> ([Project], [SavedLook]) {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        recoveryMessages = []
        do { _ = try deletedProjects() } catch { recoveryMessages.append("Recently Deleted could not be checked: "+error.localizedDescription) }
        let projects = (try? FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:nil))?.filter { $0.pathExtension == "json" && $0.lastPathComponent != "looks.json" && $0.lastPathComponent != "adjustments-clipboard.json" }.compactMap { recoverableProject($0) } ?? []
        organizations = Dictionary(projects.map { ($0.id,OrganizationSnapshot(value:$0.organization)) },uniquingKeysWith:{ a,_ in a })
        let looks = recoveredLooks()
        return (projects.sorted { $0.modified > $1.modified }, looks)
    }
    func source(_ project: Project) -> URL { root.appendingPathComponent(project.id.uuidString, isDirectory: true).appendingPathComponent(project.sourceName) }
    func saveEditorSnapshot(_ project:Project) throws -> Project {
        try Task.checkCancellation();return try save(project)
    }
    @discardableResult func save(_ incoming: Project) throws -> Project {
        var project = incoming
        let index = root.appendingPathComponent(project.id.uuidString+".json")
        if FileManager.default.fileExists(atPath:index.path) {
            if let known = organizations[project.id] { project.organization = known.value }
            else {
                project.organization = try JSONDecoder().decode(Project.self,from:Data(contentsOf:index)).organization
                #if DEBUG
                organizationSaveReads += 1
                #endif
            }
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try writeRecoverableIndex(project)
        organizations[project.id] = OrganizationSnapshot(value:project.organization)
        return project
    }
    func updateOrganization(_ id:UUID,favorite:Bool?,rating:Int?) throws -> Project {
        let url = root.appendingPathComponent(id.uuidString+".json")
        var project = try JSONDecoder().decode(Project.self,from:Data(contentsOf:url))
        var metadata = project.organization ?? ProjectOrganization()
        if let favorite { metadata.favorite = favorite };if let rating { metadata.rating = min(5,max(0,rating)) }
        project.organization = metadata
        try writeRecoverableIndex(project,forceBackup:true)
        organizations[project.id] = OrganizationSnapshot(value:project.organization)
        return project
    }
    func loadClipboard() throws -> AdjustmentClipboard? {
        let url = root.appendingPathComponent("adjustments-clipboard.json")
        guard FileManager.default.fileExists(atPath:url.path) else { return nil }
        let clip = try JSONDecoder().decode(AdjustmentClipboard.self,from:Data(contentsOf:url))
        guard clip.schema == 1,!clip.sections.isEmpty else { throw StudioError.unsupportedPreset }
        return clip
    }
    func saveClipboard(_ clip:AdjustmentClipboard?) throws {
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let url = root.appendingPathComponent("adjustments-clipboard.json")
        if let clip { try JSONEncoder().encode(clip).write(to:url,options:.atomic) }
        else if FileManager.default.fileExists(atPath:url.path) { try FileManager.default.removeItem(at:url) }
    }
    func saveLooks(_ looks: [SavedLook]) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(looks)
        try FileManager.default.createDirectory(at:recoveryRoot,withIntermediateDirectories:true)
        try data.write(to:recoveryRoot.appendingPathComponent("looks.json"),options:.atomic)
        try data.write(to:root.appendingPathComponent("looks.json"),options:.atomic)
    }
    func importPhoto(_ url: URL) async throws -> Project {
        let id = UUID(), dir = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let final = root.appendingPathComponent(id.uuidString, isDirectory: true)
        // Stage decoding before publishing a project to the library.
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        do {
            let sourceName = "original." + (url.pathExtension.isEmpty ? "image" : url.pathExtension.lowercased())
            let destination = dir.appendingPathComponent(sourceName)
            try FileManager.default.copyItem(at: url, to: destination)
            let video = VideoEngine.isMovie(destination) ? try await VideoEngine.describe(destination) : nil
            let prepared:PreparedPhoto
            if let video { prepared = try await Task.detached(priority:.userInitiated) { try await VideoEngine.poster(destination,descriptor:video,maxDimension:450) }.value }
            else { prepared = try ImageEngine.open(destination,maxDimension:1600) }
            try FileManager.default.moveItem(at: dir, to: final)
            var recipe = Recipe(); recipe.input.profile = video?.detectedLog ?? .standard;recipe.video.hdr = video?.hdrTransfer != nil
            let project = Project(id:id,name:url.deletingPathExtension().lastPathComponent,sourceName:sourceName,created:Date(),modified:Date(),recipe:recipe,width:prepared.width,height:prepared.height,isRAW:prepared.isRAW,video:video)
            try save(project)
            return project
        } catch { try? FileManager.default.removeItem(at: dir); try? FileManager.default.removeItem(at: final); throw error }
    }
    func saveVersion(_ project:Project,version:EditVersion,recipe:Recipe) throws {
        let directory = root.appendingPathComponent(project.id.uuidString).appendingPathComponent("versions")
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        try JSONEncoder().encode(recipe).write(to:directory.appendingPathComponent(version.id.uuidString+".json"),options:.atomic)
    }
    func loadVersion(_ project:Project,version:EditVersion) throws -> Recipe {
        let url = root.appendingPathComponent(project.id.uuidString).appendingPathComponent("versions").appendingPathComponent(version.id.uuidString+".json")
        return try JSONDecoder().decode(Recipe.self,from:Data(contentsOf:url))
    }
    func removeVersion(_ project:Project,version:EditVersion) throws {
        let url = root.appendingPathComponent(project.id.uuidString).appendingPathComponent("versions").appendingPathComponent(version.id.uuidString+".json")
        if FileManager.default.fileExists(atPath:url.path) { try FileManager.default.removeItem(at:url) }
    }
    func remove(_ project: Project) throws {
        try moveToDeleted(project)
        organizations.removeValue(forKey:project.id)
    }
}
@MainActor @Observable final class StudioLibrary {
    var projects: [Project] = []
    var looks: [SavedLook] = []
    var looksBusy = false
    var adjustmentClipboard:AdjustmentClipboard?
    var recoveryMessage:String?
    var loading = true
    var importing = false
    var organizationBusy = Set<UUID>()
    var error: String?
    let vault:ProjectVault
    init(vault:ProjectVault = ProjectVault()) { self.vault = vault }
    func load() async {
        do { (projects, looks) = try await vault.load();adjustmentClipboard = try await vault.loadClipboard();recoveryMessage = await vault.recoveryNotice() } catch { self.error = error.localizedDescription }
        loading = false
    }
    @discardableResult func copyAdjustments(name:String,recipe:Recipe,sections:Set<AdjustmentSection>) async -> Bool {
        guard !sections.isEmpty else { return false }
        let clip = AdjustmentClipboard(name:name,recipe:recipe,sections:sections)
        do { try await vault.saveClipboard(clip);adjustmentClipboard = clip;return true }
        catch { self.error = error.localizedDescription;return false }
    }
    @discardableResult func clearCopiedAdjustments() async -> Bool {
        do { try await vault.saveClipboard(nil);adjustmentClipboard = nil;return true }
        catch { self.error = error.localizedDescription;return false }
    }
    func add(_ url: URL) async -> Project? {
        guard !importing else { return nil }; importing = true
        defer { importing = false }
        do {
            let secured = url.startAccessingSecurityScopedResource()
            defer { if secured { url.stopAccessingSecurityScopedResource() } }
            let project = try await vault.importPhoto(url)
            projects.insert(project, at: 0)
            return project
        } catch { self.error = error.localizedDescription; return nil }
    }
    @discardableResult func save(_ project: Project) async -> Bool {
        do {
            let updated = try await vault.saveEditorSnapshot(project)
            if let index = projects.firstIndex(where: { $0.id == project.id }),projects[index].modified<=updated.modified { projects[index] = updated }
            return true
        } catch is CancellationError { return false }
        catch { self.error = error.localizedDescription; return false }
    }
    func organize(_ project:Project,favorite:Bool? = nil,rating:Int? = nil) async {
        guard organizationBusy.insert(project.id).inserted else { return }
        defer { organizationBusy.remove(project.id) }
        do {
            let updated = try await vault.updateOrganization(project.id,favorite:favorite,rating:rating)
            if let index = projects.firstIndex(where:{ $0.id == project.id }),projects[index].modified<=updated.modified { projects[index] = updated }
        } catch { self.error = error.localizedDescription }
    }
    func remove(_ project: Project) async {
        do { try await vault.remove(project); projects.removeAll { $0.id == project.id } } catch { self.error = error.localizedDescription }
    }
    @discardableResult func saveLook(name: String, recipe: Recipe) async -> Bool {
        guard !looksBusy else { return false };looksBusy = true;defer { looksBusy = false }
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return false }
        let updated = looks + [SavedLook(name: cleaned, recipe: recipe.colorPreset)]
        do { try await vault.saveLooks(updated); looks = updated; return true } catch { self.error = error.localizedDescription; return false }
    }
    @discardableResult func renameLook(_ look:SavedLook,name:String) async -> Bool {
        guard !looksBusy else { return false };looksBusy = true;defer { looksBusy = false }
        let name = String(name.trimmingCharacters(in:.whitespacesAndNewlines).prefix(100))
        guard !name.isEmpty,let index = looks.firstIndex(where:{ $0.id == look.id }) else { return false }
        var updated = looks;updated[index].name = name
        do { try await vault.saveLooks(updated);looks = updated;return true } catch { self.error = error.localizedDescription;return false }
    }
    func removeLook(_ look: SavedLook) async {
        guard !looksBusy else { return };looksBusy = true;defer { looksBusy = false }
        let updated = looks.filter { $0.id != look.id }
        do { try await vault.saveLooks(updated); looks = updated } catch { self.error = error.localizedDescription }
    }
}

@MainActor @Observable final class EditSession {
    var project: Project
    var recipe: Recipe
    var source: PreparedPhoto?
    var error: String?
    var versionsBusy = false
    var busy = true
    var saving = false
    var saved = true
    var undoStack: [Recipe] = []
    var redoStack: [Recipe] = []
    var transaction: Recipe?
    var sourceURL: URL?
    private var saveTask: Task<Void, Never>?
    private var retired=false
    var historyRecorder:((Recipe,Recipe)->Void)?
    private var historySavedRecipe:Recipe?
    init(_ project: Project) { self.project = project; recipe = project.recipe }
    func open(library: StudioLibrary) async {
        let url = await library.vault.source(project); sourceURL = url
        do {
            let video = project.video,maskLayers = recipe.masks
            let worker = Task.detached(priority:.userInitiated) {
                AutomaticMaskBitmap.warm(maskLayers)
                if let video { return try await VideoEngine.poster(url,descriptor:video) }
                return try ImageEngine.open(url,maxDimension:1600)
            }
            let loaded = try await withTaskCancellationHandler(operation:{try await worker.value},onCancel:{worker.cancel()})
            guard !Task.isCancelled,!retired else {return}
            source = loaded
            if source?.isRAW == true { recipe.input = InputConversion() }
        }
        catch { self.error = error.localizedDescription }
        busy = false
    }
    func begin() { if transaction == nil { transaction = recipe } }
    func end() {
        guard let before = transaction else { return }; transaction = nil
        if before != recipe {if let historyRecorder {historyRecorder(before,recipe)} else {undoStack.append(before);if undoStack.count>80 {undoStack.removeFirst()}};redoStack=[]}
    }
    func change(_ body: (inout Recipe) -> Void) { begin(); body(&recipe); end() }
    func undo() { guard let previous = undoStack.popLast() else { return }; redoStack.append(recipe); recipe = previous }
    func redo() { guard let next = redoStack.popLast() else { return }; undoStack.append(recipe); recipe = next }
    func saveVersion(name:String,library:StudioLibrary) async {
        let name = name.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !versionsBusy,!name.isEmpty,(project.versions?.count ?? 0)<20 else { return }
        versionsBusy = true;defer { versionsBusy = false }
        let version = EditVersion(name:String(name.prefix(80))),snapshot = recipe,previous = project.versions
        do {
            try await library.vault.saveVersion(project,version:version,recipe:snapshot)
            project.versions = (previous ?? [])+[version]
            if !(await persist(library)) { project.versions = previous;try? await library.vault.removeVersion(project,version:version) }
        } catch { self.error = error.localizedDescription }
    }
    @discardableResult func restoreVersion(_ version:EditVersion,library:StudioLibrary) async -> Bool {
        guard !versionsBusy else { return false };versionsBusy = true;defer { versionsBusy = false }
        do { let restored = try await library.vault.loadVersion(project,version:version);change { $0 = restored };return await persist(library) }
        catch { self.error = error.localizedDescription;return false }
    }
    func deleteVersion(_ version:EditVersion,library:StudioLibrary) async {
        guard !versionsBusy else { return };versionsBusy = true;defer { versionsBusy = false }
        let previous = project.versions
        project.versions = previous?.filter { $0.id != version.id }
        if await persist(library) { try? await library.vault.removeVersion(project,version:version) }
        else { project.versions = previous }
    }
    func scheduleSave(_ library: StudioLibrary) {
        guard !retired else {return}
        if historySavedRecipe==recipe {historySavedRecipe=nil;return}
        historySavedRecipe=nil
        saved = false; saveTask?.cancel()
        saveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            guard let self else { return }; await self.persist(library)
        }
    }
    func pauseAutosave() {saveTask?.cancel();saveTask=nil;end()}
    func adoptHistory(_ updated:Project) {
        saveTask?.cancel();saveTask=nil;transaction=nil
        project=updated;recipe=updated.recipe;historySavedRecipe=recipe;saved=true
    }
    func retire(_ library:StudioLibrary) async -> Bool {
        saveTask?.cancel();saveTask=nil;end()
        guard await persist(library) else {return false}
        retired=true;source=nil;return true
    }
    @discardableResult func persist(_ library: StudioLibrary) async -> Bool {
        guard !retired else {return true}
        guard !Task.isCancelled else {return false}
        project.recipe = recipe; project.modified = Date()
        let snapshot = project
        let success = await library.save(snapshot)
        if recipe == snapshot.recipe { saved = success }
        return success
    }
}

// Serialize thumbnail decoding, reuse one context and bound decoded image memory.
actor ThumbnailCache {
    static let shared = ThumbnailCache()
    private let context = ImageEngine.context()
    private let cache = NSCache<NSString, UIImage>()
    init() { cache.countLimit = 40; cache.totalCostLimit = 24 * 1024 * 1024 }
    func clear() { cache.removeAllObjects(); context.clearCaches() }
    func image(url: URL, project: Project,maxDimension:Double = 450) async -> UIImage? {
        guard !Task.isCancelled else { return nil }
        let dimension=min(450,max(96,maxDimension.isFinite ? maxDimension:450))
        let key = "\(project.id)-\(project.modified.timeIntervalSince1970)-\(Int(dimension))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let prepared:PreparedPhoto?
        if let video = project.video { prepared = try? await VideoEngine.poster(url,descriptor:video,maxDimension:dimension) }
        else { prepared = try? ImageEngine.open(url,maxDimension:dimension) }
        return autoreleasepool {
            guard let source = prepared,!Task.isCancelled else { return nil }
            let adjusted = ImageEngine.apply(source.source(for:project.recipe),recipe:project.recipe)
            guard let cg = context.createCGImage(adjusted, from: adjusted.extent) else { return nil }
            let image = UIImage(cgImage: cg)
            cache.setObject(image, forKey: key, cost: cg.bytesPerRow * cg.height)
            return image
        }
    }
}

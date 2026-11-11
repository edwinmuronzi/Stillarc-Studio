import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CoreImage

struct PhotoTransfer: Transferable {
    let url: URL
    private static func copied(_ file:URL) throws -> PhotoTransfer {
        let target = FileManager.default.temporaryDirectory.appendingPathComponent("StudioImport-"+UUID().uuidString).appendingPathExtension(file.pathExtension)
        try FileManager.default.copyItem(at:file,to:target)
        return PhotoTransfer(url:target)
    }
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType:.image) { try copied($0.file) }
        FileRepresentation(importedContentType:.movie) { try copied($0.file) }
    }
}
actor ProjectVault {
    let root: URL
    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("StillarcStudio", isDirectory: true)
    }
    func load() throws -> ([Project], [SavedLook]) {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let projects = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil))?.filter { $0.pathExtension == "json" && $0.lastPathComponent != "looks.json" }.compactMap { try? JSONDecoder().decode(Project.self, from: Data(contentsOf: $0)) } ?? []
        let lookURL = root.appendingPathComponent("looks.json")
        let looks = FileManager.default.fileExists(atPath: lookURL.path) ? try JSONDecoder().decode([SavedLook].self, from: Data(contentsOf: lookURL)) : []
        return (projects.sorted { $0.modified > $1.modified }, looks)
    }
    func source(_ project: Project) -> URL { root.appendingPathComponent(project.id.uuidString, isDirectory: true).appendingPathComponent(project.sourceName) }
    func save(_ project: Project) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(project).write(to: root.appendingPathComponent(project.id.uuidString + ".json"), options: .atomic)
    }
    func saveLooks(_ looks: [SavedLook]) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONEncoder().encode(looks).write(to: root.appendingPathComponent("looks.json"), options: .atomic)
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
    func remove(_ project: Project) throws {
        // Remove the index first: a failed cleanup cannot leave a broken library item.
        try FileManager.default.removeItem(at: root.appendingPathComponent(project.id.uuidString + ".json"))
        try? FileManager.default.removeItem(at: root.appendingPathComponent(project.id.uuidString))
    }
}
@MainActor @Observable final class StudioLibrary {
    var projects: [Project] = []
    var looks: [SavedLook] = []
    var loading = true
    var importing = false
    var error: String?
    let vault = ProjectVault()
    func load() async {
        do { (projects, looks) = try await vault.load() } catch { self.error = error.localizedDescription }
        loading = false
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
            try await vault.save(project)
            if let index = projects.firstIndex(where: { $0.id == project.id }) { projects[index] = project }
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func remove(_ project: Project) async {
        do { try await vault.remove(project); projects.removeAll { $0.id == project.id } } catch { self.error = error.localizedDescription }
    }
    @discardableResult func saveLook(name: String, recipe: Recipe) async -> Bool {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return false }
        let updated = looks + [SavedLook(name: cleaned, recipe: recipe.colorPreset)]
        do { try await vault.saveLooks(updated); looks = updated; return true } catch { self.error = error.localizedDescription; return false }
    }
    func removeLook(_ look: SavedLook) async {
        let updated = looks.filter { $0.id != look.id }
        do { try await vault.saveLooks(updated); looks = updated } catch { self.error = error.localizedDescription }
    }
}

@MainActor @Observable final class EditSession {
    var project: Project
    var recipe: Recipe
    var source: PreparedPhoto?
    var error: String?
    var busy = true
    var saving = false
    var saved = true
    var undoStack: [Recipe] = []
    var redoStack: [Recipe] = []
    var transaction: Recipe?
    var sourceURL: URL?
    private var saveTask: Task<Void, Never>?
    init(_ project: Project) { self.project = project; recipe = project.recipe }
    func open(library: StudioLibrary) async {
        let url = await library.vault.source(project); sourceURL = url
        do {
            let video = project.video
            source = try await Task.detached(priority:.userInitiated) {
                if let video { return try await VideoEngine.poster(url,descriptor:video) }
                return try ImageEngine.open(url,maxDimension:1600)
            }.value
            if source?.isRAW == true { recipe.input = InputConversion() }
        }
        catch { self.error = error.localizedDescription }
        busy = false
    }
    func begin() { if transaction == nil { transaction = recipe } }
    func end() {
        guard let before = transaction else { return }; transaction = nil
        if before != recipe { undoStack.append(before); if undoStack.count > 80 { undoStack.removeFirst() }; redoStack = [] }
    }
    func change(_ body: (inout Recipe) -> Void) { begin(); body(&recipe); end() }
    func undo() { guard let previous = undoStack.popLast() else { return }; redoStack.append(recipe); recipe = previous }
    func redo() { guard let next = redoStack.popLast() else { return }; undoStack.append(recipe); recipe = next }
    func scheduleSave(_ library: StudioLibrary) {
        saved = false; saveTask?.cancel()
        saveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            guard let self else { return }; await self.persist(library)
        }
    }
    func persist(_ library: StudioLibrary) async {
        project.recipe = recipe; project.modified = Date()
        let snapshot = project
        let success = await library.save(snapshot)
        if recipe == snapshot.recipe { saved = success }
    }
}

// Serialize thumbnail decoding, reuse one context and bound decoded image memory.
actor ThumbnailCache {
    static let shared = ThumbnailCache()
    private let context = ImageEngine.context()
    private let cache = NSCache<NSString, UIImage>()
    init() { cache.countLimit = 40; cache.totalCostLimit = 24 * 1024 * 1024 }
    func clear() { cache.removeAllObjects(); context.clearCaches() }
    func image(url: URL, project: Project) async -> UIImage? {
        guard !Task.isCancelled else { return nil }
        let key = "\(project.id)-\(project.modified.timeIntervalSince1970)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let prepared:PreparedPhoto?
        if let video = project.video { prepared = try? await VideoEngine.poster(url,descriptor:video,maxDimension:450) }
        else { prepared = try? ImageEngine.open(url,maxDimension:450) }
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

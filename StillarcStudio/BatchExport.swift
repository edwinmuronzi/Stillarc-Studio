import Foundation

struct BatchExportResult:Sendable {
    let folder:URL
    let urls:[URL]
    let failures:[String]
}
enum BatchExportEngine {
    static func run(_ projects:[Project],vault:ProjectVault,format:ExportFormat,privacy:ExportPrivacy = ExportPrivacy(),delivery:DeliverySettings = DeliverySettings(),progress:@escaping @Sendable (Int,Double,String) async -> Void) async throws -> BatchExportResult {
        guard !projects.isEmpty,projects.count<=20 else { throw StudioError.render }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Stillarc-Batch-\(UUID())",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        var completed = false,urls:[URL] = [],failures:[String] = []
        defer { if !completed { try? FileManager.default.removeItem(at:folder) } }
        for (i,p) in projects.enumerated() {
            try Task.checkCancellation()
            while ProcessInfo.processInfo.thermalState.rawValue>=ProcessInfo.ThermalState.serious.rawValue {
                await progress(i,0,"Waiting for the phone to cool · "+p.name)
                try await Task.sleep(for:.seconds(1))
            }
            if ProcessInfo.processInfo.thermalState == .fair { try await Task.sleep(for:.milliseconds(150)) }
            await progress(i,0,p.name)
            do {
                let source = await vault.source(p)
                let recipe = try await MaskFramingRepair.repair(recipe:p.recipe,url:source,video:p.video,prepared:nil)
                try Task.checkCancellation()
                let output:ExportResult
                if let video = p.video { output = try await VideoEngine.export(source:source,descriptor:video,recipe:recipe,privacy:privacy,delivery:delivery,progress:{ value in await progress(i,value,p.name) }) }
                else { output = try ImageEngine.export(source:source,recipe:recipe,format:recipe.hasTransparentCutout ? .png:format,privacy:privacy,delivery:delivery) }
                defer { try? FileManager.default.removeItem(at:output.url) }
                try Task.checkCancellation()
                let cleaned = String(String.UnicodeScalarView(p.name.unicodeScalars.filter { CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn:"-_" )).contains($0) }.prefix(60)))
                let target = folder.appendingPathComponent(String(format:"%02d-",i+1)+(!privacy.projectNames || cleaned.isEmpty ? "Stillarc" : cleaned)).appendingPathExtension(output.url.pathExtension)
                try FileManager.default.moveItem(at:output.url,to:target);urls.append(target)
            } catch is CancellationError { throw CancellationError() }
            catch { failures.append(p.name+": "+error.localizedDescription) }
            await progress(i,1,p.name)
        }
        try Task.checkCancellation();completed = true
        return BatchExportResult(folder:folder,urls:urls,failures:failures)
    }
}

import Foundation

/// Preflight only; the writer remains responsible for actual free-space changes during delivery.
enum DeliveryStorage {
    static func validate(available:Int64?,planned:Double) throws {
        guard planned.isFinite,planned>=0 else {throw StudioError.render}
        guard let available else {return}
        let needed=min(Double(Int64.max/2),planned*1.2+25_000_000)
        guard Double(available)>=needed else {throw NSError(domain:"DeliveryStorage",code:1,userInfo:[NSLocalizedDescriptionKey:"Free up storage before exporting. This delivery needs approximately \(ExportSizeEstimate.bytes(needed)) of temporary space. Your original and edits are unchanged."])}
    }
    static func require(planned:Double) throws {
        let free=(try? FileManager.default.attributesOfFileSystem(forPath:NSTemporaryDirectory())[.systemFreeSize] as? NSNumber)?.int64Value
        try validate(available:free,planned:planned)
    }
}

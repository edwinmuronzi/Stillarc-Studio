#if DEBUG
import Foundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import AVFoundation

enum ExportPrivacyVerification {
    static func check(_ value:Bool,_ message:String) throws { if !value { throw NSError(domain:"ExportPrivacyQA",code:1,userInfo:[NSLocalizedDescriptionKey:message]) } }
    static func properties(_ url:URL) throws -> [String:Any] {
        guard let s = CGImageSourceCreateWithURL(url as CFURL,nil),let p = CGImageSourceCopyPropertiesAtIndex(s,0,nil) as? [String:Any] else { throw StudioError.render };return p
    }
    static func photo() async throws -> [String:Any] {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PrivacyQA-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);defer { try? FileManager.default.removeItem(at:root) }
        let source = root.appendingPathComponent("private-source.jpg")
        let image = CIImage(color:.init(red:0.25,green:0.4,blue:0.6)).cropped(to:CGRect(x:0,y:0,width:64,height:48))
        guard let cg = ImageEngine.context().createCGImage(image,from:image.extent),let destination = CGImageDestinationCreateWithURL(source as CFURL,UTType.jpeg.identifier as CFString,1,nil) else { throw StudioError.render }
        CGImageDestinationAddImage(destination,cg,[kCGImagePropertyOrientation:6,kCGImagePropertyExifDictionary:[kCGImagePropertyExifDateTimeOriginal:"2020:01:02 03:04:05",kCGImagePropertyExifLensModel:"QA Lens",kCGImagePropertyExifBodySerialNumber:"PRIVATE-SERIAL",kCGImagePropertyExifUserComment:"PRIVATE-COMMENT"],kCGImagePropertyTIFFDictionary:[kCGImagePropertyTIFFMake:"QA Camera",kCGImagePropertyTIFFModel:"QA Model",kCGImagePropertyTIFFArtist:"PRIVATE-OWNER"],kCGImagePropertyGPSDictionary:[kCGImagePropertyGPSLatitude:36.8,kCGImagePropertyGPSLatitudeRef:"S",kCGImagePropertyGPSLongitude:174.7,kCGImagePropertyGPSLongitudeRef:"E",kCGImagePropertyGPSDateStamp:"PRIVATE-GPS-TIME"]] as CFDictionary)
        try check(CGImageDestinationFinalize(destination),"Fixture encode")
        let bytes = try Data(contentsOf:source),all = ExportPrivacy(captureDate:true,camera:true,location:true,audio:false,projectNames:true)
        for format in ExportFormat.allCases {
            let stripped = try ImageEngine.export(source:source,recipe:Recipe(),format:format)
            let included = try ImageEngine.export(source:source,recipe:Recipe(),format:format,privacy:all)
            defer { try? FileManager.default.removeItem(at:stripped.url);try? FileManager.default.removeItem(at:included.url) }
            let a = try properties(stripped.url),b = try properties(included.url)
            let exifA = a[kCGImagePropertyExifDictionary as String] as? [String:Any] ?? [:],exifB = b[kCGImagePropertyExifDictionary as String] as? [String:Any] ?? [:]
            let tiffA = a[kCGImagePropertyTIFFDictionary as String] as? [String:Any] ?? [:],tiffB = b[kCGImagePropertyTIFFDictionary as String] as? [String:Any] ?? [:]
            try check(a[kCGImagePropertyGPSDictionary as String] == nil && exifA[kCGImagePropertyExifDateTimeOriginal as String] == nil && tiffA[kCGImagePropertyTIFFMake as String] == nil,"\(format): default leaked metadata")
            try check(exifB[kCGImagePropertyExifDateTimeOriginal as String] as? String == "2020:01:02 03:04:05" && tiffB[kCGImagePropertyTIFFMake as String] as? String == "QA Camera","\(format): selected date/camera missing")
            try check((b[kCGImagePropertyGPSDictionary as String] as? [String:Any])?[kCGImagePropertyGPSLatitude as String] != nil,"\(format): selected location missing")
            try check(exifB[kCGImagePropertyExifBodySerialNumber as String] == nil && exifB[kCGImagePropertyExifUserComment as String] == nil && tiffB[kCGImagePropertyTIFFArtist as String] == nil,"\(format): unselected private fields leaked")
            try check(stripped.width == 48 && stripped.height == 64 && included.width == 48 && included.height == 64,"Export orientation/dimensions")
            let noDate = ExportPrivacy(captureDate:false,camera:true,location:true).photoProperties(source:source)
            try check((noDate[kCGImagePropertyExifDictionary as String] as? [String:Any])?[kCGImagePropertyExifDateTimeOriginal as String] == nil && (noDate[kCGImagePropertyGPSDictionary as String] as? [String:Any])?[kCGImagePropertyGPSDateStamp as String] == nil,"Location/camera selection leaked date")
        }
        let suite = "PrivacyQA-\(UUID())",defaults = UserDefaults(suiteName:suite)!
        defer { defaults.removePersistentDomain(forName:suite) }
        try check(ExportPrivacy.load(defaults) == ExportPrivacy(),"Private defaults")
        all.save(defaults);try check(ExportPrivacy.load(defaults) == all,"Preference persistence")
        let vault = ProjectVault(root:root.appendingPathComponent("vault")),project = try await vault.importPhoto(source)
        let batch = try await BatchExportEngine.run([project],vault:vault,format:.jpeg,privacy:all,progress:{ _,_,_ in })
        defer { try? FileManager.default.removeItem(at:batch.folder) }
        try check(batch.urls.first?.lastPathComponent.contains("private-source") == true && (try properties(batch.urls[0]))[kCGImagePropertyGPSDictionary as String] != nil,"Batch policy propagation")
        let anonymous = try await BatchExportEngine.run([project],vault:vault,format:.jpeg,progress:{ _,_,_ in })
        defer { try? FileManager.default.removeItem(at:anonymous.folder) }
        try check(anonymous.urls.first?.lastPathComponent == "01-Stillarc.jpg","Batch private filenames")
        try check(try Data(contentsOf:source) == bytes,"Original bytes changed")
        return ["passed":true,"jpegPNGMetadata":true,"orientation":true,"defaultStrip":true,"allowlist":true,"independentChoices":true,"preferencePersistence":true,"batchPropagationAndNames":true,"originalPreserved":true]
    }
    static func video() async throws -> [String:Any] {
        var items:[AVMetadataItem] = []
        for (key,value) in [(AVMetadataIdentifier.quickTimeMetadataCreationDate,"2020-01-02T03:04:05Z"),(.quickTimeMetadataLocationISO6709,"-36.8000+174.7000/"),(.quickTimeMetadataMake,"QA Camera"),(.quickTimeMetadataModel,"QA Model"),(.quickTimeMetadataDescription,"PRIVATE-COMMENT")] {
            let item = AVMutableMetadataItem();item.identifier = key;item.value = value as NSString;item.dataType = kCMMetadataBaseDataType_UTF8 as String;items.append(item)
        }
        let source = try await VideoFixtures.make(profile:.standard,frames:6,width:128,height:72,metadata:items)
        defer { try? FileManager.default.removeItem(at:source.deletingLastPathComponent()) }
        let descriptor = try await VideoEngine.describe(source),bytes = try Data(contentsOf:source)
        let stripped = try await VideoEngine.export(source:source,descriptor:descriptor,recipe:Recipe(),progress:{ _ in })
        let included = try await VideoEngine.export(source:source,descriptor:descriptor,recipe:Recipe(),privacy:ExportPrivacy(captureDate:true,camera:true,location:true,audio:false),progress:{ _ in })
        defer { try? FileManager.default.removeItem(at:stripped.url);try? FileManager.default.removeItem(at:included.url) }
        let a = AVURLAsset(url:stripped.url),b = AVURLAsset(url:included.url)
        let metadataA = try await a.loadMetadata(for:.quickTimeMetadata),metadataB = try await b.loadMetadata(for:.quickTimeMetadata)
        let keysA = Set(metadataA.compactMap(\.identifier)),keysB = Set(metadataB.compactMap(\.identifier))
        try check(!keysA.contains(.quickTimeMetadataLocationISO6709) && !keysA.contains(.quickTimeMetadataCreationDate) && !keysA.contains(.quickTimeMetadataMake),"Video default metadata leak")
        try check(keysB.contains(.quickTimeMetadataLocationISO6709) && keysB.contains(.quickTimeMetadataCreationDate) && keysB.contains(.quickTimeMetadataMake) && !keysB.contains(.quickTimeMetadataDescription),"Video allowlist")
        let audioA = try await a.loadTracks(withMediaType:.audio),audioB = try await b.loadTracks(withMediaType:.audio)
        try check(audioA.count == 1 && audioB.isEmpty,"Video sound privacy")
        let duration = try await b.load(.duration).seconds
        try check(abs(duration-descriptor.duration)<0.04 && included.width == 128 && included.height == 72,"Video timing/quality geometry")
        try check(try Data(contentsOf:source) == bytes,"Video source changed")
        return ["passed":true,"defaultStrip":true,"allowlist":true,"audioKeptAndRemoved":true,"timingGeometry":true,"originalPreserved":true]
    }
    @MainActor static func writeReport() async {
        let url = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("export-privacy-verification.json")
        do {
            let result = try await Task.detached(priority:.utility) { () -> [String:Any] in
                var report:[String:Any] = ["version":"0.26.0","photo":try await photo(),"passed":true]
                #if !targetEnvironment(simulator)
                report["video"] = try await video()
                #endif
                return report
            }.value
            try JSONSerialization.data(withJSONObject:result,options:.prettyPrinted).write(to:url,options:.atomic)
        } catch { try? JSONSerialization.data(withJSONObject:["version":"0.26.0","passed":false,"error":error.localizedDescription],options:.prettyPrinted).write(to:url,options:.atomic) }
    }
}
#endif

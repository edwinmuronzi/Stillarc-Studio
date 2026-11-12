import Foundation
import ImageIO
import AVFoundation
import SwiftUI

struct ExportPrivacy:Codable,Equatable,Sendable {
    var captureDate = false
    var camera = false
    var location = false
    var audio = true
    var projectNames = false
    static func load(_ defaults:UserDefaults = .standard) -> Self {
        Self(captureDate:defaults.bool(forKey:"export.date"),camera:defaults.bool(forKey:"export.camera"),location:defaults.bool(forKey:"export.location"),audio:defaults.object(forKey:"export.audio") as? Bool ?? true,projectNames:defaults.bool(forKey:"export.names"))
    }
    func save(_ defaults:UserDefaults = .standard) {
        for (key,value) in [("date",captureDate),("camera",camera),("location",location),("audio",audio),("names",projectNames)] { defaults.set(value,forKey:"export."+key) }
    }
    func photoProperties(source:URL) -> [String:Any] {
        var result:[String:Any] = [kCGImagePropertyOrientation as String:1]
        guard captureDate || camera || location,let image = CGImageSourceCreateWithURL(source as CFURL,[kCGImageSourceShouldCache:false] as CFDictionary),let original = CGImageSourceCopyPropertiesAtIndex(image,0,nil) as? [String:Any] else { return result }
        func subset(_ group:CFString,_ keys:[CFString]) -> [String:Any] {
            let values = original[group as String] as? [String:Any] ?? [:]
            var selected:[String:Any] = [:]
            for key in keys { if let value = values[key as String],value is String || value is NSNumber { selected[key as String] = value } }
            return selected
        }
        var exif:[String:Any] = [:]
        if captureDate { exif.merge(subset(kCGImagePropertyExifDictionary,[kCGImagePropertyExifDateTimeOriginal,kCGImagePropertyExifDateTimeDigitized,kCGImagePropertyExifOffsetTimeOriginal,kCGImagePropertyExifOffsetTimeDigitized])) { _,b in b } }
        if camera {
            exif.merge(subset(kCGImagePropertyExifDictionary,[kCGImagePropertyExifExposureTime,kCGImagePropertyExifFNumber,kCGImagePropertyExifFocalLength,kCGImagePropertyExifLensMake,kCGImagePropertyExifLensModel])) { _,b in b }
            let tiff = subset(kCGImagePropertyTIFFDictionary,[kCGImagePropertyTIFFMake,kCGImagePropertyTIFFModel])
            if !tiff.isEmpty { result[kCGImagePropertyTIFFDictionary as String] = tiff }
        }
        if !exif.isEmpty { result[kCGImagePropertyExifDictionary as String] = exif }
        if location {
            let gps = subset(kCGImagePropertyGPSDictionary,[kCGImagePropertyGPSLatitude,kCGImagePropertyGPSLatitudeRef,kCGImagePropertyGPSLongitude,kCGImagePropertyGPSLongitudeRef,kCGImagePropertyGPSAltitude,kCGImagePropertyGPSAltitudeRef])
            if !gps.isEmpty { result[kCGImagePropertyGPSDictionary as String] = gps }
        }
        return result
    }
    func videoMetadata(_ asset:AVAsset) async throws -> [AVMetadataItem] {
        guard captureDate || camera || location else { return [] }
        let formats = try await asset.load(.availableMetadataFormats)
        guard formats.contains(.quickTimeMetadata) else { return [] }
        let source = try await asset.loadMetadata(for:.quickTimeMetadata)
        var allowed:[AVMetadataIdentifier] = []
        if captureDate { allowed.append(.quickTimeMetadataCreationDate) }
        if camera { allowed += [.quickTimeMetadataMake,.quickTimeMetadataModel] }
        if location { allowed.append(.quickTimeMetadataLocationISO6709) }
        var output:[AVMetadataItem] = []
        for identifier in allowed {
            guard let input = source.first(where:{ $0.identifier == identifier }),let value = try await input.load(.stringValue),!value.isEmpty,value.utf8.count<=1024 else { continue }
            let item = AVMutableMetadataItem();item.identifier = identifier;item.value = value as NSString;item.dataType = kCMMetadataBaseDataType_UTF8 as String
            output.append(item)
        }
        return output
    }
}
struct ExportPrivacyControls:View {
    @Binding var policy:ExportPrivacy
    var video = false
    var batch = false
    var body:some View {
        DisclosureGroup("Metadata & privacy") {
            VStack(alignment:.leading,spacing:12) {
                Toggle("Include capture date",isOn:$policy.captureDate)
                Toggle("Include camera details",isOn:$policy.camera)
                Toggle("Include location",isOn:$policy.location)
                if video { Toggle("Keep video sound",isOn:$policy.audio) }
                if batch { Toggle("Use project names in filenames",isOn:$policy.projectNames) }
                if policy.location { Text("Location can reveal where you recorded. Only enable it for files you intend to share with that information.").font(.caption).foregroundStyle(.orange) }
                Text("Copies only the selected details when present in the imported file. Owner names, camera serial numbers, comments and maker notes are omitted. Color profiles and technical playback information remain. Choices are remembered on this device; originals stay untouched.").font(.caption).foregroundStyle(StudioStyle.secondary)
                Button("Remove identifying metadata") { policy.captureDate = false;policy.camera = false;policy.location = false;policy.projectNames = false }
            }.font(.subheadline).padding(.top,12)
        }.onChange(of:policy) { _,value in value.save() }
    }
}

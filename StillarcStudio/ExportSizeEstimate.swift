import Foundation
import SwiftUI

/// Planning ranges, never an encode or an image analysis. Compressed size depends on content.
struct ExportSizeEstimate:Equatable,Sendable {
    var lower:Double
    var upper:Double
    var isPhoto=false
    var label:String {"\(Self.bytes(lower)) – \(Self.bytes(upper))"}
    static func bytes(_ value:Double)->String {
        let safe=value.isFinite ? min(Double(Int64.max/2),max(0,value)):0
        return ByteCountFormatter.string(fromByteCount:Int64(safe.rounded()),countStyle:.file)
    }
    static func dimensions(_ project:Project)->CGSize {
        let source=project.video.map {CGSize(width:$0.width,height:$0.height)} ?? CGSize(width:project.width,height:project.height)
        return PhotoFraming.window(in:PhotoFraming.orientedSize(source,recipe:project.recipe),recipe:project.recipe).size
    }
    static func make(project:Project,format:ExportFormat,privacy:ExportPrivacy,delivery:DeliverySettings)->Self? {
        guard project.width>0,project.height>0,project.width<=100_000,project.height<=100_000 else {return nil}
        let size=delivery.dimensions(dimensions(project),video:project.isVideo)
        guard size.width.isFinite,size.height.isFinite,size.width>0,size.height>0 else {return nil}
        let pixels=size.width*size.height
        if let video=project.video {
            guard video.duration.isFinite,video.duration>0,video.frameRate.isFinite,video.frameRate<=1000 else {return nil}
            let range=project.recipe.video.range(duration:video.duration),duration=range.upperBound-range.lowerBound
            let rate=delivery.codec == .proRes422 ? 147_000_000*(pixels/(1920*1080))*((video.frameRate>0 ? video.frameRate:30)/29.97):Double(delivery.targetVideoBitRate(size:size,frameRate:video.frameRate))
            // Original MOV audio is copied; H.264 sound is encoded at 96/192 kbps per mono/stereo track.
            var audioLow=0.0,audioHigh=0.0
            if privacy.audio {
                if let channels=video.audioChannels,channels.isEmpty {} // Known silent source.
                else if delivery.codec == .h264,let channels=video.audioChannels {
                    audioLow=channels.reduce(0) {$0+($1 == 1 ? 96_000:192_000)};audioHigh=audioLow*1.05
                } else if let source=video.audioDataRate,source.isFinite,source>=0 {audioLow=source*0.95;audioHigh=source*1.05}
                else {audioLow=96_000;audioHigh=delivery.codec == .h264 ? 384_000:3_072_000}
            }
            let factor=delivery.codec == .proRes422 ? 0.65:0.3
            return Self(lower:(rate*factor+audioLow)*duration/8+16_384,upper:(rate*1.2+audioHigh)*duration/8+65_536)
        }
        let format=project.recipe.hasTransparentCutout ? ExportFormat.png:format
        let low:Double,high:Double
        switch format {
        case .png: low=0.15;high=4.1
        case .jpeg:
            switch delivery.quality {case .maximum:low=0.35;high=1.8;case .balanced:low=0.18;high=1.0;case .compact:low=0.1;high=0.6}
        case .hdrHEIF:
            switch delivery.quality {case .maximum:low=0.2;high=1.2;case .balanced:low=0.1;high=0.7;case .compact:low=0.06;high=0.4}
        }
        return Self(lower:pixels*low+4096,upper:pixels*high+16_384,isPhoto:true)
    }
    static func total(projects:[Project],format:ExportFormat,privacy:ExportPrivacy,delivery:DeliverySettings)->Self? {
        guard !projects.isEmpty else {return nil}
        var result=Self(lower:0,upper:0,isPhoto:projects.allSatisfy {!$0.isVideo})
        for project in projects {guard let estimate=make(project:project,format:format,privacy:privacy,delivery:delivery) else {return nil};result.lower+=estimate.lower;result.upper+=estimate.upper}
        return result
    }
    static func total(jobs:[QueueJob])->Self? {
        guard !jobs.isEmpty else {return nil}
        var result=Self(lower:0,upper:0)
        for job in jobs {guard let estimate=total(projects:job.projects,format:job.format,privacy:job.privacy,delivery:job.delivery) else {return nil};result.lower+=estimate.lower;result.upper+=estimate.upper}
        return result
    }
    static func measured(_ urls:[URL]) throws ->Int64 {
        var total:Int64=0
        for url in urls {
            try Task.checkCancellation()
            let values=try url.resourceValues(forKeys:[.fileSizeKey,.isRegularFileKey])
            guard values.isRegularFile==true,let count=values.fileSize,count>=0,Int64(count)<=Int64.max-total else {throw StudioError.unreadable}
            total+=Int64(count)
        }
        return total
    }
}

extension DeliverySettings {
    /// Shared with the encoder so size planning follows the actual bitrate setting.
    func targetVideoBitRate(size:CGSize,frameRate:Double)->Int {
        let pixels=max(1,min(100_000_000,size.width*size.height))
        let fps=frameRate.isFinite ? min(1000,max(24,frameRate)):30
        let base=max(Int(8_000_000*quality.video),min(80_000_000,Int(pixels*fps*0.14*quality.video)))
        return codec == .h264 ? Int(Double(base)*1.4):base
    }
}

struct ExportSizeSummary:View {
    let estimate:ExportSizeEstimate?
    var urls:[URL]=[]
    var completed=false
    var title="Estimated size"
    var compact=false
    @State private var measured:Int64?
    @State private var unavailable=false
    var body:some View {
        VStack(alignment:.leading,spacing:7) {
            HStack(alignment:.firstTextBaseline) {
                Label(completed ? "Actual file size":title,systemImage:"internaldrive").font(.caption.weight(.medium))
                Spacer(minLength:12)
                Text(value).font(.caption.monospacedDigit()).multilineTextAlignment(.trailing).accessibilityIdentifier(completed ? "actualExportSize":"estimatedExportSize")
            }
            if !completed && !compact {Text(estimate?.isPhoto == true ? "Approximate range. Photo detail, grain and transparency affect compression; very simple images can be much smaller. Actual size appears after export." : "Approximate range based on format, size, timing and sound. Motion and image detail affect compression; very simple clips can be much smaller. Actual size appears after export.").font(.caption2).foregroundStyle(StudioStyle.secondary)}
            else if urls.count>1 && !compact {Text("Total for \(urls.count) completed files.").font(.caption2).foregroundStyle(StudioStyle.secondary)}
        }.padding(compact ? 0:14).background(compact ? Color.clear:StudioStyle.panel,in:RoundedRectangle(cornerRadius:16))
        .task(id:MeasurementID(urls:urls,completed:completed)) {
            measured=nil;unavailable=false
            guard completed else {return}
            let worker=Task.detached(priority:.utility){try ExportSizeEstimate.measured(urls)}
            do {let count=try await withTaskCancellationHandler(operation:{try await worker.value},onCancel:{worker.cancel()});if !Task.isCancelled {measured=count}}
            catch {if !Task.isCancelled {unavailable=true}}
        }
    }
    private struct MeasurementID:Hashable {let urls:[URL];let completed:Bool}
    private var value:String {
        if completed {return measured.map {ExportSizeEstimate.bytes(Double($0))} ?? (unavailable ? "Unavailable":"Checking…")}
        return estimate?.label ?? "Unavailable"
    }
}

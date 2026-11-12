#if DEBUG
import AVFoundation
import CoreVideo
import Foundation
import CoreImage

/// Private constant-color fixtures. These are not camera footage or marketing samples.
enum VideoFixtures {
    static let scene = [0.23,0.18,0.12]
    static func make(profile:CameraLogProfile,frames:Int = 18,portrait:Bool = false,audioTracks:Int = 1,width:Int = 640,height:Int = 360,linear:[Double]? = nil,hdr:String? = nil,metadata:[AVMetadataItem] = []) async throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("StudioVideoQA-\(UUID())")
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let url = root.appendingPathComponent("fixture.mov"), wav = root.appendingPathComponent("tone.wav")
        let duration = Double(frames)/30
        var pcm = Data()
        for n in 0..<Int(duration*48000) { var v = Int16(sin(Double(n)*2*Double.pi*440/48000)*2000).littleEndian;withUnsafeBytes(of:&v) { pcm.append(contentsOf:$0) } }
        var wave = Data("RIFF".utf8)
        func u32(_ v:UInt32) { var v = v.littleEndian;withUnsafeBytes(of:&v) { wave.append(contentsOf:$0) } }
        func u16(_ v:UInt16) { var v = v.littleEndian;withUnsafeBytes(of:&v) { wave.append(contentsOf:$0) } }
        u32(UInt32(36+pcm.count));wave.append(Data("WAVEfmt ".utf8));u32(16);u16(1);u16(1);u32(48000);u32(96000);u16(2);u16(16);wave.append(Data("data".utf8));u32(UInt32(pcm.count));wave.append(pcm);try wave.write(to:wav)
        let audioAsset = AVURLAsset(url:wav)
        guard let audioTrack = try await audioAsset.loadTracks(withMediaType:.audio).first else { throw StudioError.render }
        let reader = try AVAssetReader(asset:audioAsset)
        let audioOutput = AVAssetReaderTrackOutput(track:audioTrack,outputSettings:nil);reader.add(audioOutput)
        let writer = try AVAssetWriter(outputURL:url,fileType:.mov)
        writer.metadata = metadata
        #if targetEnvironment(simulator)
        let format = kCVPixelFormatType_32BGRA
        #else
        let format = kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        #endif
        let attributes:[String:Any] = [kCVPixelBufferPixelFormatTypeKey as String:format,kCVPixelBufferWidthKey as String:width,kCVPixelBufferHeightKey as String:height,kCVPixelBufferIOSurfacePropertiesKey as String:[:]]
        var buffer:CVPixelBuffer?
        guard CVPixelBufferCreate(nil,width,height,format,attributes as CFDictionary,&buffer) == kCVReturnSuccess,let buffer else { throw StudioError.render }
        let values = linear ?? scene
        let rgb = profile == .standard ? values.map { v in v <= 0.0031308 ? v*12.92 : 1.055*pow(v,1/2.4)-0.055 } : values.map(LogConversion.encode)
        let y = rgb[0]*0.2627+rgb[1]*0.6780+rgb[2]*0.0593,u = (rgb[2]-y)/(2*(1-0.0593)),v = (rgb[0]-y)/(2*(1-0.2627))
        CVPixelBufferLockBaseAddress(buffer,[])
        if CVPixelBufferIsPlanar(buffer) {
            let yy = UInt16(min(1023,max(0,(64+y*876).rounded())))<<6,uu = UInt16(min(1023,max(0,(512+u*896).rounded())))<<6,vv = UInt16(min(1023,max(0,(512+v*896).rounded())))<<6
            for row in 0..<height {
                let base = CVPixelBufferGetBaseAddressOfPlane(buffer,0)!.advanced(by:row*CVPixelBufferGetBytesPerRowOfPlane(buffer,0)).assumingMemoryBound(to:UInt16.self)
                for col in 0..<width { base[col] = yy }
            }
            for row in 0..<(height/2) {
                let base = CVPixelBufferGetBaseAddressOfPlane(buffer,1)!.advanced(by:row*CVPixelBufferGetBytesPerRowOfPlane(buffer,1)).assumingMemoryBound(to:UInt16.self)
                for col in stride(from:0,to:width,by:2) { base[col] = uu;base[col+1] = vv }
            }
        } else {
            for row in 0..<height {
                let base = CVPixelBufferGetBaseAddress(buffer)!.advanced(by:row*CVPixelBufferGetBytesPerRow(buffer)).assumingMemoryBound(to:UInt8.self)
                for col in 0..<width { base[col*4] = UInt8((rgb[2]*255).rounded());base[col*4+1] = UInt8((rgb[1]*255).rounded());base[col*4+2] = UInt8((rgb[0]*255).rounded());base[col*4+3] = 255 }
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer,[])
        CVBufferSetAttachment(buffer,kCVImageBufferYCbCrMatrixKey,kCVImageBufferYCbCrMatrix_ITU_R_2020,.shouldPropagate)
        CVBufferSetAttachment(buffer,kCVImageBufferColorPrimariesKey,kCVImageBufferColorPrimaries_ITU_R_2020,.shouldPropagate)
        CVBufferSetAttachment(buffer,kCVImageBufferTransferFunctionKey,kCVImageBufferTransferFunction_ITU_R_709_2,.shouldPropagate)
        if #available(iOS 17.2,*),profile != .standard {
            CVBufferRemoveAttachment(buffer,kCVImageBufferTransferFunctionKey)
            if #available(iOS 27,*) { CVBufferSetAttachment(buffer,kCVImageBufferLogTransferFunctionKey,profile == .appleLog ? kCVImageBufferLogTransferFunction_AppleLog : kCVImageBufferLogTransferFunction_AppleLog2,.shouldPropagate) }
            else { CVBufferSetAttachment(buffer,kCVImageBufferLogTransferFunctionKey,kCVImageBufferLogTransferFunction_AppleLog,.shouldPropagate) }
            if profile == .appleLog2 { CVBufferRemoveAttachment(buffer,kCVImageBufferColorPrimariesKey) }
        }
        if let hdr {
            let transfer = hdr == "PQ" ? kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ : kCVImageBufferTransferFunction_ITU_R_2100_HLG
            if #available(iOS 17.2,*) { CVBufferRemoveAttachment(buffer,kCVImageBufferLogTransferFunctionKey) }
            CVBufferSetAttachment(buffer,kCVImageBufferColorPrimariesKey,kCVImageBufferColorPrimaries_ITU_R_2020,.shouldPropagate)
            CVBufferSetAttachment(buffer,kCVImageBufferTransferFunctionKey,transfer,.shouldPropagate)
            let color = CIColor(red:values[0],green:values[1],blue:values[2],alpha:1,colorSpace:ImageEngine.working)!
            let image = CIImage(color:color).cropped(to:CGRect(x:0,y:0,width:width,height:height))
            ImageEngine.context().render(image,to:buffer,bounds:image.extent,colorSpace:hdr == "PQ" ? CGColorSpace(name:CGColorSpace.itur_2100_PQ)! : HDRPipeline.hlg)
        }
        var settings:[String:Any] = [AVVideoCodecKey:AVVideoCodecType.hevc,AVVideoWidthKey:width,AVVideoHeightKey:height,AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:3_000_000]]
        if #available(iOS 27,*),profile != .standard {
            var color:[String:Any] = [AVVideoYCbCrMatrixKey:AVVideoYCbCrMatrix_ITU_R_2020,AVVideoLogTransferFunctionKey:profile == .appleLog ? AVVideoLogTransferFunction_AppleLog : AVVideoLogTransferFunction_AppleLog2]
            if profile == .appleLog { color[AVVideoColorPrimariesKey] = AVVideoColorPrimaries_ITU_R_2020 }
            settings[AVVideoColorPropertiesKey] = color
        }
        if profile != .standard { settings[AVVideoCompressionPropertiesKey] = [AVVideoAverageBitRateKey:3_000_000,AVVideoProfileLevelKey:"HEVC_Main10_AutoLevel"] }
        if let hdr {
            settings[AVVideoColorPropertiesKey] = [AVVideoColorPrimariesKey:AVVideoColorPrimaries_ITU_R_2020,AVVideoTransferFunctionKey:hdr == "PQ" ? AVVideoTransferFunction_SMPTE_ST_2084_PQ : AVVideoTransferFunction_ITU_R_2100_HLG,AVVideoYCbCrMatrixKey:AVVideoYCbCrMatrix_ITU_R_2020]
            settings[AVVideoCompressionPropertiesKey] = [AVVideoAverageBitRateKey:3_000_000,AVVideoProfileLevelKey:"HEVC_Main10_AutoLevel"]
        }
        let input = AVAssetWriterInput(mediaType:.video,outputSettings:settings)
        if portrait { input.transform = CGAffineTransform(a:0,b:1,c:-1,d:0,tx:CGFloat(height),ty:0) }
        writer.add(input)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:attributes)
        let audioInputs = (0..<audioTracks).map { _ in AVAssetWriterInput(mediaType:.audio,outputSettings:[AVFormatIDKey:kAudioFormatMPEG4AAC,AVSampleRateKey:48000,AVNumberOfChannelsKey:1,AVEncoderBitRateKey:64000]) }
        for audio in audioInputs { writer.add(audio) }
        guard writer.startWriting(),reader.startReading() else { throw writer.error ?? StudioError.render };writer.startSession(atSourceTime:.zero)
        try await withThrowingTaskGroup(of:Void.self) { group in
            group.addTask {
                for frame in 0..<frames {
                    while !input.isReadyForMoreMediaData { guard writer.status == .writing else { throw writer.error ?? StudioError.render };try await Task.sleep(for:.milliseconds(2)) }
                    guard adaptor.append(buffer,withPresentationTime:CMTime(value:Int64(frame),timescale:30)) else { throw writer.error ?? StudioError.render }
                }
                input.markAsFinished()
            }
            group.addTask {
                while let sample = audioOutput.copyNextSampleBuffer() {
                    for input in audioInputs {
                        while !input.isReadyForMoreMediaData { guard writer.status == .writing else { throw writer.error ?? StudioError.render };try await Task.sleep(for:.milliseconds(2)) }
                        guard input.append(sample) else { throw writer.error ?? StudioError.render }
                    }
                }
                audioInputs.forEach { $0.markAsFinished() }
            }
            while let _ = try await group.next() {}
        }
        await writer.finishWriting();guard writer.status == .completed else { throw writer.error ?? StudioError.render }
        try? FileManager.default.removeItem(at:wav)
        return url
    }
}
#endif

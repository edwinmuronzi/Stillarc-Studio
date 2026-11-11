import SwiftUI
import CoreImage

enum ScopeMode:String,CaseIterable { case histogram = "Histogram",waveform = "Waveform",vectorscope = "Vectorscope" }
struct ScopeSnapshot:@unchecked Sendable {
    var histogram = [[Int]](repeating:[Int](repeating:0,count:256),count:3)
    var waveform:CGImage?
    var vectorscope:CGImage?
    var hdr = false
    var ceiling = 0.0
}
@MainActor @Observable final class ScopeSampler {
    var snapshot = ScopeSnapshot()
    var enabled = false
    #if DEBUG
    var completed = 0
    var analysisTimes = [Double]()
    #endif
    private var busy = false
    private var last = 0.0
    private var generation = 0
    private let worker = DispatchQueue(label:"Studio.Scopes",qos:.utility)
    func setEnabled(_ value:Bool) { if enabled != value { enabled = value;generation += 1;last = 0 } }
    func offer(_ image:CIImage,hdr:Bool) {
        let now = CACurrentMediaTime()
        guard enabled,!busy,now-last>=0.2 else { return }
        busy = true;last = now
        let token = generation
        worker.async {
            let began = CACurrentMediaTime()
            let snapshot = autoreleasepool { ScopeAnalysis.analyze(image,hdr:hdr) }
            Task { @MainActor [weak self] in
                guard let self else { return };self.busy = false
                #if DEBUG
                self.completed += 1;self.analysisTimes.append((CACurrentMediaTime()-began)*1000)
                #endif
                if self.enabled && self.generation == token { self.snapshot = snapshot }
            }
        }
    }
}
enum ScopeAnalysis {
    private static let context = ImageEngine.context()
    static func analyze(_ image:CIImage,hdr:Bool) -> ScopeSnapshot {
        let w = 128,h = 72,n = w*h
        let normalized = image.transformed(by:.init(translationX:-image.extent.minX,y:-image.extent.minY)).transformed(by:.init(scaleX:Double(w)/image.extent.width,y:Double(h)/image.extent.height))
        var pixels = [Float](repeating:0,count:n*4)
        context.render(normalized,toBitmap:&pixels,rowBytes:w*16,bounds:CGRect(x:0,y:0,width:w,height:h),format:.RGBAf,colorSpace:hdr ? ImageEngine.working : ImageEngine.output)
        return analyze(pixels,width:w,height:h,hdr:hdr)
    }
    static func analyze(_ pixels:[Float],width:Int,height:Int,hdr:Bool) -> ScopeSnapshot {
        var result = ScopeSnapshot();result.hdr = hdr
        var wave = [Int](repeating:0,count:128*64*3),vector = [Int](repeating:0,count:128*128*4),ceiling = 0
        guard width>0,height>0,pixels.count == width*height*4 else { return result }
        for i in 0..<(width*height) {
            func value(_ c:Int) -> Double { let v = Double(pixels[i*4+c]);return v.isFinite ? max(0,v) : 0 }
            let red = value(0),green = value(1),blue = value(2),maximum = max(red,max(green,blue))
            let scale = hdr ? 8.0 : 1.0
            if maximum >= scale { ceiling += 1 }
            for c in 0..<3 {
                let v = min(1,(c == 0 ? red : c == 1 ? green : blue)/scale),bin = min(255,Int(v*255)),x = min(127,(i%width)*128/width),y = 63-min(63,Int(v*63))
                result.histogram[c][bin] += 1;wave[(y*128+x)*3+c] += 1
            }
            let peak = max(1,maximum),r = red/peak,g = green/peak,b = blue/peak,y = 0.2126*r+0.7152*g+0.0722*b
            let vx = min(127,max(0,Int(((b-y)/1.8556+0.5)*127))),vy = min(127,max(0,Int((0.5-(r-y)/1.5748)*127))),base = (vy*128+vx)*4
            vector[base] += Int(r*255);vector[base+1] += Int(g*255);vector[base+2] += Int(b*255);vector[base+3] += 1
        }
        var waveBytes = [UInt8](repeating:0,count:128*64*4),vectorBytes = [UInt8](repeating:0,count:128*128*4)
        for i in 0..<(128*64) { for c in 0..<3 { waveBytes[i*4+c] = UInt8(min(255,Int(sqrt(Double(wave[i*3+c]))*85))) };waveBytes[i*4+3] = 255 }
        for i in 0..<(128*128) {
            let count = vector[i*4+3]
            if count>0 { for c in 0..<3 { vectorBytes[i*4+c] = UInt8(min(255,max(40,vector[i*4+c]/count))) } }
            vectorBytes[i*4+3] = 255
        }
        func raster(_ bytes:[UInt8],height:Int) -> CGImage? {
            guard let provider = CGDataProvider(data:Data(bytes) as CFData) else { return nil }
            return CGImage(width:128,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:512,space:ImageEngine.output,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent)
        }
        result.waveform = raster(waveBytes,height:64);result.vectorscope = raster(vectorBytes,height:128);result.ceiling = Double(ceiling)/Double(width*height)
        return result
    }
}
struct ScopePanel:View {
    @Bindable var sampler:ScopeSampler
    @Binding var mode:ScopeMode
    var body:some View {
        VStack(spacing:6) {
            Picker("Scope",selection:$mode) { ForEach(ScopeMode.allCases,id:\.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            Canvas { context,size in
                let snapshot = sampler.snapshot
                if mode == .histogram {
                    let peak = max(1,snapshot.histogram.flatMap { $0 }.max() ?? 1)
                    for c in 0..<3 {
                        var path = Path()
                        for x in 0..<256 { let point = CGPoint(x:Double(x)/255*size.width,y:size.height*(1-log1p(Double(snapshot.histogram[c][x]))/log1p(Double(peak))));if x == 0 { path.move(to:point) } else { path.addLine(to:point) } }
                        context.stroke(path,with:.color([Color.red,.green,.blue][c].opacity(0.85)),lineWidth:1)
                    }
                } else if let image = mode == .waveform ? snapshot.waveform : snapshot.vectorscope {
                    let side = min(size.width,size.height),rect = mode == .vectorscope ? CGRect(x:(size.width-side)/2,y:0,width:side,height:side) : CGRect(origin:.zero,size:size)
                    context.draw(Image(decorative:image,scale:1),in:rect)
                    var grid = Path()
                    if mode == .vectorscope { grid.addEllipse(in:rect);grid.move(to:CGPoint(x:rect.midX,y:rect.minY));grid.addLine(to:CGPoint(x:rect.midX,y:rect.maxY));grid.move(to:CGPoint(x:rect.minX,y:rect.midY));grid.addLine(to:CGPoint(x:rect.maxX,y:rect.midY)) }
                    else { for n in 1...3 { let y = size.height*Double(n)/4;grid.move(to:CGPoint(x:0,y:y));grid.addLine(to:CGPoint(x:size.width,y:y)) } }
                    context.stroke(grid,with:.color(.white.opacity(0.2)),lineWidth:0.5)
                }
            }.frame(height:80).background(.black,in:RoundedRectangle(cornerRadius:8)).accessibilityLabel(mode.rawValue+" of the current preview")
            Text(sampler.snapshot.hdr ? "HDR · linear 0–8× SDR white" : "SDR · RGB 0–100% · sampled preview").font(.system(size:9,design:.monospaced)).foregroundStyle(StudioStyle.secondary)
        }.padding(10).background(StudioStyle.panel)
    }
}

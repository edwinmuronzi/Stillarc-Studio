import SwiftUI

struct PhotoDevelopmentSheet:View {
    @Bindable var session:EditSession
    @Binding var sdrProof:Bool
    @Environment(\.dismiss) private var dismiss
    private var raw:RawDevelopment {session.recipe.rawDevelopment ?? RawDevelopment()}
    private func update(_ body:(inout RawDevelopment)->Void) {session.change {var s=$0.rawDevelopment ?? RawDevelopment();body(&s);$0.rawDevelopment=s}}
    private func rawSlider(_ name:String,_ key:WritableKeyPath<RawDevelopment,Double?>,_ fallback:Double,_ range:ClosedRange<Double>) -> some View {
        VStack {HStack {Text(name);Spacer();Text(raw[keyPath:key] ?? fallback,format:.number.precision(.fractionLength(1))).monospacedDigit()}.font(.caption)
            Slider(value:Binding(get:{min(range.upperBound,max(range.lowerBound,raw[keyPath:key] ?? fallback))},set:{value in var s=raw;s[keyPath:key]=value;session.recipe.rawDevelopment=s}),in:range,onEditingChanged:{$0 ? session.begin():session.end()}).accessibilityLabel(name).sliderReset {update {$0[keyPath:key]=nil}}
        }
    }
    private func opticsSlider(_ name:String,_ key:WritableKeyPath<PhotoOptics,Double>,_ range:ClosedRange<Double>) -> some View {
        VStack {Text(name).font(.caption);Slider(value:Binding(get:{(session.recipe.optics ?? PhotoOptics())[keyPath:key]},set:{value in var s=session.recipe.optics ?? PhotoOptics();s[keyPath:key]=value;session.recipe.optics=s}),in:range,onEditingChanged:{$0 ? session.begin():session.end()}).accessibilityLabel(name).sliderReset {session.change {var s=$0.optics ?? PhotoOptics();s[keyPath:key]=0;$0.optics=s}}}
    }
    var body:some View {
        NavigationStack {ScrollView {VStack(alignment:.leading,spacing:22) {
            if let cap=session.source?.rawCapabilities {
                Text("RAW development").font(.title2.bold())
                Text("Develop the original sensor data. White balance changes the color of the light; RAW exposure changes brightness before the creative grade. The settled preview is re-developed after you lift your finger.").font(.caption).foregroundStyle(StudioStyle.secondary)
                rawSlider("RAW temperature · K",\.temperature,cap.temperature,2000...50000)
                rawSlider("RAW tint",\.tint,cap.tint,-150...150)
                VStack {HStack {Text("RAW exposure");Spacer();Text(raw.exposure,format:.number.precision(.fractionLength(2)))}.font(.caption)
                    Slider(value:Binding(get:{raw.exposure},set:{v in var s=raw;s.exposure=v;session.recipe.rawDevelopment=s}),in:-4...4,onEditingChanged:{$0 ? session.begin():session.end()}).accessibilityLabel("RAW exposure").sliderReset {update {$0.exposure=0}}}
                rawSlider("RAW rendering boost",\.boost,cap.boost,0...1)
                if cap.lens {Toggle("Camera lens profile",isOn:Binding(get:{raw.lensProfile ?? cap.lensEnabled},set:{v in update {$0.lensProfile=v}}));Text("Uses the correction supplied by Apple's RAW decoder for this camera. Changing it recreates automatic selections.").font(.caption).foregroundStyle(StudioStyle.secondary)}
                if cap.recovery {Toggle("Recover RAW highlights",isOn:Binding(get:{raw.recoverHighlights ?? cap.recoveryEnabled},set:{v in update {$0.recoverHighlights=v}}));Text("Attempts to recover bright sensor detail. Fully clipped highlights cannot be recovered.").font(.caption).foregroundStyle(StudioStyle.secondary)}
                if cap.colorNoise {rawSlider("RAW color noise",\.colorNoise,cap.colorNoiseAmount,0...1)}
                if cap.luminanceNoise {rawSlider("RAW luminance noise",\.luminanceNoise,cap.luminanceNoiseAmount,0...1)}
                Button("Reset RAW development"){session.change {$0.rawDevelopment=nil}}
            } else {Text("RAW development controls appear for supported RAW originals.").font(.caption).foregroundStyle(StudioStyle.secondary)}
            Divider();Text("Optics").font(.title2.bold())
            opticsSlider("Chromatic aberration",\.chromatic,-1...1)
            opticsSlider("Defringe",\.defringe,0...1)
            VStack {Text("Chroma noise cleanup").font(.caption);Slider(value:Binding(get:{session.recipe.optics?.chromaNoise ?? 0},set:{v in var value=session.recipe.optics ?? PhotoOptics();value.chromaNoise=v;session.recipe.optics=value}),in:0...1,onEditingChanged:{$0 ? session.begin():session.end()}).accessibilityLabel("Chroma noise cleanup").sliderReset {session.change {$0.optics?.chromaNoise=nil}}}
            Text("Softens coloured noise while retaining original brightness detail. Use lightly around fine coloured edges. This is spatial filtering, not AI or multi-frame reconstruction.").font(.caption).foregroundStyle(StudioStyle.secondary)
            Text("Chromatic aberration aligns red and blue edges. Defringe reduces purple/green color fringing; inspect small details before using a strong setting. Use small adjustments to keep fine detail natural.").font(.caption).foregroundStyle(StudioStyle.secondary)
            Divider();Text("HDR stills").font(.title2.bold())
            Toggle("Develop in HDR",isOn:Binding(get:{session.recipe.photoHDR == true},set:{v in session.change {$0.photoHDR=v}}))
            if session.recipe.photoHDR == true {Toggle("SDR proof",isOn:$sdrProof)}
            Text("HDR preserves available bright detail from supported originals for compatible screens. SDR proof shows the tone-mapped JPEG/PNG appearance. Export HDR HEIF for 10-bit HLG output; HDR cannot create missing highlight detail.").font(.caption).foregroundStyle(StudioStyle.secondary)
        }.padding(22)}.safeAreaInset(edge:.top) {if let photo=session.source {LivePreview(source:PhotoRendering.rawPreview(photo,recipe:session.recipe),recipe:session.recipe,original:false,hdr:session.recipe.photoHDR == true && !sdrProof).frame(height:220).clipShape(RoundedRectangle(cornerRadius:16)).padding(.horizontal,16).padding(.bottom,8)}}.background(StudioStyle.ink).navigationTitle("Photo development").navigationBarTitleDisplayMode(.inline).toolbar {Button("Done"){dismiss()}}}.tint(StudioStyle.blue).presentationDetents([.large])
    }
}

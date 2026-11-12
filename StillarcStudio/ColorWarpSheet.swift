import SwiftUI

struct ColorWarpSheet:View {
    @Bindable var session:EditSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var poster:PreparedPhoto?
    @State private var posterError:String?
    @State private var selected:UUID?
    @State private var editingMap=false
    @State private var dragOrigin:ColorWarpPoint?
    private var warp:ColorWarp {session.recipe.colorWarp ?? ColorWarp()}
    private var point:ColorWarpPoint? {warp.points.first {$0.id == selected} ?? warp.points.first}
    var body:some View {
        NavigationStack {
            VStack(spacing:0) {
                if let source=session.project.isVideo ? poster:session.source {
                    LivePreview(source:PhotoRendering.rawPreview(source,recipe:session.recipe),recipe:proofRecipe,signalSource:source.signalImage,original:false,active:phase == .active,hdr:false,stillFrame:session.project.isVideo ? .init(time:firstTime,framing:MaskMotion.signature(session.recipe)):nil)
                        .frame(maxWidth:.infinity,maxHeight:.infinity).clipShape(RoundedRectangle(cornerRadius:20)).padding(12)
                }
                if let posterError {Text(posterError).font(.caption).foregroundStyle(.orange)}
                ScrollView {
                    VStack(alignment:.leading,spacing:16) {
                        Text("Move a color, keep the mood.").font(.headline)
                        Text("Choose up to four color points. Hue changes the color; richness changes how colorful it is. Nearby colors blend smoothly. Gray stays neutral. Video shows its first kept frame here; review playback after closing.").font(.caption).foregroundStyle(StudioStyle.secondary)
                        HStack {
                            Menu {ForEach(Array(warp.points.enumerated()),id:\.element.id) {i,p in Button("Color point \(i+1)"){selected=p.id}}} label:{Label("Color point \((warp.points.firstIndex(where:{$0.id == point?.id}) ?? 0)+1)",systemImage:"circle.grid.2x2")}.disabled(warp.points.isEmpty).accessibilityIdentifier("warpPointMenu")
                            Spacer()
                            Button("Add point") {var p=ColorWarpPoint();p.hue=Double((warp.points.count*90+210)%360);session.change {var w=$0.colorWarp ?? ColorWarp();w.points.append(p);$0.colorWarp=w};selected=p.id}.disabled(warp.points.count>=4).accessibilityIdentifier("addWarpPoint")
                        }
                        if let point {
                            Toggle("Edit color map",isOn:$editingMap).toggleStyle(.button).accessibilityIdentifier("editWarpMap")
                            map(point).frame(height:126)
                            Text(editingMap ? "Drag the white point left/right for hue, up/down for richness. Turn off Edit color map to scroll freely." : "The hollow point is the original color; the filled point shows this control’s direction. Overlapping points blend together. Turn on Edit color map to drag it.").font(.caption).foregroundStyle(StudioStyle.secondary)
                            control("Source hue",key:\.hue,range:0...360,defaultValue:210,unit:"°")
                            control("Source richness",key:\.saturation,range:0...1,defaultValue:0.6)
                            control("Hue move",key:\.hueShift,range:-60...60,defaultValue:0,unit:"°")
                            control("Richness move",key:\.saturationShift,range:-0.5...0.5,defaultValue:0)
                            DisclosureGroup("Colors affected") {
                                control("Hue reach",key:\.hueWidth,range:5...120,defaultValue:60,unit:"°")
                                control("Richness reach",key:\.saturationWidth,range:0.05...1,defaultValue:0.5)
                            }
                            HStack {
                                Button("Reset point"){session.change {r in guard var w=r.colorWarp,let i=w.points.firstIndex(where:{$0.id == point.id}) else{return};w.points[i].hueShift=0;w.points[i].saturationShift=0;r.colorWarp=w}}
                                Spacer()
                                Button("Delete point",role:.destructive){session.change {$0.colorWarp?.points.removeAll {$0.id == point.id}};selected=nil}
                            }.font(.caption)
                        }
                        if !warp.points.isEmpty {
                            HStack {Text("Warp strength");Spacer();Text("\(Int(warp.amount*100))%").monospacedDigit()}.font(.caption)
                            Slider(value:Binding(get:{warp.amount},set:{v in session.recipe.colorWarp?.amount=v}),in:0...1,onEditingChanged:{$0 ? session.begin():session.end()}).accessibilityLabel("Warp strength").sliderReset {session.change {$0.colorWarp?.amount=1}}
                            Button("Reset Color Warp",role:.destructive){session.change {$0.colorWarp=nil};selected=nil}.font(.caption)
                        }
                        Text("This is a global color edit, not an object selection. SDR proof is shown here; your HDR output choice stays unchanged.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    }.padding(20)
                }.frame(maxHeight:300).background(StudioStyle.panel)
            }.background(StudioStyle.ink).navigationTitle("Color Warp").navigationBarTitleDisplayMode(.inline).toolbar {Button("Done"){session.end();dismiss()}}
        }.tint(StudioStyle.blue).task {await loadPoster()}.onDisappear {session.end()}
    }
    private var firstTime:Double {session.project.video.map {session.recipe.video.range(duration:$0.duration).lowerBound} ?? 0}
    private var proofRecipe:Recipe {var r=session.recipe;if session.project.isVideo {r.photoHDR=r.video.hdr};return r}
    private func loadPoster() async {
        guard let video=session.project.video,let url=session.sourceURL else{return};let time=firstTime
        do {let worker=Task.detached(priority:.utility){try await VideoEngine.poster(url,descriptor:video,maxDimension:1536,time:time)};let loaded=try await withTaskCancellationHandler(operation:{try await worker.value},onCancel:{worker.cancel()});if !Task.isCancelled {poster=loaded}}
        catch {if !Task.isCancelled {posterError=error.localizedDescription}}
    }
    private func update(_ key:WritableKeyPath<ColorWarpPoint,Double>,_ value:Double) {guard let id=point?.id else{return};if let i=session.recipe.colorWarp?.points.firstIndex(where:{$0.id == id}) {session.recipe.colorWarp?.points[i][keyPath:key]=value}}
    private func control(_ name:String,key:WritableKeyPath<ColorWarpPoint,Double>,range:ClosedRange<Double>,defaultValue:Double,unit:String="")->some View {
        VStack(alignment:.leading,spacing:6) {
            HStack {Text(name);Spacer();Text(String(format:unit.isEmpty ? "%.2f":"%.0f°",point?[keyPath:key] ?? defaultValue)).monospacedDigit()}.font(.caption)
            Slider(value:Binding(get:{point?[keyPath:key] ?? defaultValue},set:{update(key,$0)}),in:range,onEditingChanged:{$0 ? session.begin():session.end()}).accessibilityLabel(name).sliderReset {session.begin();update(key,defaultValue);session.end()}
        }
    }
    private func map(_ p:ColorWarpPoint)->some View {
        GeometryReader {g in
            let w=g.size.width,h=g.size.height
            ZStack {
                LinearGradient(colors:(0...12).map {Color(hue:Double($0)/12,saturation:0.9,brightness:0.85)},startPoint:.leading,endPoint:.trailing)
                    .overlay(LinearGradient(colors:[.clear,Color.gray.opacity(0.95)],startPoint:.top,endPoint:.bottom))
                Path {path in path.move(to:CGPoint(x:p.hue/360*w,y:(1-p.saturation)*h));path.addLine(to:CGPoint(x:targetHue(p)/360*w,y:(1-targetSaturation(p))*h))}.stroke(.white.opacity(0.7),style:StrokeStyle(lineWidth:1,dash:[3,3]))
                Circle().stroke(.white,lineWidth:2).frame(width:12,height:12).position(x:p.hue/360*w,y:(1-p.saturation)*h)
                Circle().fill(.white).frame(width:18,height:18).shadow(radius:2).position(x:targetHue(p)/360*w,y:(1-targetSaturation(p))*h)
            }.clipShape(RoundedRectangle(cornerRadius:14)).contentShape(Rectangle()).overlay {if editingMap {Color.clear.contentShape(Rectangle()).gesture(DragGesture(minimumDistance:2).onChanged {value in
                if dragOrigin == nil {dragOrigin=point;session.begin()}
                guard let origin=dragOrigin else{return}
                update(\.hueShift,min(60,max(-60,origin.hueShift+value.translation.width/w*360)))
                update(\.saturationShift,min(0.5,max(-0.5,origin.saturationShift-value.translation.height/h)))
            }.onEnded {_ in dragOrigin=nil;session.end()})}}.accessibilityElement(children:.ignore).accessibilityIdentifier("warpMap").accessibilityLabel("Color warp map").accessibilityValue(editingMap ? "Editing":"Scroll mode")
        }
    }
    private func targetHue(_ p:ColorWarpPoint)->Double {(p.hue+p.hueShift*warp.amount+360).truncatingRemainder(dividingBy:360)}
    private func targetSaturation(_ p:ColorWarpPoint)->Double {min(1,max(0,p.saturation+p.saturationShift*warp.amount))}
}

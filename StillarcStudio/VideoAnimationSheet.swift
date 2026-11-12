import SwiftUI

struct VideoAnimationSheet:View {
    @Bindable var session:EditSession
    var pool:EditingPool? = nil
    var undoAction:()->Void={}
    var redoAction:()->Void={}
    var initialTime=0.0
    var onFinish:(Double)->Void={_ in}
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var position=ClipPosition()
    @State private var target=AnimationTarget.exposure
    @State private var selectedPoint:UUID?
    @State private var draft=0.0
    private var animation:VideoAnimation {session.recipe.videoAnimation ?? VideoAnimation()}
    private var track:AnimationTrack {animation.tracks.first {$0.target==target} ?? AnimationTrack(target:target)}
    private var duration:Double {session.project.video?.duration ?? 1}
    private var range:ClosedRange<Double> {session.recipe.video.range(duration:duration)}
    private var step:Double {1/max(1,session.project.video?.frameRate ?? 30)}
    private var time:Double {min(range.upperBound,max(range.lowerBound,position.time))}
    private var targets:[AnimationTarget] {[.exposure,.look,.lut]+session.recipe.masks.map {.mask($0.id)}}
    private var currentPoint:AnimationPoint? {track.points.first {abs($0.time-time)<step*0.6}}
    var body:some View {
        NavigationStack {
            GeometryReader {geometry in
                let wide=geometry.size.width>geometry.size.height*1.3
                let layout=wide ? AnyLayout(HStackLayout(spacing:0)):AnyLayout(VStackLayout(spacing:0))
                layout {
                if let descriptor=session.project.video,let url=session.sourceURL,let poster=session.source {
                    VideoPreview(url:url,descriptor:descriptor,poster:poster,recipe:session.recipe,original:false,active:phase == .active && pool?.historyBusy != true,showTrimButton:false,position:position)
                        .frame(maxWidth:.infinity,maxHeight:.infinity).clipShape(RoundedRectangle(cornerRadius:18)).padding(12).accessibilityIdentifier("animationPreview")
                }
                ScrollView {
                    VStack(alignment:.leading,spacing:14) {
                        Menu {ForEach(targets) {item in Button(title(item)){target=item;selectedPoint=nil;draft=item.neutral}}} label:{Label(title(target),systemImage:"diamond")}.accessibilityIdentifier("animationTarget")
                        Text("Pause or scrub to a moment. Drag the value to add or update a point live, or tap Set point to capture the shown value. Two or more points blend the change over time. Exposure shifts add to your main exposure; fades multiply the existing effect strength.").font(.caption).foregroundStyle(StudioStyle.secondary)
                        if target == .look && session.recipe.look == .original {Text("Choose a look in Film first to see a look fade.").font(.caption).foregroundStyle(StudioStyle.secondary)}
                        if target == .lut && session.recipe.lut == nil {Text("Import a LUT first to see a LUT fade.").font(.caption).foregroundStyle(StudioStyle.secondary)}
                        HStack {
                            Text(String(format:"%.2f s",time-range.lowerBound)).monospacedDigit()
                            Spacer()
                            if position.playing {Button("Pause to set a point"){position.pause()}}
                            Button("Start"){position.seek(range.lowerBound)}
                            Button("End"){position.seek(max(range.lowerBound,range.upperBound-step))}
                        }.font(.caption).buttonStyle(.bordered)
                        HStack {Text(target == .exposure ? "Exposure shift":"Fade strength");Spacer();Text(target == .exposure ? String(format:"%+.2f EV",draft):String(format:"%.0f%%",draft*100)).monospacedDigit()}.font(.caption)
                        Slider(value:Binding(get:{draft},set:{value in draft=value;upsert(value)}),in:target.range,onEditingChanged:{$0 ? session.begin():session.end()}).disabled(position.playing).accessibilityLabel("Animation value").sliderReset {session.begin();draft=target.neutral;upsert(target.neutral);session.end()}
                        HStack {
                            Button(currentPoint == nil ? "Set point":"Update point",systemImage:"diamond.fill"){setPoint()}.buttonStyle(.borderedProminent).disabled(position.playing || (track.points.count>=32 && currentPoint==nil)).accessibilityIdentifier("setAnimationPoint")
                            Spacer()
                            Text("\(track.points.count)/32 points").font(.caption).foregroundStyle(StudioStyle.secondary)
                        }
                        if !track.points.isEmpty {
                            Picker("Blend",selection:Binding(get:{track.blend},set:{value in edit {$0.blend=value}})){ForEach(AnimationBlend.allCases,id:\.self){Text($0.rawValue).tag($0)}}.pickerStyle(.segmented)
                            Toggle("Animation on",isOn:Binding(get:{track.enabled},set:{value in edit {$0.enabled=value}}))
                            ScrollView(.horizontal,showsIndicators:false) {HStack(spacing:8) {ForEach(track.points) {p in Button {selectedPoint=p.id;draft=p.value;position.seek(p.time)} label:{VStack(spacing:4){Image(systemName:currentPoint?.id==p.id ? "diamond.fill":"diamond");Text(String(format:"%.2fs",p.time-range.lowerBound)).monospacedDigit()}.font(.caption).padding(10).background(StudioStyle.blue.opacity(currentPoint?.id==p.id ? 0.3:0.1),in:RoundedRectangle(cornerRadius:12))}.contextMenu {Button("Delete point",role:.destructive){edit {$0.points.removeAll {$0.id==p.id}}}}.accessibilityLabel("Animation point "+String(format:"%.2f seconds",p.time-range.lowerBound))}}}
                            if let selectedPoint,let selected=track.points.first(where:{$0.id==selectedPoint}),abs(selected.time-time)>step*0.6 {
                                Button("Move selected point here"){let destination=(time/step).rounded()*step;edit {item in item.points.removeAll {$0.id != selectedPoint && abs($0.time-destination)<step*0.6};if let i=item.points.firstIndex(where:{$0.id==selectedPoint}) {item.points[i].time=destination}}}.font(.caption).disabled(position.playing)
                            }
                            HStack {
                                Button("Delete point",role:.destructive){if let point=currentPoint {edit {$0.points.removeAll {$0.id==point.id}};selectedPoint=nil}}.disabled(currentPoint==nil || position.playing)
                                Spacer()
                                Button("Reset this animation",role:.destructive){session.change {$0.videoAnimation?.tracks.removeAll {$0.target==target}};draft=target.neutral;selectedPoint=nil}
                            }.font(.caption)
                        }
                        Text("Points stay attached to the original clip time when you trim. Values before the first point and after the last hold steady. Smooth gently eases between points; Linear changes at a constant rate. Animation stays with this source and its versions/backups/queue, and is excluded from reusable grades and LUTs.").font(.caption).foregroundStyle(StudioStyle.secondary)
                        if animation.tracks.contains(where: {t in if case .mask(let id)=t.target {return !session.recipe.masks.contains {$0.id==id}};return false}) {Button("Remove animations for deleted masks"){session.change {$0.videoAnimation?.tracks.removeAll {t in if case .mask(let id)=t.target {return !session.recipe.masks.contains {$0.id==id}};return false}}}.font(.caption)}
                    }.padding(18)
                }.frame(maxHeight:wide ? .infinity:300).frame(width:wide ? min(340,geometry.size.width*0.42):nil).background(StudioStyle.panel).disabled(pool?.historyBusy == true)
            }}.background(StudioStyle.ink).navigationTitle("Video animation").navigationBarTitleDisplayMode(.inline).toolbar {
                ToolbarItemGroup(placement:.topBarLeading) {
                    Button(action:undoAction){Image(systemName:"arrow.uturn.backward")}.disabled(pool.map {$0.undoHistory.isEmpty || $0.historyBusy} ?? session.undoStack.isEmpty).accessibilityLabel("Undo animation edit").accessibilityIdentifier("animationUndo")
                    Button(action:redoAction){Image(systemName:"arrow.uturn.forward")}.disabled(pool.map {$0.redoHistory.isEmpty || $0.historyBusy} ?? session.redoStack.isEmpty).accessibilityLabel("Redo animation edit").accessibilityIdentifier("animationRedo")
                }
                ToolbarItem(placement:.topBarTrailing){Button("Done"){dismiss()}.accessibilityIdentifier("closeVideoAnimation")}
            }
        }.tint(StudioStyle.blue)
        .onAppear {position.seek(min(range.upperBound,max(range.lowerBound,initialTime)))}
        .onDisappear {session.end();onFinish(position.time)}
        .onChange(of:position.time){_,_ in if !position.playing {draft=currentPoint?.value ?? track.value(at:time)}}
        .onChange(of:target){_,_ in draft=track.value(at:time)}
    }
    private func title(_ target:AnimationTarget)->String {switch target {case .exposure:"Exposure shift";case .look:"Look fade";case .lut:"LUT fade";case .mask(let id):session.recipe.masks.firstIndex(where:{$0.id==id}).map {"Mask \($0+1) · \(session.recipe.masks[$0].title) fade"} ?? "Deleted mask fade"}}
    private func edit(_ change:(inout AnimationTrack)->Void) {
        session.change {r in var a=r.videoAnimation ?? VideoAnimation();a.tracks.removeAll {if case .mask(let id)=$0.target {return !r.masks.contains {$0.id==id}};return false};if let i=a.tracks.firstIndex(where:{$0.target==target}) {change(&a.tracks[i])} else {var t=AnimationTrack(target:target);change(&t);a.tracks.append(t)};r.videoAnimation=a.validated()}
    }
    private func setPoint() {session.begin();upsert(draft);session.end()}
    private func upsert(_ value:Double) {
        let t=min(range.upperBound,max(range.lowerBound,(time/step).rounded()*step))
        var a=animation;a.tracks.removeAll {if case .mask(let id)=$0.target {return !session.recipe.masks.contains {$0.id==id}};return false}
        var item=track
        if let i=item.points.firstIndex(where:{abs($0.time-t)<step*0.6}) {item.points[i].time=t;item.points[i].value=value}
        else if item.points.count<32 {item.points.append(AnimationPoint(time:t,value:value))}
        if let i=a.tracks.firstIndex(where:{$0.target==target}) {a.tracks[i]=item.validated()} else {a.tracks.append(item.validated())}
        session.recipe.videoAnimation=a.validated()
    }
}

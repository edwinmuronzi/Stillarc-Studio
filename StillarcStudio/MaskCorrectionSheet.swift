import SwiftUI

/// Reuses the existing video renderer and cached mattes; no additional inference.
struct MaskCorrectionSheet:View {
    @Bindable var session:EditSession
    let maskID:UUID
    var pool:EditingPool? = nil
    var undoAction:()->Void={}
    var redoAction:()->Void={}
    var initialTime=0.0
    var onFinish:(Double)->Void={_ in}
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var position=ClipPosition()
    @State private var showGuide=true
    @State private var moving=false
    @State private var dragStart:(x:Double,y:Double)?
    private var layer:LocalMask? {session.recipe.masks.first {$0.id==maskID}}
    private var motion:MaskMotion? {layer?.motion}
    private var range:ClosedRange<Double> {session.recipe.video.range(duration:session.project.video?.duration ?? 1)}
    private var step:Double {1/max(1,session.project.video?.frameRate ?? 30)}
    private var time:Double {min(range.upperBound,max(range.lowerBound,position.time))}
    private var correction:(x:Double,y:Double) {motion?.correction(at:time) ?? (0,0)}
    private var pose:(scale:Double,rotation:Double) {motion?.manualPose(at:time) ?? (1,0)}
    private var point:MaskMotionPoint? {motion?.corrections?.first {abs($0.time-time)<=step*0.6}}
    private var valid:Bool {motion?.matches(session.recipe,duration:session.project.video?.duration ?? 0) == true}
    var body:some View {
        NavigationStack {
            GeometryReader {geometry in
                let wide=geometry.size.width>geometry.size.height*1.3
                let layout=wide ? AnyLayout(HStackLayout(spacing:0)):AnyLayout(VStackLayout(spacing:0))
                layout {
                    preview.padding(12)
                    ScrollView {
                        VStack(alignment:.leading,spacing:14) {
                            Text("Fix a drifting mask").font(.headline)
                            Text("Pause or scrub to the drift. Turn on Move mask and drag the blue handle, or use the sliders. Open Size & rotation to make the mask bigger, smaller or turn it. Corrections blend between saved points without running tracking again.").font(.caption).foregroundStyle(StudioStyle.secondary)
                            HStack {Text(String(format:"%.2f s",time-range.lowerBound)).monospacedDigit();Spacer();Button("Start"){position.seek(range.lowerBound)};Button("End"){position.seek(max(range.lowerBound,range.upperBound-step))}}.font(.caption).buttonStyle(.bordered)
                            HStack(spacing:10) {
                                navigationButton("Previous correction",icon:"backward.end",target:previousPoint)
                                navigationButton("Previous frame",icon:"backward.frame",target:time>range.lowerBound+0.00001 ? max(range.lowerBound,time-step):nil)
                                Spacer(minLength:0)
                                navigationButton("Next frame",icon:"forward.frame",target:time<lastFrame-0.00001 ? min(lastFrame,time+step):nil)
                                navigationButton("Next correction",icon:"forward.end",target:nextPoint)
                            }.buttonStyle(.bordered)
                            VStack(alignment:.leading,spacing:6) {
                                Text("Correction transition").font(.caption)
                                Picker("Correction transition",selection:Binding(get:{motion?.correctionBlend ?? .linear},set:{value in session.change {r in if let i=r.masks.firstIndex(where:{$0.id==maskID}) {r.masks[i].motion?.correctionBlend=value == .linear ? nil:value}}})) {
                                    ForEach(MaskCorrectionBlend.allCases,id:\.self) {Text($0.title).tag($0)}
                                }.pickerStyle(.segmented).disabled(position.playing).accessibilityIdentifier("correctionTransition")
                                Text("Linear moves steadily. Smooth eases into each correction. Hold keeps a correction until the next point. The measured tracking path stays active in every mode.").font(.caption).foregroundStyle(StudioStyle.secondary)
                            }
                            Toggle("Show mask overlay",isOn:$showGuide)
                            Toggle("Move mask in preview",isOn:$moving).onChange(of:moving){_,value in if value {position.pause()}}
                            valueSlider("Horizontal correction",horizontal:true)
                            valueSlider("Vertical correction",horizontal:false)
                            DisclosureGroup("Size & rotation") {
                                VStack(spacing:14) {
                                    poseSlider("Mask size",scale:true)
                                    poseSlider("Mask rotation",scale:false)
                                    Text("Size and rotation pivot around the tracked target centre. For older tracks, the mask centre is used; track again to choose a new target centre. These are manual corrections, not automatic pose tracking.").font(.caption).foregroundStyle(StudioStyle.secondary)
                                }.padding(.top,10)
                            }.font(.subheadline)
                            HStack {
                                Button(point == nil ? "Set correction":"Update correction",systemImage:"diamond.fill"){commit(x:correction.x,y:correction.y)}.buttonStyle(.borderedProminent).accessibilityIdentifier("setTrackingCorrection").disabled(position.playing || !canInsert)
                                Spacer();Text("\(motion?.corrections?.count ?? 0)/32 points").font(.caption).foregroundStyle(StudioStyle.secondary)
                            }
                            if let points=motion?.corrections,!points.isEmpty {
                                ScrollView(.horizontal,showsIndicators:false){HStack(spacing:8){ForEach(Array(points.enumerated()),id:\.offset){_,p in
                                    Button {position.seek(p.time)} label:{VStack(spacing:4){Image(systemName:point?.time==p.time ? "diamond.fill":"diamond");Text(String(format:"%.2fs",p.time-range.lowerBound)).monospacedDigit()}.font(.caption).padding(10).background(StudioStyle.blue.opacity(0.14),in:RoundedRectangle(cornerRadius:12))}.accessibilityLabel("Correction at "+String(format:"%.2f seconds",p.time-range.lowerBound))
                                        .contextMenu {Button("Delete correction",role:.destructive){remove(at:p.time)}}
                                }}}
                                HStack {Button("Delete correction",role:.destructive){if let point {remove(at:point.time)}}.disabled(point==nil || position.playing);Spacer();Button("Clear corrections",role:.destructive){session.change {r in if let i=r.masks.firstIndex(where:{$0.id==maskID}) {r.masks[i].motion?.corrections=nil}}}}.font(.caption)
                            }
                            Text("A first correction after the start adds a zero point at the original tracking start. The selected transition applies to all manual corrections on this mask; the last correction holds. Up to 32 points, including that anchor. Corrections follow source time through trims and stay in versions, backups and exports. Clearing them restores the measured path. Position, size and rotation blend between the same points. Rotation follows the chosen numeric angles; add intermediate points to control the turn. The mask does not deform to follow a changing pose.").font(.caption).foregroundStyle(StudioStyle.secondary)
                            if !valid {Text("This track no longer matches the crop or kept clip. Close this screen and track again.").font(.caption).foregroundStyle(.orange)}
                        }.padding(18).disabled(!valid || pool?.historyBusy == true)
                    }.frame(maxHeight:wide ? .infinity:300).frame(width:wide ? min(340,geometry.size.width*0.42):nil).background(StudioStyle.panel)
                }
            }.background(StudioStyle.ink).navigationTitle("Correct tracking").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItemGroup(placement:.topBarLeading) {
                        Button(action:undoAction){Image(systemName:"arrow.uturn.backward")}.disabled(pool.map {$0.undoHistory.isEmpty || $0.historyBusy} ?? session.undoStack.isEmpty).accessibilityLabel("Undo tracking correction").accessibilityIdentifier("correctionUndo")
                        Button(action:redoAction){Image(systemName:"arrow.uturn.forward")}.disabled(pool.map {$0.redoHistory.isEmpty || $0.historyBusy} ?? session.redoStack.isEmpty).accessibilityLabel("Redo tracking correction").accessibilityIdentifier("correctionRedo")
                    }
                    ToolbarItem(placement:.topBarTrailing){Button("Done"){dismiss()}.accessibilityIdentifier("closeTrackingCorrection")}
                }
        }.tint(StudioStyle.blue)
            .onAppear {position.seek(min(range.upperBound,max(range.lowerBound,initialTime)))}
            .onDisappear {session.end();onFinish(position.time)}
            .onChange(of:position.playing){_,value in if value {moving=false;session.end();dragStart=nil}}
            .onChange(of:phase){_,value in if value != .active {session.end();dragStart=nil}}
    }
    private var lastFrame:Double {max(range.lowerBound,range.upperBound-step)}
    private var previousPoint:Double? {motion?.corrections?.last {$0.time<time-step*0.6 && $0.time>=range.lowerBound}?.time}
    private var nextPoint:Double? {motion?.corrections?.first {$0.time>time+step*0.6 && $0.time<=range.upperBound}?.time}
    private func navigationButton(_ title:String,icon:String,target:Double?)->some View {
        Button {if let target {session.end();position.pause();position.seek(target,exact:true)}} label:{Image(systemName:icon).frame(minWidth:24,minHeight:24)}
            .disabled(target == nil).accessibilityLabel(title)
    }
    private var canInsert:Bool {(motion?.corrections?.count ?? 0)<32 || point != nil}
    private var preview:some View {
        GeometryReader {geometry in
            if let descriptor=session.project.video,let url=session.sourceURL,let source=session.source {
                VideoPreview(url:url,descriptor:descriptor,poster:source,recipe:session.recipe,original:false,active:phase == .active && pool?.historyBusy != true,showTrimButton:false,maskPreview:showGuide ? layer:nil,hideTransport:moving,position:position)
                    .overlay {
                        if moving,!position.playing,valid,let layer,let motion {
                            let size=PhotoFraming.apply(source.image,recipe:session.recipe).extent.size
                            let scale=min(geometry.size.width/max(1,size.width),geometry.size.height/max(1,size.height))
                            let width=max(1,size.width*scale),height=max(1,size.height*scale)
                            let offset=motion.offset(at:time)
                            Image(systemName:"arrow.up.and.down.and.arrow.left.and.right").font(.title3.bold()).foregroundStyle(.white)
                                .frame(width:44,height:44).background(StudioStyle.blue,in:Circle()).overlay(Circle().stroke(.white.opacity(0.7),lineWidth:1))
                                .position(x:(geometry.size.width-width)/2+width*min(1,max(0,(motion.pivotX ?? layer.centerX)+offset.x)),y:(geometry.size.height-height)/2+height*min(1,max(0,(motion.pivotY ?? layer.centerY)+offset.y)))
                                .gesture(DragGesture(minimumDistance:0).onChanged {v in
                                    guard canInsert else {return}
                                    if dragStart==nil {session.begin();dragStart=correction}
                                    if let start=dragStart {setLive(x:start.x+v.translation.width/width,y:start.y+v.translation.height/height)}
                                }.onEnded {_ in session.end();dragStart=nil})
                                .accessibilityLabel("Move tracked mask").accessibilityIdentifier("trackingCorrectionHandle")
                        }
                    }.clipShape(RoundedRectangle(cornerRadius:18)).accessibilityElement(children:.contain).accessibilityIdentifier("correctionPreview")
            }
        }.frame(maxWidth:.infinity,maxHeight:.infinity)
    }
    private func valueSlider(_ title:String,horizontal:Bool)->some View {
        VStack(spacing:5){HStack{Text(title);Spacer();Text(String(format:"%+.1f%%",(horizontal ? correction.x:correction.y)*100)).monospacedDigit()}.font(.caption)
            Slider(value:Binding(get:{horizontal ? correction.x:correction.y},set:{v in setLive(x:horizontal ? v:correction.x,y:horizontal ? correction.y:v)}),in:-1...1,onEditingChanged:{$0 ? session.begin():session.end()}).accessibilityLabel(title).disabled(position.playing || !canInsert).sliderReset {commit(x:horizontal ? 0:correction.x,y:horizontal ? correction.y:0)}
        }
    }
    private func poseSlider(_ name:String,scale:Bool)->some View {
        VStack(spacing:5) {
            HStack {Text(name);Spacer();Text(scale ? String(format:"%.0f%%",pose.scale*100):String(format:"%+.1f°",pose.rotation)).monospacedDigit()}.font(.caption)
            Slider(value:Binding(get:{scale ? pose.scale:pose.rotation},set:{value in session.begin();var recipe=session.recipe;set(&recipe,x:correction.x,y:correction.y,scale:scale ? value:nil,rotation:scale ? nil:value);session.recipe=recipe}),in:scale ? 0.25...4:-180...180,onEditingChanged:{$0 ? session.begin():session.end()})
                .accessibilityLabel(name).disabled(position.playing || !canInsert)
                .sliderReset {var recipe=session.recipe;set(&recipe,x:correction.x,y:correction.y,scale:scale ? 1:nil,rotation:scale ? nil:0);session.change {$0=recipe}}
        }
    }
    private func set(_ recipe:inout Recipe,x:Double,y:Double,scale:Double?=nil,rotation:Double?=nil) {
        guard let i=recipe.masks.firstIndex(where:{$0.id==maskID}),recipe.masks[i].motion?.matches(recipe,duration:session.project.video?.duration ?? 0)==true else {return}
        let bounds=recipe.video.range(duration:session.project.video?.duration ?? 1)
        let t=min(bounds.upperBound,max(bounds.lowerBound,(position.time/step).rounded()*step))
        if let video=session.project.video {recipe.masks[i].motion?.sourceWidth=Double(video.width);recipe.masks[i].motion?.sourceHeight=Double(video.height)}
        recipe.masks[i].motion?.setCorrection(time:t,x:x,y:y,tolerance:step*0.6,scale:scale,rotation:rotation)
    }
    private func commit(x:Double,y:Double) {var recipe=session.recipe;set(&recipe,x:x,y:y);session.change {$0=recipe}}
    private func setLive(x:Double,y:Double) {session.begin();var recipe=session.recipe;set(&recipe,x:x,y:y);session.recipe=recipe}
    private func remove(at time:Double) {session.change {r in if let i=r.masks.firstIndex(where:{$0.id==maskID}) {r.masks[i].motion?.corrections?.removeAll {abs($0.time-time)<0.00001}}}}
}

import SwiftUI

enum VideoRepairTool:String,CaseIterable {case view="View",add="Add",subtract="Subtract"}
struct VideoMatteReviewSheet:View {
    @Bindable var session:EditSession
    let maskID:UUID
    var initialTime=0.0
    var onFinish:(Double)->Void={_ in}
    var undoAction:()->Void={}
    var redoAction:()->Void={}
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var position=ClipPosition()
    @State private var tool=VideoRepairTool.view
    @State private var radius=0.035
    @State private var feather=0.5
    @State private var zoom=1.0
    @State private var offset=CGSize.zero
    @State private var strokeID:UUID?
    @State private var panStart:CGSize?
    @State private var opposingStrokeID:UUID?
    @State private var pointID:UUID?
    @State private var patch:PeopleMatteTarget?
    private var layer:LocalMask? {session.recipe.masks.first {$0.id==maskID}}
    private var matte:TemporalMatte? {layer?.automatic?.temporal}
    private var repairs:VideoMaskRepairs {layer?.videoRepairs ?? VideoMaskRepairs()}
    private var time:Double {matte?.frame(at:position.time).time ?? position.time}
    private var range:ClosedRange<Double> {session.recipe.video.range(duration:session.project.video?.duration ?? 1)}
    private var markers:[Double] {Array(Set((matte?.reviewTimes ?? []).filter {hint in !repairs.dismissedHints.contains {abs($0-hint)<0.05}}+repairs.markers)).filter {$0>=range.lowerBound && $0<range.upperBound}.sorted()}
    private var currentPoint:VideoMaskRepairPoint? {repairs.points.first {abs($0.time-time)<0.0001}}
    private var previewRecipe:Recipe {var r=session.recipe;r.reset(.crop);return r}
    var body:some View {
        NavigationStack {GeometryReader {g in
            let wide=g.size.width>g.size.height*1.3
            let layout=wide ? AnyLayout(HStackLayout(spacing:0)):AnyLayout(VStackLayout(spacing:0))
            layout {
                preview.padding(12)
                ScrollView {VStack(alignment:.leading,spacing:12) {
                    Text("Repair the outline at a moment").font(.headline)
                    DisclosureGroup("How repair moments work") {
                        Text("Pause and choose Add or Subtract, then brush on the full-frame preview. Smooth/Linear/Hold blends between saved moments. Before the first repair it fades from the analysis start; after the last it holds. Use empty moments to bound a fix. Repairs stay in source time through crops and shorter trims, but do not automatically follow the object between moments.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    }.font(.caption)
                    Picker("Repair tool",selection:$tool){ForEach(VideoRepairTool.allCases,id:\.self){Text($0.rawValue).tag($0)}}.pickerStyle(.segmented).accessibilityIdentifier("videoRepairTool").onChange(of:tool){_,_ in session.end();strokeID=nil;opposingStrokeID=nil;pointID=nil;position.pause()}
                    HStack {Button(position.playing ? "Pause":"Play"){tool = .view;position.togglePlay()}.buttonStyle(.bordered);Slider(value:Binding(get:{position.time},set:{position.seek($0,exact:true)}),in:range,onEditingChanged:{_ in position.pause()}).accessibilityLabel("Matte review position")}
                    HStack {Text(String(format:"%.2f s",time-range.lowerBound)).monospacedDigit();Spacer();Button("Previous marker"){if let t=markers.last(where:{$0<time-0.01}) {seek(t)}}.disabled(!markers.contains {$0<time-0.01});Button("Next marker"){if let t=markers.first(where:{$0>time+0.01}) {seek(t)}}.disabled(!markers.contains {$0>time+0.01})}.font(.caption)
                    HStack {Button("Mark for review"){change {if $0.markers.count<64,!$0.markers.contains(where:{abs($0-time)<0.05}) {$0.markers.append(time)};$0.dismissedHints.removeAll {abs($0-time)<0.1}}};Button("Clear marker"){change {r in r.markers.removeAll {abs($0-time)<0.1};for hint in matte?.reviewTimes ?? [] where abs(hint-time)<0.1 {if r.dismissedHints.count<128,!r.dismissedHints.contains(hint) {r.dismissedHints.append(hint)}}}}}.font(.caption).buttonStyle(.bordered)
                    if markers.isEmpty {Text("No review markers on this matte. Review the full clip; confidence hints cannot identify every bad edge.").font(.caption).foregroundStyle(StudioStyle.secondary)}
                    else {ScrollView(.horizontal){LazyHStack {ForEach(markers,id:\.self){t in Button(String(format:"%.2fs",t-range.lowerBound)){seek(t)}.buttonStyle(.bordered)}}}}
                    Picker("Repair transition",selection:Binding(get:{repairs.transition},set:{v in change {$0.transition=v}})){ForEach(MaskCorrectionBlend.allCases,id:\.self){Text($0.title).tag($0)}}.pickerStyle(.segmented).accessibilityIdentifier("videoRepairTransition")
                    HStack {Button("Empty repair here"){change {if let i=$0.point(at:time,tolerance:0.0001) {$0.points[i].add=BrushDrawing();$0.points[i].subtract=BrushDrawing()}}};Button("Delete repair",role:.destructive){change {$0.points.removeAll {abs($0.time-time)<0.0001}}}.disabled(currentPoint==nil)}.font(.caption).buttonStyle(.bordered)
                    Text("\(repairs.points.count)/16 repair moments. New strokes clear the opposing repair along the same path. Undo removes one complete stroke; deleting a moment changes how neighbouring moments blend.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    HStack {Button("Fit"){zoom=1;offset = .zero};Slider(value:$zoom,in:1...6).accessibilityLabel("Repair preview zoom").sliderReset {zoom=1;offset = .zero};Text("\(zoom,format:.number.precision(.fractionLength(1)))×").monospacedDigit()}.font(.caption)
                    if tool != .view {
                        Text("Brush radius").font(.caption);Slider(value:$radius,in:0.005...0.15).accessibilityLabel("Repair brush radius").sliderReset {radius=0.035}
                        Text("Soft edge").font(.caption);Slider(value:$feather,in:0.02...1).accessibilityLabel("Repair soft edge").sliderReset {feather=0.5}
                        Button("Done brushing"){tool = .view;session.end();position.pause()}.buttonStyle(.borderedProminent)
                    }
                    Button("Reanalyse one-second section here",systemImage:"arrow.clockwise") {
                        guard let matte else {return};seek(time)
                        let lower=max(matte.start,time-0.5),upper=min(matte.end,time+0.5)
                        patch=PeopleMatteTarget(maskID:maskID,cutout:layer?.cutout == true,object:layer?.automatic?.selectionMode == .picked,interval:lower...upper)
                    }.buttonStyle(.bordered).font(.caption).disabled(matte==nil)
                    Text("Object hints mark weaker accepted tracking, not guaranteed errors. Reanalysis asks you to tap the object again at the section start; only that section is replaced if preparation succeeds. It does not invent a hidden object through an obstruction.").font(.caption).foregroundStyle(StudioStyle.secondary)
                }.padding(18)}.accessibilityIdentifier("videoRepairControls").frame(width:wide ? min(350,g.size.width*0.44):nil).frame(maxHeight:wide ? .infinity:310).background(StudioStyle.panel)
            }
        }.background(StudioStyle.ink).navigationTitle("Repair matte").navigationBarTitleDisplayMode(.inline).toolbar {
            ToolbarItemGroup(placement:.topBarLeading){Button(action:undoAction){Image(systemName:"arrow.uturn.backward")}.accessibilityLabel("Undo matte repair").accessibilityIdentifier("matteRepairUndo");Button(action:redoAction){Image(systemName:"arrow.uturn.forward")}.accessibilityLabel("Redo matte repair").accessibilityIdentifier("matteRepairRedo")}
            ToolbarItem(placement:.topBarTrailing){Button("Done"){dismiss()}.accessibilityIdentifier("closeMatteReview")}
        }}.tint(StudioStyle.blue)
        .onAppear {seek(min(range.upperBound,max(range.lowerBound,initialTime)))}
        .onDisappear {session.end();onFinish(position.time)}
        .onChange(of:phase){_,v in if v != .active {session.end();strokeID=nil;opposingStrokeID=nil;pointID=nil;position.pause()}}
        .sheet(item:$patch){PeopleVideoMatteSheet(session:session,target:$0)}
    }
    private func seek(_ t:Double){session.end();tool = .view;position.pause();position.seek(t,exact:true)}
    private func change(_ body:(inout VideoMaskRepairs)->Void) {
        guard let i=session.recipe.masks.firstIndex(where:{$0.id==maskID}) else {return}
        var r=repairs;body(&r);guard r.isValid else {return};session.change {$0.masks[i].videoRepairs=r}
    }
    private var preview:some View {
        GeometryReader {g in
            if let source=session.source,let video=session.project.video,let url=session.sourceURL {
                let viewport=MaskViewport(scale:zoom,offset:offset)
                let fit=viewport.rect(size:CGSize(width:video.width,height:video.height),container:g.size)
                VideoPreview(url:url,descriptor:video,poster:source,recipe:previewRecipe,original:false,active:phase == .active && patch==nil,showTrimButton:false,maskPreview:layer,hideTransport:tool != .view,viewport:viewport,position:position)
                    .overlay {
                        if tool != .view {
                            Color.clear.contentShape(Path(fit)).gesture(DragGesture(minimumDistance:0).onChanged {v in paint(v.location,fit:fit)}.onEnded {_ in session.end();strokeID=nil;opposingStrokeID=nil;pointID=nil}).accessibilityElement(children:.ignore).accessibilityLabel("Paint video matte repair").accessibilityValue("\(repairs.points.reduce(0){$0+$1.add.strokes.count+$1.subtract.strokes.count}) strokes").accessibilityIdentifier("videoRepairCanvas")
                        } else if zoom>1 {
                            Color.clear.contentShape(Rectangle()).gesture(DragGesture(minimumDistance:12).onChanged {v in if panStart==nil {panStart=offset};if let start=panStart {offset=MaskViewport.bounded(CGSize(width:start.width+v.translation.width,height:start.height+v.translation.height),scale:zoom,container:g.size)}}.onEnded {_ in panStart=nil})
                        }
                    }.clipShape(RoundedRectangle(cornerRadius:18)).accessibilityElement(children:.contain).accessibilityIdentifier("videoRepairPreview").onChange(of:zoom){_,v in offset=MaskViewport.bounded(offset,scale:v,container:g.size)}
            }
        }.frame(maxWidth:.infinity,maxHeight:.infinity)
    }
    private func paint(_ p:CGPoint,fit:CGRect) {
        guard fit.width>0,fit.height>0,let i=session.recipe.masks.firstIndex(where:{$0.id==maskID}) else {return}
        var r=repairs
        let index:Int?
        if let pointID {index=r.points.firstIndex {$0.id==pointID}} else {index=r.point(at:time,tolerance:0.0001)}
        guard let index else {return}
        let point=BrushPoint(x:(p.x-fit.minX)/fit.width,y:(p.y-fit.minY)/fit.height).validated()
        let writesAdd=(tool == .add) != (layer?.inverted == true)
        var drawing=writesAdd ? r.points[index].add:r.points[index].subtract
        var opposing=writesAdd ? r.points[index].subtract:r.points[index].add
        if strokeID==nil {
            guard drawing.strokes.count<16,(opposing.strokes.isEmpty || opposing.strokes.count<16) else {return}
            session.begin();strokeID=drawing.begin(point:point,radius:radius,feather:feather,erase:false);pointID=r.points[index].id
            if !opposing.strokes.isEmpty {opposingStrokeID=opposing.begin(point:point,radius:radius,feather:feather,erase:true)}
        } else {
            if let strokeID {drawing.append(point,stroke:strokeID)}
            if let opposingStrokeID {opposing.append(point,stroke:opposingStrokeID)}
        }
        if writesAdd {r.points[index].add=drawing;r.points[index].subtract=opposing} else {r.points[index].subtract=drawing;r.points[index].add=opposing}
        guard r.isValid else {return};session.recipe.masks[i].videoRepairs=r
    }
}

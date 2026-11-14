import SwiftUI

struct RetouchSheet:View {
    @Bindable var session:EditSession
    var undoAction:()->Void={}
    var redoAction:()->Void={}
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var kind=RetouchKind.heal
    @State private var source=CGPoint(x:0.35,y:0.5)
    @State private var pickSource=false
    @State private var autoSource=true
    @State private var painting=true
    @State private var radius=0.035
    @State private var zoom=1.0
    @State private var offset=CGSize.zero
    @State private var panStart:CGSize?
    @State private var last:CGPoint?
    @State private var strokeSource:CGPoint?
    @State private var strokeTarget:CGPoint?
    @State private var sampler:CleanupSource?
    @State private var message:String?
    private var working:Recipe {var r=session.recipe;r.reset(.crop);r.masks=[];r.background=nil;return r}
    var body:some View {
        NavigationStack {GeometryReader {g in
            let wide=g.size.width>g.size.height*1.3
            let layout=wide ? AnyLayout(HStackLayout(spacing:0)):AnyLayout(VStackLayout(spacing:0))
            layout {
                preview.padding(12)
                ScrollView {VStack(alignment:.leading,spacing:12) {
                    Picker("Cleanup tool",selection:$kind){ForEach(RetouchKind.allCases){Text($0.rawValue).tag($0)}}.pickerStyle(.segmented)
                    HStack {Button(painting ? "Move view":"Brush"){session.end();painting.toggle()};Button("Choose source"){painting=true;pickSource=true;autoSource=false};Button("Fit"){zoom=1;offset = .zero}}.buttonStyle(.bordered).font(.caption)
                    if autoSource && sampler==nil {ProgressView("Preparing source suggestions…").font(.caption)}
                    Toggle("Suggest a clean source",isOn:$autoSource).font(.caption).onChange(of:autoSource){_,v in if v {pickSource=false}}
                    Text(pickSource ? "Tap a clean source area.":painting ? "Tap or brush over a small distraction. One stroke is one Undo step.":"Pan the zoomed preview; switch back to Brush to repair.").font(.caption)
                    HStack {Text("Radius");Slider(value:$radius,in:0.005...0.15).accessibilityLabel("Spot radius").sliderReset {radius=0.035}}.font(.caption)
                    HStack {Text("Zoom");Slider(value:$zoom,in:1...6).accessibilityLabel("Cleanup zoom").sliderReset {zoom=1;offset = .zero}}.font(.caption)
                    HStack {Text("\(session.recipe.retouch?.count ?? 0) / 32 dabs");Spacer();Button("Remove last dab"){session.change {$0.retouch?.removeLast()}}.disabled(session.recipe.retouch?.isEmpty != false);Button("Clear",role:.destructive){session.change {$0.retouch=nil}}.disabled(session.recipe.retouch?.isEmpty != false)}.font(.caption)
                    if let message {Text(message).font(.caption).foregroundStyle(.orange)}
                    DisclosureGroup("How cleanup works") {Text("Heal borrows clean texture and matches the surrounding colour, excluding the centre of the distraction from the match. Clone copies texture directly. The optional source suggestion searches a small local sampling grid; inspect the result and choose a source manually for patterned areas. This is patch-based cleanup, not generative object reconstruction. Brushing places spaced dabs up to the shared 32-dab limit; zoom does not change output resolution. The original source supplies each patch to avoid repeatedly copying repaired pixels. Full-frame repair coordinates survive your crop.").font(.caption).foregroundStyle(StudioStyle.secondary)}.font(.caption)
                }.padding(16)}.frame(width:wide ? min(340,g.size.width*0.42):nil).frame(maxHeight:wide ? .infinity:270).background(StudioStyle.panel)
            }
        }.background(StudioStyle.ink).navigationTitle("Photo cleanup").navigationBarTitleDisplayMode(.inline).toolbar {
            ToolbarItemGroup(placement:.topBarLeading){Button(action:undoAction){Image(systemName:"arrow.uturn.backward")}.accessibilityIdentifier("cleanupUndo");Button(action:redoAction){Image(systemName:"arrow.uturn.forward")}.accessibilityIdentifier("cleanupRedo")}
            ToolbarItem(placement:.topBarTrailing){Button("Done"){dismiss()}.accessibilityIdentifier("closeCleanup")}
        }}.tint(StudioStyle.blue)
        .task {if let photo=session.source {let image=PhotoRendering.rawPreview(photo,recipe:session.recipe);sampler=await Task.detached(priority:.utility){CleanupSource(image)}.value}}
        .onDisappear {session.end()}.onChange(of:phase){_,v in if v != .active {session.end();last=nil;strokeSource=nil;strokeTarget=nil}}
    }
    private var preview:some View {
        GeometryReader {g in
            if let photo=session.source {
                let viewport=MaskViewport(scale:zoom,offset:offset),fit=viewport.rect(size:photo.image.extent.size,container:g.size)
                LivePreview(source:PhotoRendering.rawPreview(photo,recipe:session.recipe),recipe:working,signalSource:photo.signalImage,original:false,active:phase == .active,hdr:session.recipe.photoHDR == true).modifier(MaskViewportModifier(viewport:viewport))
                    .overlay {
                        if painting {
                            Color.clear.contentShape(Path(fit)).gesture(DragGesture(minimumDistance:0).onChanged {v in
                                if autoSource && sampler==nil && !pickSource {return}
                                let p=CGPoint(x:min(1,max(0,(v.location.x-fit.minX)/fit.width)),y:min(1,max(0,(v.location.y-fit.minY)/fit.height)))
                                if pickSource {source=p;return}
                                if strokeTarget==nil {session.begin();strokeTarget=p;strokeSource=autoSource ? sampler?.suggestion(at:p,radius:radius) ?? source:source;message=nil}
                                guard (session.recipe.retouch?.count ?? 0)<32 else {message="32-dab limit reached. Undo or remove dabs before adding more.";return}
                                if let last,hypot((p.x-last.x)*fit.width,(p.y-last.y)*fit.height)<radius*min(fit.width,fit.height)*0.6 {return}
                                if let origin=strokeTarget,let clean=strokeSource {
                                    let sx=min(1,max(0,clean.x+p.x-origin.x)),sy=min(1,max(0,clean.y+p.y-origin.y))
                                    var spots=session.recipe.retouch ?? [];spots.append(.init(x:p.x,y:p.y,sourceX:sx,sourceY:sy,radius:radius,kind:kind));session.recipe.retouch=spots;source=CGPoint(x:sx,y:sy);last=p
                                }
                            }.onEnded {_ in if pickSource {pickSource=false};session.end();last=nil;strokeSource=nil;strokeTarget=nil}).accessibilityElement().accessibilityLabel("Brush photo cleanup").accessibilityValue("\(session.recipe.retouch?.count ?? 0) dabs").accessibilityIdentifier("cleanupCanvas")
                            Circle().stroke(.blue,lineWidth:2).frame(width:18,height:18).position(x:fit.minX+fit.width*source.x,y:fit.minY+fit.height*source.y).allowsHitTesting(false)
                        } else {
                            Color.clear.contentShape(Rectangle()).gesture(DragGesture(minimumDistance:8).onChanged {v in if panStart==nil {panStart=offset};if let start=panStart {offset=MaskViewport.bounded(CGSize(width:start.width+v.translation.width,height:start.height+v.translation.height),scale:zoom,container:g.size)}}.onEnded {_ in panStart=nil})
                        }
                    }.clipShape(RoundedRectangle(cornerRadius:16)).onChange(of:zoom){_,v in offset=MaskViewport.bounded(offset,scale:v,container:g.size)}
            }
        }.frame(maxWidth:.infinity,maxHeight:.infinity)
    }
}

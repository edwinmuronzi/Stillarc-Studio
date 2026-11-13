import SwiftUI
import UniformTypeIdentifiers

/// Inline controls keep the main preview visible and reuse its single render worker.
struct LUTStackControls:View {
    @Bindable var session:EditSession
    @State private var importing=false
    @State private var failure:String?
    private var layers:[LUTLayer] {session.recipe.lutLayers ?? []}
    var body:some View {
        DisclosureGroup("LUT stack · \((session.recipe.lut == nil ? 0:1)+layers.count)/3") {
            VStack(alignment:.leading,spacing:14) {
                Text("LUTs run from top to bottom after your look. Use creative LUTs made for normal display color; choose Log conversion separately in Input. Each layer blends independently.").font(.caption).foregroundStyle(StudioStyle.secondary)
                if let primary=session.recipe.lut {Toggle("1 · \(primary.name)",isOn:Binding(get:{session.recipe.lutEnabled != false},set:{v in session.change {$0.lutEnabled=v ? nil:false}})).font(.caption)}
                ForEach(layers) {layer in
                    VStack(alignment:.leading,spacing:8) {
                        Toggle(layer.asset.name,isOn:Binding(get:{session.recipe.lutLayers?.first {$0.id==layer.id}?.enabled ?? false},set:{v in session.change {r in if let i=r.lutLayers?.firstIndex(where:{$0.id==layer.id}) {r.lutLayers?[i].enabled=v}}})).font(.caption)
                        HStack {
                            Text("Strength \(Int(layer.amount*100))%").font(.caption).monospacedDigit()
                            Spacer()
                            Button("Move up",systemImage:"arrow.up") {session.change {r in guard let i=r.lutLayers?.firstIndex(where:{$0.id==layer.id}) else{return};if i>0 {r.lutLayers?.swapAt(i,i-1)} else if let first=r.lut {let amount=r.lutAmount;let enabled=r.lutEnabled != false;r.lut=layer.asset;r.lutAmount=layer.amount;r.lutEnabled=layer.enabled ? nil:false;r.lutLayers?[i].asset=first;r.lutLayers?[i].amount=amount;r.lutLayers?[i].enabled=enabled}}}.labelStyle(.iconOnly).accessibilityLabel("Move \(layer.asset.name) up")
                            Button("Remove",systemImage:"trash",role:.destructive){session.change {$0.lutLayers?.removeAll {$0.id==layer.id}}}.labelStyle(.iconOnly).accessibilityLabel("Remove \(layer.asset.name)")
                        }
                        Slider(value:Binding(get:{session.recipe.lutLayers?.first {$0.id==layer.id}?.amount ?? 1},set:{v in session.begin();if let i=session.recipe.lutLayers?.firstIndex(where:{$0.id==layer.id}) {session.recipe.lutLayers?[i].amount=v}}),in:0...1,onEditingChanged:{$0 ? session.begin():session.end()}).accessibilityLabel("\(layer.asset.name) strength").sliderReset {session.change {r in if let i=r.lutLayers?.firstIndex(where:{$0.id==layer.id}) {r.lutLayers?[i].amount=1}}}
                    }.padding(12).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:12))
                }
                Button("Add LUT layer",systemImage:"plus"){importing=true}.disabled(layers.count>=2).accessibilityIdentifier("addLUTLayer")
                if session.recipe.lut != nil || !layers.isEmpty {Button("Turn off all LUTs",role:.destructive){session.change {$0.lut=nil;$0.lutEnabled=nil;$0.lutAmount=1;$0.lutLayers=nil}}}
                if let failure {Text(failure).font(.caption).foregroundStyle(.orange)}
            }.padding(.top,12)
        }.font(.subheadline)
        .fileImporter(isPresented:$importing,allowedContentTypes:[UTType(filenameExtension:"cube") ?? .data]) {result in
            Task {do {let url=try result.get();let asset=try await Task.detached(priority:.userInitiated){try LUTAsset.read(url)}.value;session.change {if $0.lut==nil && ($0.lutLayers ?? []).isEmpty {$0.lut=asset;$0.lutEnabled=nil;$0.lutAmount=1} else if ($0.lutLayers ?? []).count<2 {$0.lutLayers=($0.lutLayers ?? [])+[LUTLayer(asset:asset)]}};failure=nil} catch {failure=error.localizedDescription}}
        }.onDisappear {session.end()}
    }
}

struct FlexibleCurveControls:View {
    @Bindable var session:EditSession
    var channel:CurveChannel
    @State private var selected=2
    @State private var editing=false
    @State private var dragging=false
    private var curve:ToneCurve {session.recipe.rgbCurves[keyPath:channel.key]}
    private var points:[CurveNode] {curve.points}
    private var index:Int {min(max(0,selected),points.count-1)}
    var body:some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Button(editing ? "Done editing points":"Edit curve points",systemImage:editing ? "checkmark":"lock.open"){editing.toggle()}.buttonStyle(.bordered).accessibilityIdentifier("editFlexibleCurve")
                Spacer()
                Button("Add point",systemImage:"plus"){session.change {r in var c=r.rgbCurves[keyPath:channel.key];var p=c.points;let i=(0..<p.count-1).max {p[$0+1].x-p[$0].x < p[$1+1].x-p[$1].x} ?? 0;let x=(p[i].x+p[i+1].x)/2;let y=CurveSpline(c).value(at:x);p.insert(CurveNode(x:x,y:y),at:i+1);c.nodes=p;r.rgbCurves[keyPath:channel.key]=c;selected=i+1}}.disabled(points.count>=12).accessibilityIdentifier("addCurvePoint")
            }.font(.caption)
            HStack(spacing:8) {graph.frame(height:160);Image(systemName:"arrow.up.arrow.down").font(.caption).foregroundStyle(StudioStyle.secondary).frame(width:24,height:160).contentShape(Rectangle())}
            Text(editing ? "Drag a point in any direction. Use the right edge to scroll." : "Swipe the graph to scroll. Enable editing to move points. Add up to 12 points per channel.").font(.caption).foregroundStyle(StudioStyle.secondary)
            HStack {
                Menu("Point \(index+1) of \(points.count)") {ForEach(points.indices,id:\.self) {i in Button("Point \(i+1) · \(Int(points[i].x*100))% input"){selected=i}}}
                Spacer()
                Button("Delete point",role:.destructive){session.change {r in var c=r.rgbCurves[keyPath:channel.key];var p=c.points;p.remove(at:index);c.nodes=p;r.rgbCurves[keyPath:channel.key]=c};selected=max(0,index-1)}.disabled(index==0 || index==points.count-1)
            }.font(.caption)
            if index>0 && index<points.count-1 {control("Curve input",input:true)}
            control("Curve output",input:false)
            Button("Reset \(channel.rawValue.lowercased()) curve"){session.change {$0.rgbCurves[keyPath:channel.key]=ToneCurve()};selected=2}.font(.caption)
        }.onChange(of:channel){_,_ in session.end();dragging=false;selected=2}.onDisappear {session.end()}
    }
    private func set(_ x:Double?=nil,_ y:Double?=nil) {
        var c=curve;var p=c.points;let i=index
        if let x,i>0,i<p.count-1 {p[i].x=min(p[i+1].x-0.005,max(p[i-1].x+0.005,x))}
        if let y {p[i].y=min(1,max(0,y))}
        c.nodes=p;session.recipe.rgbCurves[keyPath:channel.key]=c
    }
    private func control(_ name:String,input:Bool)->some View {
        let range:ClosedRange<Double> = input ? (points[index-1].x+0.005)...(points[index+1].x-0.005):0...1
        return VStack(spacing:5) {
            HStack {Text(name);Spacer();Text(String(format:"%.1f%%",(input ? points[index].x:points[index].y)*100)).monospacedDigit()}.font(.caption)
            Slider(value:Binding(get:{input ? points[index].x:points[index].y},set:{v in session.begin();if input {set(v)} else {set(nil,v)}}),in:range,onEditingChanged:{$0 ? session.begin():session.end()}).accessibilityLabel(name).sliderReset {session.begin();if input {set((range.lowerBound+range.upperBound)/2)} else {set(nil,points[index].x)};session.end()}
        }
    }
    private var graph:some View {
        GeometryReader {g in
            let w=max(1,g.size.width-24),h=max(1,g.size.height-24)
            Canvas {ctx,size in
                var grid=Path();for i in 0...4 {let t=Double(i)/4;grid.move(to:CGPoint(x:12+t*w,y:12));grid.addLine(to:CGPoint(x:12+t*w,y:12+h));grid.move(to:CGPoint(x:12,y:12+t*h));grid.addLine(to:CGPoint(x:12+w,y:12+t*h))};ctx.stroke(grid,with:.color(.white.opacity(0.1)),lineWidth:1)
                let spline=CurveSpline(curve);var line=Path();for i in 0...160 {let x=Double(i)/160;let p=CGPoint(x:12+x*w,y:12+(1-spline.value(at:x))*h);if i==0 {line.move(to:p)} else {line.addLine(to:p)}};ctx.stroke(line,with:.color(channel.color),lineWidth:2)
                for i in points.indices {let p=points[i];ctx.fill(Path(ellipseIn:CGRect(x:12+p.x*w-6,y:12+(1-p.y)*h-6,width:12,height:12)),with:.color(i==index ? .white:channel.color))}
            }.background(.white.opacity(0.03),in:RoundedRectangle(cornerRadius:14)).contentShape(Rectangle())
            .highPriorityGesture(DragGesture(minimumDistance:0).onChanged {v in
                if !dragging {selected=points.indices.min {a,b in hypot(12+points[a].x*w-v.startLocation.x,12+(1-points[a].y)*h-v.startLocation.y)<hypot(12+points[b].x*w-v.startLocation.x,12+(1-points[b].y)*h-v.startLocation.y)} ?? 0;dragging=true;session.begin()}
                set((v.location.x-12)/w,1-(v.location.y-12)/h)
            }.onEnded {_ in dragging=false;session.end()},including:editing ? .all:.none)
            .accessibilityIdentifier("flexibleCurveGraph")
        }
    }
}

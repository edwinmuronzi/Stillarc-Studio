import SwiftUI

struct RetouchSheet:View {
    @Bindable var session:EditSession
    @Environment(\.dismiss) private var dismiss
    @State private var kind=RetouchKind.heal
    @State private var source=CGPoint(x:0.35,y:0.5)
    @State private var pickSource=true
    @State private var radius=0.035
    private var working:Recipe {var r=session.recipe;r.reset(.crop);r.masks=[];r.background=nil;return r}
    var body:some View {
        NavigationStack {VStack(spacing:12) {
            if let photo=session.source {
                GeometryReader {g in
                    let fit=CropEditingGeometry.fit(size:photo.image.extent.size,container:g.size)
                    ZStack(alignment:.topLeading) {
                        LivePreview(source:PhotoRendering.rawPreview(photo,recipe:session.recipe),recipe:working,original:false)
                        Circle().stroke(.blue,lineWidth:2).frame(width:18,height:18).position(x:fit.minX+fit.width*source.x,y:fit.minY+fit.height*source.y).allowsHitTesting(false)
                        Color.clear.contentShape(Rectangle()).gesture(SpatialTapGesture().onEnded {v in
                            guard fit.contains(v.location) else {return}
                            let point=CGPoint(x:(v.location.x-fit.minX)/fit.width,y:(v.location.y-fit.minY)/fit.height)
                            if pickSource {source=point;pickSource=false}
                            else if (session.recipe.retouch?.count ?? 0)<32 {session.change {var spots=$0.retouch ?? [];spots.append(RetouchSpot(x:point.x,y:point.y,sourceX:source.x,sourceY:source.y,radius:radius,kind:kind));$0.retouch=spots}}
                        })
                    }
                }
            }
            VStack(alignment:.leading,spacing:12) {
                Picker("Retouch mode",selection:$kind) {ForEach(RetouchKind.allCases){Text($0.rawValue).tag($0)}}.pickerStyle(.segmented)
                Text(pickSource ? "Tap a clean source area.":"Tap a spot to repair it. Choose another source whenever needed.").font(.subheadline)
                Text("Works on the full frame; your crop and optics stay saved. Heal matches local color; Clone copies the source patch. Small spots work best.").font(.caption).foregroundStyle(StudioStyle.secondary)
                Button("Choose source"){pickSource=true}.buttonStyle(.bordered)
                HStack {Text("Spot radius");Slider(value:$radius,in:0.005...0.15).accessibilityLabel("Spot radius").sliderReset {radius=0.035}}
                HStack {Text("\(session.recipe.retouch?.count ?? 0) / 32 spots").font(.caption);Spacer();Button("Remove last spot"){session.change {$0.retouch?.removeLast()}}.disabled(session.recipe.retouch?.isEmpty != false);Button("Clear spots",role:.destructive){session.change {$0.retouch=nil}}.disabled(session.recipe.retouch?.isEmpty != false)}.font(.caption)
            }.padding(16).background(StudioStyle.panel)
        }.background(StudioStyle.ink).navigationTitle("Heal & Clone").navigationBarTitleDisplayMode(.inline).toolbar {Button("Done"){dismiss()}}}.tint(StudioStyle.blue)
    }
}

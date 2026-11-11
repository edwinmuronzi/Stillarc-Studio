import SwiftUI

struct SplitComparisonDivider:View {
    let sourceSize:CGSize
    let recipe:Recipe
    @Binding var fraction:Double
    var body:some View {
        GeometryReader { geometry in
            let framed = PhotoFraming.window(in:PhotoFraming.orientedSize(sourceSize,recipe:recipe),recipe:recipe).size
            let scale = min(geometry.size.width/framed.width,geometry.size.height/framed.height)
            let width = framed.width*scale,height = framed.height*scale
            let x = (geometry.size.width-width)/2+width*fraction,y = geometry.size.height/2
            Rectangle().fill(.white.opacity(0.85)).frame(width:1,height:height).position(x:x,y:y).allowsHitTesting(false)
            Image(systemName:"arrow.left.and.right").font(.caption.bold()).frame(width:44,height:44).background(.regularMaterial,in:Circle())
                .overlay(Circle().stroke(.white.opacity(0.5),lineWidth:1)).position(x:x,y:(geometry.size.height-height)/2+height*0.25)
                .gesture(DragGesture(minimumDistance:0,coordinateSpace:.named("comparisonPreview")).onChanged { value in fraction = min(1,max(0,(value.location.x-(geometry.size.width-width)/2)/width)) })
                .accessibilityLabel("Before and after divider")
                .accessibilityValue("\(Int(fraction*100)) percent original")
                .accessibilityAdjustableAction { direction in fraction = min(1,max(0,fraction+(direction == .increment ? 0.1 : -0.1))) }
        }
    }
}

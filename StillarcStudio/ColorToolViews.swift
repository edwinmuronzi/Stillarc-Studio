import SwiftUI

extension CurveChannel {
    var color: Color { switch self { case .master: StudioStyle.blue; case .red: .red; case .green: .green; case .blue: .blue } }
}
extension ColorRange {
    var color: Color { Color(hue:degrees/360,saturation:0.82,brightness:0.95) }
}
enum ColorPanel: String, CaseIterable { case global = "All colors", selective = "Color mix", wheels = "Wheels", mixer = "Mixer" }
@MainActor struct ColorRangePicker: View {
    @Binding var selected: ColorRange
    let adjustments: SelectiveColors
    var body: some View {
        ScrollView(.horizontal,showsIndicators:false) {
            HStack(spacing:7) {
                ForEach(ColorRange.allCases) { range in
                    Button { selected = range } label: {
                        VStack(spacing:6) {
                            Circle().fill(range.color).frame(width:26,height:26).padding(5)
                                .overlay(Circle().stroke(selected == range ? .white : .clear,lineWidth:1.5))
                            Circle().fill(StudioStyle.blue).frame(width:4,height:4).opacity(adjustments[keyPath:range.key].isNeutral ? 0 : 1)
                        }.frame(width:39,height:50)
                    }.buttonStyle(.plain).accessibilityLabel(range.title).accessibilityValue(adjustments[keyPath:range.key].isNeutral ? "No adjustments" : "Adjusted").accessibilityAddTraits(selected == range ? .isSelected : [])
                }
            }.padding(.horizontal,2)
        }
    }
}
@MainActor struct RGBCurveGraph: View {
    @Bindable var session: EditSession
    let channel: CurveChannel
    var editable = false
    @Binding var selected: CurvePoint
    @State private var dragging: CurvePoint?
    @State private var initialY = 0.0
    @State private var initialValue = 0.0
    private let inset: CGFloat = 14
    var body: some View {
        GeometryReader { geometry in
            let width = max(1,geometry.size.width-inset*2), height = max(1,geometry.size.height-inset*2)
            Canvas { context,size in
                let rect = CGRect(x:inset,y:inset,width:width,height:height)
                var grid = Path()
                for i in 0...4 {
                    let t = CGFloat(i)/4
                    grid.move(to:CGPoint(x:rect.minX+t*width,y:rect.minY)); grid.addLine(to:CGPoint(x:rect.minX+t*width,y:rect.maxY))
                    grid.move(to:CGPoint(x:rect.minX,y:rect.minY+t*height)); grid.addLine(to:CGPoint(x:rect.maxX,y:rect.minY+t*height))
                }
                context.stroke(grid,with:.color(.white.opacity(0.08)),lineWidth:1)
                var diagonal = Path(); diagonal.move(to:CGPoint(x:rect.minX,y:rect.maxY)); diagonal.addLine(to:CGPoint(x:rect.maxX,y:rect.minY))
                context.stroke(diagonal,with:.color(.white.opacity(0.2)),style:StrokeStyle(lineWidth:1,dash:[3,4]))
                let curve = session.recipe.rgbCurves[keyPath:channel.key]
                let spline = CurveSpline(curve)
                var line = Path()
                for n in 0...128 {
                    let x = Double(n)/128
                    let point = CGPoint(x:rect.minX+x*width,y:rect.maxY-spline.value(at:x)*height)
                    if n == 0 { line.move(to:point) } else { line.addLine(to:point) }
                }
                context.stroke(line,with:.color(channel.color),style:StrokeStyle(lineWidth:2,lineCap:.round))
                for point in CurvePoint.allCases {
                    let center = CGPoint(x:rect.minX+point.input*width,y:rect.maxY-curve[keyPath:point.key]*height)
                    let radius: CGFloat = point == selected ? 6 : 4
                    let knob = Path(ellipseIn:CGRect(x:center.x-radius,y:center.y-radius,width:radius*2,height:radius*2))
                    context.fill(knob,with:.color(point == selected ? .white : channel.color))
                    context.stroke(knob,with:.color(channel.color),lineWidth:1.5)
                }
            }
            .background(Color.white.opacity(0.02),in:RoundedRectangle(cornerRadius:14))
            .contentShape(Rectangle())
            .highPriorityGesture(DragGesture(minimumDistance:0).onChanged { value in
                if dragging == nil {
                    let curve = session.recipe.rgbCurves[keyPath:channel.key]
                    let nearest = CurvePoint.allCases.min { a,b in
                        func distance(_ p: CurvePoint) -> CGFloat {
                            let dx = inset+p.input*width-value.startLocation.x
                            let dy = inset+(1-curve[keyPath:p.key])*height-value.startLocation.y
                            return dx*dx+dy*dy
                        }
                        return distance(a) < distance(b)
                    } ?? .middle
                    dragging = nearest; selected = nearest
                    initialY = value.startLocation.y
                    initialValue = curve[keyPath:nearest.key]
                    session.begin()
                }
                if let dragging { session.recipe[keyPath:channel.recipeKey(dragging)] = min(1,max(0,initialValue-Double(value.location.y-initialY)/height)) }
            }.onEnded { _ in dragging = nil; session.end() },including:editable ? .all : .none)
            .onDisappear { if dragging != nil { dragging = nil;session.end() } }
            .onChange(of:editable) { _,value in if !value && dragging != nil { dragging = nil;session.end() } }
            .accessibilityRepresentation {
                VStack {
                    ForEach(CurvePoint.allCases) { point in
                        Button(point.title) { selected = point }
                            .accessibilityLabel("\(channel.rawValue) curve, \(point.title.lowercased())")
                            .accessibilityValue("\(Int(session.recipe[keyPath:channel.recipeKey(point)]*100)) percent")
                            .accessibilityAdjustableAction { direction in
                                selected = point
                                let key = channel.recipeKey(point)
                                session.change { r in r[keyPath:key] = min(1,max(0,r[keyPath:key]+(direction == .increment ? 0.01 : -0.01))) }
                            }
                    }
                }
            }
        }.accessibilityElement(children:.contain).accessibilityLabel("RGB curve graph").accessibilityIdentifier("rgbCurveGraph")
    }
}

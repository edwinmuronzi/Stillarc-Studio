import SwiftUI

@MainActor struct GradingWheel: View {
    @Bindable var session: EditSession
    let zone: WheelZone
    @State private var dragging = false
    @State private var grabOffset = CGSize.zero
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width,geometry.size.height), radius = max(1,side/2-10)
            let grade = session.recipe.colorWheels[keyPath:zone.key]
            let angle = grade.hue * .pi / 180
            let center = CGPoint(x:geometry.size.width/2,y:geometry.size.height/2)
            let knob = CGPoint(x:center.x+cos(angle)*grade.strength*radius,y:center.y-sin(angle)*grade.strength*radius)
            ZStack {
                Circle().fill(AngularGradient(colors:[.red,Color(red:1,green:0,blue:1),.blue,.cyan,.green,.yellow,.red],center:.center))
                    .overlay(Circle().fill(RadialGradient(colors:[.white,.white.opacity(0)],center:.center,startRadius:0,endRadius:radius)))
                    .saturation(0.8).padding(10)
                Circle().stroke(.white.opacity(0.2),lineWidth:1).padding(10)
                Circle().fill(.black.opacity(0.35)).frame(width:3,height:3).position(center)
                Circle().fill(.black.opacity(0.25)).overlay(Circle().stroke(.white,lineWidth:2)).frame(width:14,height:14).position(knob)
            }
            .contentShape(Circle())
            .highPriorityGesture(DragGesture(minimumDistance:0).onChanged { value in
                if !dragging {
                    dragging = true; session.begin()
                    let near = hypot(value.startLocation.x-knob.x,value.startLocation.y-knob.y) < 22
                    grabOffset = near ? CGSize(width:knob.x-value.startLocation.x,height:knob.y-value.startLocation.y) : .zero
                }
                let dx = Double(value.location.x+grabOffset.width-center.x)/radius
                let dy = -Double(value.location.y+grabOffset.height-center.y)/radius
                let distance = hypot(dx,dy)
                var wheel = session.recipe.colorWheels[keyPath:zone.key]
                wheel.strength = min(1,distance)
                if distance > 0.0001 { let angle = atan2(dy,dx)*180 / .pi; wheel.hue = angle < 0 ? angle+360 : angle }
                session.recipe.colorWheels[keyPath:zone.key] = wheel
            }.onEnded { _ in dragging = false; session.end() })
            .accessibilityLabel("\(zone.rawValue) color wheel")
            .accessibilityValue("Hue \(Int(grade.hue)) degrees, strength \(Int(grade.strength*100)) percent")
            .accessibilityHint("Use the hue and strength sliders for precise accessible adjustments.")
        }
    }
}

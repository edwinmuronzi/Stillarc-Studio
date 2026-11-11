#if DEBUG
import SwiftUI
struct SliderGestureVerificationView:View {
    @State private var value = 0.75
    @State private var resets = 0
    var body:some View {
        VStack(spacing:24) {
            Text(String(format:"%.2f",value)).accessibilityIdentifier("testValue")
            Slider(value:$value,in:0...1).accessibilityIdentifier("testSlider").sliderReset { value = 0.25;resets += 1 }
            Text("\(resets)").accessibilityIdentifier("resetCount")
            Button("Set changed") { value = 0.75 }.accessibilityIdentifier("setChanged")
        }.padding(40)
    }
}
#endif

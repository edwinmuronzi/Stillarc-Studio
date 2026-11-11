import SwiftUI

/// Simultaneous recognition leaves native slider drags responsive; reset is also available to VoiceOver.
struct SliderReset: ViewModifier {
    let reset: () -> Void
    func body(content:Content) -> some View {
        content
            .simultaneousGesture(TapGesture(count:2).onEnded { DispatchQueue.main.async { reset() } })
            .accessibilityAction(named:Text("Reset to default"),reset)
            .accessibilityHint("Double-tap the slider to reset its value. With VoiceOver, use the Reset to default action.")
    }
}
extension View {
    func sliderReset(_ reset:@escaping () -> Void) -> some View { modifier(SliderReset(reset:reset)) }
}

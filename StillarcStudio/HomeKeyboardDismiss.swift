import SwiftUI
import UIKit

struct HomeKeyboardDismiss:UIViewRepresentable {
    let active:Bool
    let dismiss:()->Void
    func makeUIView(context:Context) -> Probe { Probe() }
    func updateUIView(_ view:Probe,context:Context) { view.enabled = active;view.dismiss = dismiss;view.tap?.isEnabled = active }
    static func dismantleUIView(_ view:Probe,coordinator:()) { view.detach() }
    final class Probe:UIView,UIGestureRecognizerDelegate {
        var enabled = false
        var dismiss:()->Void = {}
        var tap:UITapGestureRecognizer?
        weak var observed:UIWindow?
        override func didMoveToWindow() {
            super.didMoveToWindow();detach()
            guard let window else { return }
            let gesture = UITapGestureRecognizer(target:self,action:#selector(touched));gesture.cancelsTouchesInView = false;gesture.delegate = self;gesture.isEnabled = enabled
            window.addGestureRecognizer(gesture);observed = window;tap = gesture
        }
        func detach() { if let tap { observed?.removeGestureRecognizer(tap) };tap = nil;observed = nil }
        @objc private func touched() { dismiss() }
        func gestureRecognizer(_ gestureRecognizer:UIGestureRecognizer,shouldReceive touch:UITouch) -> Bool {
            guard enabled,let window,convert(bounds,to:window).contains(touch.location(in:window)) else { return false }
            var node = touch.view
            while let view = node { if view is UITextField || view is UITextView { return false };node = view.superview }
            return true
        }
        func gestureRecognizer(_ gestureRecognizer:UIGestureRecognizer,shouldRecognizeSimultaneouslyWith otherGestureRecognizer:UIGestureRecognizer) -> Bool { true }
    }
}

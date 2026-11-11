import SwiftUI
import UIKit

/// Full-screen editor owns its insets; only the background extends under system UI.
@MainActor struct EditorSafeArea<Content:View>:View {
    @State private var windowInsets = initialInsets()
    private static func initialInsets() -> UIEdgeInsets {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
        guard let window = scene?.windows.first(where: { $0.isKeyWindow }) else { return .zero }
        var value = window.safeAreaInsets
        if scene?.interfaceOrientation.isPortrait == true { value.top = max(value.top,scene?.statusBarManager?.statusBarFrame.height ?? 0) }
        return value
    }
    let content:Content
    init(@ViewBuilder content:() -> Content) { self.content = content() }
    var body:some View {
        GeometryReader { geometry in
            content
                .padding(.top,max(geometry.safeAreaInsets.top,windowInsets.top))
                .padding(.bottom,max(geometry.safeAreaInsets.bottom,windowInsets.bottom))
                .padding(.leading,max(geometry.safeAreaInsets.leading,windowInsets.left))
                .padding(.trailing,max(geometry.safeAreaInsets.trailing,windowInsets.right))
                .frame(maxWidth:.infinity,maxHeight:.infinity)
                .background { WindowInsetsReader(insets:$windowInsets).allowsHitTesting(false) }
        }.ignoresSafeArea().background(StudioStyle.ink)
    }
}
private struct WindowInsetsReader:UIViewRepresentable {
    @Binding var insets:UIEdgeInsets
    func makeUIView(context:Context) -> Probe { let view = Probe();view.changed = { value in if insets != value { insets = value } };return view }
    func updateUIView(_ view:Probe,context:Context) { view.changed = { value in if insets != value { insets = value } };view.schedule() }
    final class Probe:UIView {
        var changed:((UIEdgeInsets)->Void)?
        private var scheduled = false
        private var observer:NSObjectProtocol?
        override init(frame:CGRect) {
            super.init(frame:frame)
            observer = NotificationCenter.default.addObserver(forName:UIApplication.didBecomeActiveNotification,object:nil,queue:.main) { [weak self] _ in self?.schedule() }
        }
        required init?(coder:NSCoder) { fatalError() }
        deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
        override func didMoveToWindow() { super.didMoveToWindow();schedule() }
        override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange();schedule() }
        override func layoutSubviews() { super.layoutSubviews();schedule() }
        func schedule() {
            guard !scheduled else { return };scheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return };self.scheduled = false
                guard let window = self.window else { return }
                var value = window.safeAreaInsets
                if window.windowScene?.interfaceOrientation.isPortrait == true { value.top = max(value.top,window.windowScene?.statusBarManager?.statusBarFrame.height ?? 0) }
                self.changed?(value)
            }
        }
    }
}

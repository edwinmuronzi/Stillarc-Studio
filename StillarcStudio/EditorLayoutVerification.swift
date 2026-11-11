#if DEBUG
import SwiftUI

struct EditorLayoutVerification:UIViewRepresentable {
    func makeUIView(context:Context) -> Probe { Probe() }
    func updateUIView(_ view:Probe,context:Context) { view.setNeedsLayout() }
    final class Probe:UIView {
        private var last = CGRect.null
        override func layoutSubviews() {
            super.layoutSubviews()
            guard ProcessInfo.processInfo.arguments.contains("--verify-editor-layout"),let window else { return }
            let rect = convert(bounds,to:window)
            guard rect != last,rect.height>0 else { return };last = rect
            let safe = window.safeAreaInsets
            let payload:[String:Any] = ["passed":rect.minY>=safe.top-0.5 && rect.minX>=safe.left-0.5 && rect.maxX<=window.bounds.width-safe.right+0.5,"headerY":rect.minY,"headerHeight":rect.height,"headerX":rect.minX,"headerWidth":rect.width,"safeTop":safe.top,"safeLeft":safe.left,"safeRight":safe.right,"windowWidth":window.bounds.width,"windowHeight":window.bounds.height]
            DispatchQueue.main.async {
                let url = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("editor-layout.json")
                if let data = try? JSONSerialization.data(withJSONObject:payload,options:.prettyPrinted) { try? data.write(to:url,options:.atomic) }
            }
        }
    }
}
#endif

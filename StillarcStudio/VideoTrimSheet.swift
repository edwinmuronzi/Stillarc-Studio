import SwiftUI

struct VideoTrimSheet:View {
    @Bindable var session:EditSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    private var duration:Double { session.project.video?.duration ?? 1 }
    private var range:ClosedRange<Double> { session.recipe.video.range(duration:duration) }
    private var step:Double { 1/max(1,session.project.video?.frameRate ?? 30) }
    var body:some View {
        NavigationStack {
            Form {
                if let video = session.project.video,let url = session.sourceURL,let source = session.source {
                    Section { VideoPreview(url:url,descriptor:video,poster:source,recipe:session.recipe,original:false,active:phase == .active,showTrimButton:false).frame(height:180).listRowInsets(EdgeInsets()).clipShape(RoundedRectangle(cornerRadius:14)) }
                }
                Section {
                    HStack { Text("Keep");Spacer();Text(time(range.upperBound-range.lowerBound)).monospacedDigit().foregroundStyle(StudioStyle.blue) }
                    Text("\(time(range.lowerBound)) → \(time(range.upperBound))").font(.title2.monospacedDigit()).frame(maxWidth:.infinity).padding(.vertical,12)
                    HStack(spacing:0) {
                        Rectangle().fill(.white.opacity(0.12)).frame(width:max(0,240*range.lowerBound/duration))
                        Rectangle().fill(StudioStyle.blue)
                        Rectangle().fill(.white.opacity(0.12)).frame(width:max(0,240*(duration-range.upperBound)/duration))
                    }.frame(width:240,height:16).clipShape(Capsule()).frame(maxWidth:.infinity).accessibilityHidden(true)
                    Text("Start · \(time(range.lowerBound))").font(.subheadline.monospacedDigit())
                    Slider(value:Binding(get:{ range.lowerBound },set:{ value in session.recipe.video.start = min(value,max(0,range.upperBound-min(step,duration))) }),in:0...duration,step:step,onEditingChanged:{ $0 ? session.begin() : session.end() }).accessibilityLabel("Trim start")
                    Text("End · \(time(range.upperBound))").font(.subheadline.monospacedDigit())
                    Slider(value:Binding(get:{ range.upperBound },set:{ value in session.recipe.video.end = max(value,min(duration,range.lowerBound+min(step,duration))) }),in:0...duration,step:step,onEditingChanged:{ $0 ? session.begin() : session.end() }).accessibilityLabel("Trim end")
                    Button("Use entire clip") { session.change { $0.video.start = 0;$0.video.end = nil } }
                } footer: { Text("Keep the part you want. The original stays intact; playback and export use this range. Adjustments remain editable, and undo restores your previous trim.") }
            }.navigationTitle("Trim video").navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { dismiss() } }
        }.tint(StudioStyle.blue).presentationDetents([.large])
    }
    private func time(_ value:Double) -> String { String(format:"%02d:%05.2f",Int(value)/60,value.truncatingRemainder(dividingBy:60)) }
}

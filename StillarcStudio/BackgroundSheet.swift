import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct BackgroundSheet:View {
    @Bindable var session:EditSession
    @Bindable var library:StudioLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var picker:PhotosPickerItem?
    @State private var files=false
    @State private var busy=false
    @State private var error:String?
    private var settings:PhotoBackground {session.recipe.background ?? PhotoBackground()}
    private func update(_ body:(inout PhotoBackground)->Void) {session.change {var value=$0.background ?? PhotoBackground();body(&value);$0.background=value}}
    private func slider(_ name:String,_ key:WritableKeyPath<PhotoBackground,Double>,_ range:ClosedRange<Double>,defaultValue:Double) -> some View {
        VStack {HStack {Text(name);Spacer();Text(settings[keyPath:key],format:.number.precision(.fractionLength(2))).monospacedDigit()}.font(.caption)
            Slider(value:Binding(get:{settings[keyPath:key]},set:{v in var value=settings;value[keyPath:key]=v;session.recipe.background=value}),in:range,onEditingChanged:{$0 ? session.begin():session.end()}).accessibilityLabel(name).sliderReset {update {$0[keyPath:key]=defaultValue}}
        }
    }
    var body:some View {
        NavigationStack {ScrollView {VStack(alignment:.leading,spacing:20) {
            Text("Keep your subject. Change the scene.").font(.title2.weight(.semibold))
            Text("Create a cutout with Remove background first. These controls affect the replacement behind it; your foreground grade stays separate.").font(.subheadline).foregroundStyle(StudioStyle.secondary)
            Picker("Background mode",selection:Binding(get:{settings.mode},set:{v in update {$0.mode=v;if v == .blur && $0.blur == 0 {$0.blur=0.5}}})) {ForEach(PhotoBackgroundMode.allCases) {Text($0.rawValue).tag($0)}}.pickerStyle(.menu).accessibilityIdentifier("backgroundMode")
            if settings.mode == .solid || settings.mode == .image {
                HStack {ForEach(Array([(0.05,0.06,0.08),(1.0,1.0,1.0),(0.15,0.35,0.70),(0.72,0.38,0.23)].enumerated()),id:\.offset) {index,c in Button {update {$0.red=c.0;$0.green=c.1;$0.blue=c.2}} label:{Circle().fill(Color(red:c.0,green:c.1,blue:c.2)).frame(width:38,height:38)}.accessibilityLabel("Background swatch \(index+1)")}}
                slider("Background red",\.red,0...1,defaultValue:0.12);slider("Background green",\.green,0...1,defaultValue:0.14);slider("Background blue",\.blue,0...1,defaultValue:0.18)
            }
            if settings.mode == .image {
                HStack {PhotosPicker(selection:$picker,matching:.images,preferredItemEncoding:.current) {Label("Photos",systemImage:"photo")};Button("Files",systemImage:"folder"){files=true}}.buttonStyle(.bordered)
                Text(settings.asset == nil ? "Choose an image to replace the background.":"Image stored with this project; changing modes keeps it available for Undo.").font(.caption).foregroundStyle(StudioStyle.secondary)
                Toggle("Fill frame",isOn:Binding(get:{settings.fill},set:{v in update {$0.fill=v}}))
                slider("Background scale",\.scale,0.25...4,defaultValue:1);slider("Background horizontal",\.x,0...1,defaultValue:0.5);slider("Background vertical",\.y,0...1,defaultValue:0.5)
            }
            if settings.mode != .transparent {
                slider("Background blur",\.blur,0...1,defaultValue:0)
                slider("Background exposure",\.exposure,-3...3,defaultValue:0)
                slider("Background saturation",\.saturation,-1...1,defaultValue:0)
            }
            if busy {ProgressView("Importing background…")}
            if let error {Text(error).font(.caption).foregroundStyle(.orange)}
            Text("Use a little blur to soften distractions behind your subject. Check hair and translucent edges after replacing the background.").font(.caption).foregroundStyle(StudioStyle.secondary)
        }.padding(20)}.safeAreaInset(edge:.top) {if let photo=session.source {LivePreview(source:PhotoRendering.rawPreview(photo,recipe:session.recipe),recipe:session.recipe,original:false,hdr:session.recipe.photoHDR == true).frame(height:220).clipShape(RoundedRectangle(cornerRadius:16)).padding(.horizontal,16).padding(.bottom,8)}}.navigationTitle("Background").navigationBarTitleDisplayMode(.inline).toolbar {Button("Done"){dismiss()}.disabled(busy)}}.tint(StudioStyle.blue).presentationDetents([.large]).interactiveDismissDisabled(busy)
        .onChange(of:picker) {_,item in guard let item else {return};Task {do {guard let transfer=try await item.loadTransferable(type:PhotoTransfer.self) else {throw StudioError.unreadable};defer {try? FileManager.default.removeItem(at:transfer.url.deletingLastPathComponent())};await load(transfer.url)} catch {self.error=error.localizedDescription};picker=nil}}
        .fileImporter(isPresented:$files,allowedContentTypes:[.image]) {result in if case .success(let url)=result {Task {let secured=url.startAccessingSecurityScopedResource();defer {if secured {url.stopAccessingSecurityScopedResource()}};await load(url)}}}
    }
    private func load(_ url:URL) async {
        guard !busy else {return};busy=true;defer {busy=false};error=nil
        do {let asset=try await library.vault.importBackground(url,project:session.project);update {$0.asset=asset;$0.mode = .image}}
        catch {self.error=error.localizedDescription}
    }
}

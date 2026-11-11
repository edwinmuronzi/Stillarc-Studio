import SwiftUI

enum AdjustmentTransferMode:String,Identifiable { case copy,paste;var id:String { rawValue } }
struct AdjustmentTransferSheet:View {
    #if DEBUG
    static var presentedIDs = Set<UUID>()
    @State private var presentationID = UUID()
    #endif
    let mode:AdjustmentTransferMode
    @Bindable var session:EditSession
    @Bindable var library:StudioLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var selected = Set<AdjustmentSection>()
    @State private var busy = false
    @State private var initialized = false
    @State private var error:String?
    private var available:[AdjustmentSection] { mode == .copy ? AdjustmentSection.allCases : (library.adjustmentClipboard?.sections ?? []) }
    var body:some View {
        NavigationStack {
            List {
                if mode == .paste,let clipboard = library.adjustmentClipboard {
                    Section { Text("Copied from \(clipboard.sourceName)");Text(clipboard.copied,format:.dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(.secondary) }
                }
                Section {
                    ForEach(available) { section in
                        Toggle(isOn:Binding(get:{ selected.contains(section) },set:{ if $0 { selected.insert(section) } else { selected.remove(section) } })) {
                            VStack(alignment:.leading,spacing:4) { Text(section.title);Text(section.help).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    HStack {
                        Button("Select all") { selected = Set(available) }
                        Spacer()
                        Button("Select none") { selected = [] }
                    }.buttonStyle(.borderless)
                } footer: { Text(mode == .copy ? "Choose which adjustments to keep in Studio’s internal clipboard. It stays available after closing the app; copying again replaces it. No media is copied." : "Selected sections replace their destination values, including neutral/Off settings. Unselected adjustments stay as they are. Crop, flips, perspective, input profile, trim, HDR choice and saved versions stay with this destination. Undo reverses the paste.") }
                Section {
                    Button(mode == .copy ? "Copy selected adjustments" : "Paste selected adjustments") { Task { await perform() } }.disabled(selected.isEmpty)
                    if mode == .paste { Button("Clear copied adjustments",role:.destructive) { Task { busy = true;defer { busy = false };if await library.clearCopiedAdjustments() { dismiss() } else { error = library.error } } } }
                }
                if let error { Text(error).font(.caption).foregroundStyle(.orange) }
            }.disabled(busy)
                .overlay { if busy { ProgressView().padding().background(.regularMaterial,in:RoundedRectangle(cornerRadius:12)) } }
                .navigationTitle(mode == .copy ? "Copy adjustments" : "Paste adjustments").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() }.disabled(busy) }
        }.tint(StudioStyle.blue).interactiveDismissDisabled(busy)
        .onAppear {
            if !initialized { selected = Set(available);initialized = true }
            #if DEBUG
            Self.presentedIDs.insert(presentationID)
            #endif
        }
    }
    private func perform() async {
        guard !busy,!selected.isEmpty else { return };busy = true;defer { busy = false }
        if mode == .copy {
            if await library.copyAdjustments(name:session.project.name,recipe:session.recipe,sections:selected) { dismiss() } else { error = library.error }
        } else if let clip = library.adjustmentClipboard {
            let sections = selected.intersection(Set(clip.sections))
            guard !sections.isEmpty else { return }
            session.change { $0 = $0.pasting(clip.recipe,sections:sections) }
            if await session.persist(library) { dismiss() } else { error = library.error }
        }
    }
}

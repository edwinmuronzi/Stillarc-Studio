import SwiftUI

struct HomeCopyAdjustmentsSheet:View {
    let project:Project
    @Bindable var library:StudioLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var sections = Set(AdjustmentSection.allCases)
    @State private var busy = false
    @State private var error:String?
    var body:some View {
        NavigationStack {
            List {
                Section { Text("Copy from \(project.name)").font(.headline);Text("Choose the adjustments to reuse on other projects. No photo or video is copied. Framing, masks and clip settings stay with their own project.").font(.caption).foregroundStyle(StudioStyle.secondary) }
                Section("Adjustments") {
                    ForEach(AdjustmentSection.allCases) { section in
                        Toggle(isOn:Binding(get:{ sections.contains(section) },set:{ if $0 { sections.insert(section) } else { sections.remove(section) } })) {
                            VStack(alignment:.leading,spacing:4) { Text(section.title);Text(section.help).font(.caption).foregroundStyle(StudioStyle.secondary) }
                        }
                    }
                    HStack { Button("Select all") { sections = Set(AdjustmentSection.allCases) };Spacer();Button("Select none") { sections = [] } }.buttonStyle(.borderless)
                }
                Section {
                    Text("The Studio clipboard remains available after reopening the app. Copying again replaces it; neutral settings also replace destination settings when pasted.").font(.caption).foregroundStyle(StudioStyle.secondary)
                    if let error { Text(error).font(.caption).foregroundStyle(.orange) }
                }
            }.disabled(busy).navigationTitle("Copy adjustments").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() }.disabled(busy) }
                .safeAreaInset(edge:.bottom) {
                    Button("Copy selected adjustments") {
                        busy = true
                        Task { @MainActor in
                            defer { busy = false }
                            if await library.copyAdjustments(name:project.name,recipe:project.recipe,sections:sections) { dismiss() } else { error = library.error }
                        }
                    }.disabled(busy || sections.isEmpty).accessibilityIdentifier("copyHomeAdjustments")
                        .buttonStyle(.borderedProminent).frame(maxWidth:.infinity).padding(14).background(.regularMaterial)
                }
        }.tint(StudioStyle.blue).interactiveDismissDisabled(busy)
    }
}

import SwiftUI

struct VersionsSheet:View {
    #if DEBUG
    static var presentationCount = 0
    static var presentedIDs = Set<UUID>()
    @State private var presentationID = UUID()
    #endif
    @Bindable var session:EditSession
    @Bindable var library:StudioLibrary
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var deletion:EditVersion?
    var body:some View {
        NavigationStack {
            List {
                Section {
                    TextField("Name this version",text:$name).submitLabel(.done)
                    Button("Save current version",systemImage:"plus") {
                        Task { await session.saveVersion(name:name,library:library);name = "" }
                    }.disabled(name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || (session.project.versions?.count ?? 0)>=20)
                } footer: { Text("A version remembers this photo or clip’s complete edit, including framing, input conversion and trim. It does not duplicate the original media. Save up to 20 per project.") }
                if let error = session.error ?? library.error { Text(error).font(.caption).foregroundStyle(.orange) }
                Section {
                    if (session.project.versions ?? []).isEmpty { Text("Save a version before trying a different grade.").foregroundStyle(.secondary) }
                    ForEach(versions) { version in versionRow(version) }
                } header: { Text("Saved versions") } footer: { Text("Restore replaces the current adjustments. Undo returns to the edit you had before restoring. Versions belong to this source; use Looks for presets you want to apply to other media.") }
            }.disabled(session.versionsBusy)
            .overlay { if session.versionsBusy { ProgressView().padding().background(.regularMaterial,in:RoundedRectangle(cornerRadius:12)) } }
            .navigationTitle("Versions").navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { dismiss() }.disabled(session.versionsBusy) }
            .confirmationDialog("Delete this saved version?",isPresented:Binding(get:{ deletion != nil },set:{ if !$0 { deletion = nil } })) {
                Button("Delete version",role:.destructive) { if let version = deletion { Task { await session.deleteVersion(version,library:library) } };deletion = nil }
            }
        }.tint(StudioStyle.blue).interactiveDismissDisabled(session.versionsBusy)
        .onAppear {
            #if DEBUG
            if Self.presentedIDs.insert(presentationID).inserted { Self.presentationCount += 1 }
            #endif
        }
    }
    private var versions:[EditVersion] { Array((session.project.versions ?? []).reversed()) }
    private func versionRow(_ version:EditVersion) -> some View {
        HStack {
            VStack(alignment:.leading) {
                Text(version.name)
                Text(version.created,format:.dateTime.month().day().hour().minute()).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Restore") { Task { if await session.restoreVersion(version,library:library) { dismiss() } } }.buttonStyle(.bordered)
            Button { deletion = version } label: { Image(systemName:"trash").frame(width:32,height:44) }
                .tint(Color.red).buttonStyle(.borderless).accessibilityLabel("Delete \(version.name)")
        }
    }

}

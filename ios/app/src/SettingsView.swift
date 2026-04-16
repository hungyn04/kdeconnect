import SwiftUI

extension String: Identifiable {
    public typealias ID = Int
    public var id: Int {
        return hash
    }
}

class SettingsViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var type: DeviceType = .desktop
    @Published var trustedNetworks: String = ""

    private let baseURL = URL(fileURLWithPath: "/var/mobile/kdeconnect", isDirectory: true)

    private var nameURL: URL {
        baseURL.appendingPathComponent("name")
    }

    private var typeURL: URL {
        baseURL.appendingPathComponent("type")
    }

    private var trustedURL: URL {
        baseURL.appendingPathComponent("trusted")
    }

    init() {
        try? loadSettings()
    }

    func ensureSettingsFiles() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: baseURL, withIntermediateDirectories: true)

        if !fm.fileExists(atPath: nameURL.path) {
            try UIDevice.current.name.write(to: nameURL, atomically: true, encoding: .utf8)
        }

        if !fm.fileExists(atPath: typeURL.path) {
            try "phone".write(to: typeURL, atomically: true, encoding: .utf8)
        }

        if !fm.fileExists(atPath: trustedURL.path) {
            try "".write(to: trustedURL, atomically: true, encoding: .utf8)
        }
    }

    func loadSettings() throws {
        try ensureSettingsFiles()

        let loadedName = try String(contentsOf: nameURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        name = loadedName.isEmpty ? UIDevice.current.name : loadedName

        let loadedType = try String(contentsOf: typeURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        type = (try? DeviceType.fromString(loadedType)) ?? .phone

        trustedNetworks = try String(contentsOf: trustedURL, encoding: .utf8)
    }

    func saveSettings() throws {
        try ensureSettingsFiles()

        let finalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try (finalName.isEmpty ? UIDevice.current.name : finalName).write(to: nameURL, atomically: true, encoding: .utf8)
        try type.toString().lowercased().write(to: typeURL, atomically: true, encoding: .utf8)
        try trustedNetworks.write(to: trustedURL, atomically: true, encoding: .utf8)
    }
}

struct SettingsView: View {
    @ObservedObject var state: SettingsViewModel
    var exit: () -> Void 

    var body: some View {
        List {
            HStack {
                Text("Name")
                TextField("Name", text: $state.name).multilineTextAlignment(.trailing)
            }
            HStack {
                Picker("Type", selection: $state.type) {
                    ForEach(DeviceType.allCases) { type in
                        Text(type.toString())
                    }
                }
            }
            NavigationLink("Trusted Networks") {
                List {
                    Section("One network per line") {
                        TextEditor(text: $state.trustedNetworks)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 220)
                    }
                }.navigationTitle("Trusted Networks")
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button("Load") {
                    do {
                        try state.loadSettings()
                    } catch {
                        UIApplication.shared.alert(body: error.localizedDescription)
                    }
                }
                Button("Save") {
                    do {
                        try state.saveSettings()
                        exit()
                    } catch {
                        UIApplication.shared.alert(body: error.localizedDescription)
                    }
                }
            }
        }
    }
}

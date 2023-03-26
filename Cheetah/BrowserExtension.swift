import CheetahIPC

class BrowserExtensionState: JSONHandler<BrowserExtensionMessage> {
    @Published var mode: String?
    @Published var files = [String: String]()
    @Published var logs = [String: String]()
    
    var navigationStart = 0
    var lastUpdate: Date?
    
    public init() {
        super.init(respondsTo: IPCMessage.browserExtensionMessage)
        
        handler = {
            guard let message = $0 else {
                return nil
            }
            
            if message.navigationStart > self.navigationStart {
                self.navigationStart = message.navigationStart
                self.files.removeAll()
                self.logs.removeAll()
            }
            
            let newMode = message.mode
            if newMode != self.mode {
                self.mode = newMode
                self.files.removeAll()
                self.logs.removeAll()
            }
            
            for (name, content) in message.files {
                self.files[name] = content
            }
            for (name, content) in message.logs {
                self.logs[name] = content
            }
            
            if self.lastUpdate == nil {
                print("BrowserExtensionState: first message was received!")
            }
            
            self.lastUpdate = Date.now
            return nil
        }
    }
    
    var codeDescription: String {
        if files.isEmpty {
            return "N/A"
        } else {
            return files
                .map { name, content in "[\(name)]\n\(content)" }
                .joined(separator: "\n\n")
        }
    }
    
    var logsDescription: String {
        if logs.isEmpty {
            return "N/A"
        } else {
            return logs
                .map { name, content in
                    let recentLines = content.split(separator: "\n").suffix(20).joined(separator: "\n")
                    return "[\(name)]\n\(recentLines)"
                }
                .joined(separator: "\n\n")
        }
    }
}

struct NativeMessagingManifest: Codable {
    enum `Type`: String, Codable {
        case stdio
    }
    
    let name: String
    let description: String
    let path: String
    let type: `Type`
    let allowedExtensions: [String]
}

func installNativeMessagingManifest() throws -> Bool {
    let manifest = NativeMessagingManifest(
        name: "cheetah",
        description: "Cheetah Extension",
        path: Bundle.main.path(forAuxiliaryExecutable: "ExtensionHelper")!,
        type: .stdio,
        allowedExtensions: ["cheetah@phrack.org"])
    
    let path = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/Mozilla/NativeMessagingHosts/cheetah.json").absoluteURL.path
    
    print("Installing native messaging manifest at \(path)")
    
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    
    let contents = try encoder.encode(manifest)
    return FileManager.default.createFile(atPath: path, contents: contents)
}

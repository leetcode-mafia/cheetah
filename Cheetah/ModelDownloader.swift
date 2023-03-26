import Foundation

extension Bundle {
    var displayName: String? {
        return object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String
    }
}

var cacheDirectory: URL {
    let parent = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    return parent.appending(path: Bundle.main.bundleIdentifier!)
}

class ModelDownloader {
    enum State {
        case pending
        case completed
        case failed(Error?)
    }
    
    @Published var state = State.pending
    
    let baseURL = URL(string: "https://huggingface.co/datasets/ggerganov/whisper.cpp/resolve/main")!
    
    let modelName: String
    let session: URLSession
    let filename: String
    let modelURL: URL
    
    var task: URLSessionDownloadTask?
    
    init(modelName: String, configuration: URLSessionConfiguration = .default) {
        self.modelName = modelName
        session = URLSession(configuration: configuration)
        filename = "\(modelName).bin"
        modelURL = cacheDirectory.appending(path: filename)
    }
    
    func resume() {
        if !FileManager.default.fileExists(atPath: cacheDirectory.absoluteURL.path) {
            try! FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: false)
        }
        
        let destination = modelURL.absoluteURL
        if FileManager.default.fileExists(atPath: destination.path) {
            state = .completed
            return
        }
        
        let request = URLRequest(url: baseURL.appending(path: filename))

        let task = session.downloadTask(with: request) { [weak self] location, response, error in
            if let error = error {
                self?.state = .failed(error)
                return
            }
            if let location = location {
                do {
                    try FileManager.default.moveItem(at: location, to: destination)
                    self?.state = .completed
                } catch {
                    self?.state = .failed(error)
                }
            } else {
                self?.state = .failed(nil)
            }
        }
        task.resume()
        self.task = task
    }
}

import CoreFoundation

func serverCallback(local: CFMessagePort?, msgid: Int32, data: CFData?, info: UnsafeMutableRawPointer?) -> Unmanaged<CFData>? {
    let server = Unmanaged<IPCServer>.fromOpaque(info!).takeUnretainedValue()
    let responseData = server.delegate?.handleMessageWithID(msgid, data: data! as Data)
    if let responseData = responseData as? NSData,
       let cfdata = CFDataCreate(nil, responseData.bytes, responseData.length) {
        return Unmanaged.passRetained(cfdata)
    } else {
        return nil
    }
}

public protocol IPCServerDelegate: AnyObject {
    func handleMessageWithID(_ msgid: Int32, data: Data) -> Data?
}

open class NSCodingHandler<RequestObject>: NSObject, IPCServerDelegate {
    public typealias Handler = (RequestObject?) -> Encodable?
    
    public let messageID: Int32
    public var handler: Handler?
    
    public init(respondsTo id: any RawRepresentable<Int32>, _ handler: Handler? = nil) {
        self.messageID = id.rawValue
        self.handler = handler
    }
    
    public func handleMessageWithID(_ msgid: Int32, data: Data) -> Data? {
        let object = NSKeyedUnarchiver.unarchiveObject(with: data) as? RequestObject
        if let handler = handler, let result = handler(object) {
            return try? NSKeyedArchiver.archivedData(withRootObject: result, requiringSecureCoding: false)
        } else {
            return nil
        }
    }
}

open class JSONHandler<RequestObject: Decodable>: IPCServerDelegate {
    public typealias Handler = (RequestObject?) -> Encodable?
    
    public let messageID: Int32
    public var handler: Handler?
    
    public init(respondsTo id: any RawRepresentable<Int32>, _ handler: Handler? = nil) {
        self.messageID = id.rawValue
        self.handler = handler
    }
    
    public func handleMessageWithID(_ msgid: Int32, data: Data) -> Data? {
        let object = try? JSONDecoder().decode(RequestObject.self, from: data)
        if let object = object, let handler = handler, let result = handler(object) {
            return try? NSKeyedArchiver.archivedData(withRootObject: result, requiringSecureCoding: false)
        } else {
            return nil
        }
    }
}

public class IPCServer: NSObject {
    public weak var delegate: IPCServerDelegate?
    
    /// Create the local message port then register an input source for it
    public func addSourceForNewLocalMessagePort(name: String, toRunLoop runLoop: CFRunLoop!) {
        if let messagePort = createMessagePort(name: name) {
            addSource(messagePort: messagePort, toRunLoop: runLoop)
        }
    }
    
    /// Create a local message port with the specified name
    ///
    /// Incoming messages will be routed to this object's handleMessageWithID(,data:) method.
    func createMessagePort(name: String) -> CFMessagePort? {
        var context = CFMessagePortContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil)
        var shouldFreeInfo: DarwinBoolean = false
        
        return CFMessagePortCreateLocal(
            nil,
            name as CFString,
            serverCallback,
            &context,
            &shouldFreeInfo)
    }
    
    /// Create an input source for the specified message port and add it to the specified run loop
    func addSource(messagePort: CFMessagePort, toRunLoop runLoop: CFRunLoop) {
        let source = CFMessagePortCreateRunLoopSource(nil, messagePort, 0)
        CFRunLoopAddSource(runLoop, source, CFRunLoopMode.commonModes)
    }
}

import CoreFoundation
import UserNotifications

public enum IPCClientError: Error {
    case createRemoteFailure
    case sendRequestFailure(Int32)
}

public class IPCClient {
    let remote: CFMessagePort
    
    public init(messagePortName: String) throws {
        if let remote = CFMessagePortCreateRemote(nil, messagePortName as CFString) {
            self.remote = remote
        } else {
            throw IPCClientError.createRemoteFailure
        }
    }
    
    public func sendRequest(msgid: Int32, data: Data) throws -> Data? {
        var responseData: Unmanaged<CFData>? = nil
        
        let result = CFMessagePortSendRequest(
            remote,
            msgid,
            data as CFData,
            1.0, // sendTimeout
            1.0, // rcvTimeout
            CFRunLoopMode.defaultMode.rawValue,
            &responseData)
        
        if result == kCFMessagePortSuccess {
            return responseData?.takeRetainedValue() as Data?
        } else {
            throw IPCClientError.sendRequestFailure(result)
        }
    }
}

public extension IPCClient {
    func encode(_ object: Encodable) throws -> Data {
        return try PropertyListEncoder().encode(object)
    }
    
    func encode(_ object: NSCoding) throws -> Data {
        return try NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: true)
    }
    
    func decode<T: Decodable>(_ data: Data) throws -> T {
        return try PropertyListDecoder().decode(T.self, from: data)
    }
    
    func decode<T>(_ data: Data) throws -> T? where T: NSObject, T: NSCoding {
        return try NSKeyedUnarchiver.unarchivedObject(ofClass: T.self, from: data)
    }
    
    func sendMessage(id: any RawRepresentable<Int32>, withObject object: NSCoding) throws {
        _ = try sendRequest(msgid: id.rawValue, data: encode(object))
    }
    
    func sendMessage<T: Decodable>(id: any RawRepresentable<Int32>, withObject object: NSCoding) throws -> T? {
        guard let resultData = try sendRequest(msgid: id.rawValue, data: encode(object)) else {
            return nil
        }
        return try decode(resultData)
    }
}

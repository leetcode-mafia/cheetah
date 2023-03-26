// ExtensionHelper is invoked by the browser extension and killed automatically
// when all tabs using the extension are closed. It relays incoming messages to
// the IPCServer running in the main app.

import Cocoa
import CheetahIPC

let client = try? IPCClient(messagePortName: MessagePortName.browserExtensionServer.rawValue)
guard let client = client else {
    exit(1)
}

let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase

let stdin = FileHandle.standardInput
_ = enableRawMode(fileHandle: stdin)

func handleMessage() throws {
    // Read length
    guard let size = stdin.readData(ofLength: 4).value(ofType: UInt32.self, at: 0, convertEndian: true) else {
        return
    }
    
    // Read message
    let data = stdin.readData(ofLength: Int(size))
    _ = try client.sendRequest(msgid: IPCMessage.browserExtensionMessage.rawValue, data: data)
    
    //TODO: send response (UInt32 length followed by JSON message)
}

while true {
    do {
        try handleMessage()
    } catch {
        exit(1)
    }
}

// https://forums.swift.org/t/how-to-read-uint32-from-a-data/59431/11
extension Data {
    subscript<T: BinaryInteger>(at offset: Int, convertEndian convertEndian: Bool = false) -> T? {
        value(ofType: T.self, at: offset, convertEndian: convertEndian)
    }
    
    func value<T: BinaryInteger>(ofType: T.Type, at offset: Int, convertEndian: Bool = false) -> T? {
        let right = offset &+ MemoryLayout<T>.size
        guard offset >= 0 && right > offset && right <= count else {
            return nil
        }
        let bytes = self[offset ..< right]
        if convertEndian {
            return bytes.reversed().reduce(0) { T($0) << 8 + T($1) }
        } else {
            return bytes.reduce(0) { T($0) << 8 + T($1) }
        }
    }
}

// see https://stackoverflow.com/a/24335355/669586
func initStruct<S>() -> S {
    let struct_pointer = UnsafeMutablePointer<S>.allocate(capacity: 1)
    let struct_memory = struct_pointer.pointee
    struct_pointer.deallocate()
    return struct_memory
}

func enableRawMode(fileHandle: FileHandle) -> termios {
    var raw: termios = initStruct()
    tcgetattr(fileHandle.fileDescriptor, &raw)

    let original = raw

    raw.c_lflag &= ~(UInt(ECHO | ICANON))
    tcsetattr(fileHandle.fileDescriptor, TCSAFLUSH, &raw);

    return original
}

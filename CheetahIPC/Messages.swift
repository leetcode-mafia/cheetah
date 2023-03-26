import Foundation
import SwiftUI

public enum MessagePortName: String {
    case browserExtensionServer = "org.phrack.Cheetah.BrowserExtensionServer"
}

public enum IPCMessage: Int32 {
    case browserExtensionMessage = 1
}

public struct BrowserExtensionMessage: Codable {
    public var mode: String
    public var files = [String: String]()
    public var logs = [String: String]()
    public var navigationStart: Int
}

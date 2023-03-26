import AVFoundation

public struct Segment {
    let text: String
    let t0: Int64
    let t1: Int64
}

public typealias OrderedSegments = [Segment]

public extension OrderedSegments {
    var text: any StringProtocol {
        map { $0.text }.joined()
    }
}

public class WhisperStream: Thread {
    let waiter = DispatchGroup()
    
    @Published public private(set) var segments = OrderedSegments()
    @Published public private(set) var alive = true
    
    let model: URL
    let device: CaptureDevice?
    let window: TimeInterval
    
    public init(model: URL, device: CaptureDevice? = nil, window: TimeInterval = 300) {
        self.model = model
        self.device = device
        self.window = window
        super.init()
    }
    
    public override func start() {
        waiter.enter()
        super.start()
    }
    
    public override func main() {
        task()
        waiter.leave()
    }
    
    public func join() {
        waiter.wait()
    }
    
    func task() {
        model.path.withCString { modelCStr in
            var params = stream_default_params()
            params.model = modelCStr
            
            if let device = device {
                params.capture_id = device.id
            }
            
            let ctx = stream_init(params)
            if ctx == nil {
                return
            }
            
            while !self.isCancelled {
                let errno = stream_run(ctx, Unmanaged.passUnretained(self).toOpaque()) {
                    return Unmanaged<WhisperStream>.fromOpaque($3!).takeUnretainedValue().callback(
                        text: $0 != nil ? String(cString: $0!) : nil,
                        t0: $1,
                        t1: $2
                    )
                }
                if errno != 0 {
                    break
                }
            }
            
            stream_free(ctx)
            alive = false
        }
    }
    
    func callback(text: String?, t0: Int64, t1: Int64) -> Int32 {
        if segments.isEmpty || text == nil {
            segments.append(Segment(text: "", t0: -1, t1: -1))
        }
        if let text = text {
            segments[segments.count - 1] = Segment(text: text, t0: t0, t1: t1)
        }
        
        var k = 0
        for segment in segments {
            if let last = segments.last, last.t0 - segment.t0 > Int64(window * 1000) {
                k += 1
            }
        }
        segments.removeFirst(k)
        
        return 0
    }
}

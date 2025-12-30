import Foundation
import flutter_native_bridge

/// Example service demonstrating stream support for EventChannel.
/// Emits counter values every second.
class CounterService: NSObject {
    private var timer: Timer?
    private var counter = 0
    private var activeSink: StreamSink?

    /// Stream that emits incrementing counter values every second.
    /// Methods with StreamSink parameter are automatically treated as streams.
    @objc func counterUpdatesWithSink(_ sink: StreamSink) {
        activeSink = sink
        counter = 0

        // Start timer on main thread
        DispatchQueue.main.async { [weak self] in
            self?.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.activeSink?.success([
                    "count": self.counter,
                    "timestamp": Date().timeIntervalSince1970 * 1000
                ])
                self.counter += 1
            }
        }
    }

    /// Stop the counter stream.
    @objc func stopCounter() {
        timer?.invalidate()
        timer = nil
        counter = 0
        activeSink = nil
    }
}

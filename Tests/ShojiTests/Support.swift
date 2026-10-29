import Foundation
@testable import Shoji

extension ThreadStore {
    /// One status signal, as the socket or a terminal delivers it.
    func send(_ signal: StatusEvent.Signal, to id: UUID, at time: Date = .now) {
        apply(StatusEvent(threadId: id, signal: signal), at: time)
    }
}

/// Threads titled "0", "1", … in shelf order, for tests that only care which is which.
func numberedThreads(_ count: Int) -> (threads: [ShojiThread], ids: [UUID]) {
    let threads = (0..<count).map { ShojiThread(title: "\($0)", order: $0) }
    return (threads, threads.map(\.id))
}

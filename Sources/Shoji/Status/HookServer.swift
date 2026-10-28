import Foundation

/// Unix-socket listener for `shoji-hook`. A connection carries one message, read until the client closes.
final class HookServer: Sendable {
    let path: String
    private let source: any DispatchSourceRead

    init(path: String, onMessage: @escaping @Sendable (Data) -> Void) throws {
        self.path = path
        let listener = try Self.listen(at: path)
        source = DispatchSource.makeReadSource(fileDescriptor: listener, queue: DispatchQueue(label: "shoji.hook-server"))
        source.setEventHandler { Self.acceptPending(on: listener, onMessage) }
        source.setCancelHandler {
            close(listener)
            unlink(path)
        }
        source.resume()
    }

    deinit {
        source.cancel()
    }

    static var defaultPath: String {
        let directory = URL.applicationSupportDirectory.appending(path: "Shoji", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "hook.sock").path(percentEncoded: false)
    }

    private static func listen(at path: String) throws -> Int32 {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8)
        guard pathBytes.count < MemoryLayout.size(ofValue: address.sun_path) else {
            throw POSIXError(.ENAMETOOLONG)
        }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: pathBytes) }

        unlink(path)
        let listener = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listener >= 0 else { throw POSIXError.current }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listener, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0, Darwin.listen(listener, 32) == 0, fcntl(listener, F_SETFL, O_NONBLOCK) == 0 else {
            let error = POSIXError.current
            close(listener)
            throw error
        }
        chmod(path, 0o600)
        return listener
    }

    private static func acceptPending(on listener: Int32, _ onMessage: (Data) -> Void) {
        while true {
            let client = accept(listener, nil, nil)
            guard client >= 0 else { return }
            // Accepted sockets inherit O_NONBLOCK on Darwin; reads below must block (with a timeout).
            _ = fcntl(client, F_SETFL, fcntl(client, F_GETFL) & ~O_NONBLOCK)
            let message = readToEnd(client)
            if !message.isEmpty { onMessage(message) }
            close(client)
        }
    }

    private static func readToEnd(_ client: Int32, limit: Int = 1 << 20) -> Data {
        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 16 * 1024)
        while data.count < limit {
            let count = read(client, &buffer, buffer.count)
            guard count > 0 else { break }
            data.append(contentsOf: buffer[..<count])
        }
        return data
    }
}

private extension POSIXError {
    static var current: POSIXError { POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
}

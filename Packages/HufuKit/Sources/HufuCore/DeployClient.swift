import Foundation

/// The transport that carries typed deploy messages between processes. Production uses
/// `DistributedNotificationCenter`; tests use an in-memory transport.
public protocol DeployTransport: Sendable {
    func post(_ request: DeployRequest)
    func observeProgress(
        for requestID: String,
        _ handler: @escaping @MainActor (DeployProgress) -> Void
    ) -> DeployObservation
    func observeReply(
        for requestID: String,
        _ handler: @escaping @MainActor (DeployReply) -> Void
    ) -> DeployObservation
    func removeObserver(_ observation: DeployObservation)
}

/// Type-erased observer handle. The transport owns its concrete token.
public final class DeployObservation: @unchecked Sendable {
    public let token: AnyObject
    public init(_ token: AnyObject) { self.token = token }
}

/// Sends one typed request and waits for the matching reply, with the shared timeout.
@MainActor
public final class DeployClient {
    private let transport: any DeployTransport
    private let timeout: Duration

    public init(
        transport: any DeployTransport = DistributedDeployTransport(),
        timeout: Duration = DeployProtocol.timeout
    ) {
        self.transport = transport
        self.timeout = timeout
    }

    public func send(
        _ request: DeployRequest,
        progress: @escaping @MainActor (DeployProgress) -> Void = { _ in }
    ) async -> DeployReply? {
        let progressObservation = transport.observeProgress(for: request.id) { update in
            progress(update)
        }
        defer { transport.removeObserver(progressObservation) }

        let transport = self.transport
        let stream = AsyncStream<DeployReply> { continuation in
            let replyObservation = transport.observeReply(for: request.id) { reply in
                continuation.yield(reply)
                continuation.finish()
            }
            continuation.onTermination = { _ in
                transport.removeObserver(replyObservation)
            }
        }

        transport.post(request)
        let timeout = self.timeout
        return await withTaskGroup(of: DeployReply?.self) { group in
            group.addTask { for await reply in stream { return reply }; return nil }
            group.addTask { try? await Task.sleep(for: timeout); return nil }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}

/// Production adapter over `DistributedNotificationCenter`.
public struct DistributedDeployTransport: DeployTransport {
    public init() {}

    public func post(_ request: DeployRequest) {
        DistributedNotificationCenter.default().postNotificationName(
            DeployRequest.notification, object: nil, userInfo: request.userInfo, deliverImmediately: true
        )
    }

    public func observeProgress(
        for requestID: String,
        _ handler: @escaping @MainActor (DeployProgress) -> Void
    ) -> DeployObservation {
        let box = HandlerBox(handler)
        let token = DistributedNotificationCenter.default().addObserver(
            forName: DeployProgress.notification, object: nil, queue: .main
        ) { note in
            guard let update = DeployProgress(userInfo: note.userInfo), update.request == requestID else { return }
            MainActor.assumeIsolated { box.value(update) }
        }
        return DeployObservation(token)
    }

    public func observeReply(
        for requestID: String,
        _ handler: @escaping @MainActor (DeployReply) -> Void
    ) -> DeployObservation {
        let box = HandlerBox(handler)
        let token = DistributedNotificationCenter.default().addObserver(
            forName: DeployReply.notification, object: nil, queue: .main
        ) { note in
            guard let reply = DeployReply(userInfo: note.userInfo), reply.request == requestID else { return }
            MainActor.assumeIsolated { box.value(reply) }
        }
        return DeployObservation(token)
    }

    public func removeObserver(_ observation: DeployObservation) {
        DistributedNotificationCenter.default().removeObserver(observation.token)
    }
}

/// The notification callback is `@Sendable`, while the handler is main-actor bound.
private final class HandlerBox<Value>: @unchecked Sendable {
    let value: Value
    init(_ value: Value) { self.value = value }
}

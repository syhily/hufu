import Foundation
import Testing
@testable import HufuCore

@MainActor
struct DeployClientTests {
    final class ImmediateTransport: DeployTransport, @unchecked Sendable {
        nonisolated(unsafe) var reply: DeployReply?
        nonisolated(unsafe) var progress: DeployProgress?
        nonisolated(unsafe) var progressHandler: (@MainActor (DeployProgress) -> Void)?
        nonisolated(unsafe) var replyHandler: (@MainActor (DeployReply) -> Void)?
        nonisolated(unsafe) var posted: [DeployRequest] = []

        func post(_ request: DeployRequest) {
            posted.append(request)
            if let progress { MainActor.assumeIsolated { progressHandler?(progress) } }
            if let reply { MainActor.assumeIsolated { replyHandler?(reply) } }
        }

        func observeProgress(
            for requestID: String,
            _ handler: @escaping @MainActor (DeployProgress) -> Void
        ) -> DeployObservation {
            progressHandler = handler
            return DeployObservation(NSObject())
        }

        func observeReply(
            for requestID: String,
            _ handler: @escaping @MainActor (DeployReply) -> Void
        ) -> DeployObservation {
            replyHandler = handler
            return DeployObservation(NSObject())
        }

        func removeObserver(_ observation: DeployObservation) {}
    }

    final class SilentTransport: DeployTransport, @unchecked Sendable {
        nonisolated(unsafe) var posted: [DeployRequest] = []
        func post(_ request: DeployRequest) { posted.append(request) }
        func observeProgress(
            for requestID: String,
            _ handler: @escaping @MainActor (DeployProgress) -> Void
        ) -> DeployObservation { DeployObservation(NSObject()) }
        func observeReply(
            for requestID: String,
            _ handler: @escaping @MainActor (DeployReply) -> Void
        ) -> DeployObservation { DeployObservation(NSObject()) }
        func removeObserver(_ observation: DeployObservation) {}
    }

    @Test func returnsTheMatchingReplyAndReportsProgress() async {
        let transport = ImmediateTransport()
        transport.progress = DeployProgress(request: "r", stage: "schemas", total: 2)
        transport.reply = DeployReply(request: "r", ok: true, log: "/tmp/log")
        let client = DeployClient(transport: transport)
        var updates: [DeployProgress] = []

        let reply = await client.send(DeployRequest(id: "r", mode: .auto)) { updates.append($0) }
        #expect(reply?.ok == true)
        #expect(reply?.log == "/tmp/log")
        #expect(updates.map(\.stage) == ["schemas"])
        #expect(transport.posted.map(\.id) == ["r"])
    }

    @Test func timesOutWithoutAReply() async {
        let transport = SilentTransport()
        let client = DeployClient(transport: transport, timeout: .milliseconds(20))
        let reply = await client.send(DeployRequest(id: "r", mode: .full))
        #expect(reply == nil)
        #expect(transport.posted.count == 1)
    }
}

import Foundation
import Testing
@testable import HufuCore

struct DeployProtocolTests {
    @Test func requestRoundTripsThroughUserInfo() throws {
        let request = DeployRequest(id: "r1", mode: .import)
        let decoded = try #require(DeployRequest(userInfo: request.userInfo))
        #expect(decoded == request)
        #expect(DeployRequest(userInfo: ["request": "r1", "mode": "nonsense"]) == nil)
        #expect(DeployRequest(userInfo: nil) == nil)
    }

    @Test func progressRoundTripsAndKeepsTheRequest() throws {
        let progress = DeployProgress(request: "r1", stage: "schemas", total: 3)
        let decoded = try #require(DeployProgress(userInfo: progress.userInfo))
        #expect(decoded == progress)
        #expect(DeployProgress(userInfo: ["total": 1]) == nil)
    }

    @Test func replyRoundTripsWithMessageAndLog() throws {
        let reply = DeployReply(request: "r1", ok: false, message: "boom", log: "/tmp/log")
        let decoded = try #require(DeployReply(userInfo: reply.userInfo))
        #expect(decoded == reply)
        #expect(DeployReply(userInfo: ["request": "r1"]) == nil)
    }

    @Test func deploySuccessNeedsEverySchemaOutput() throws {
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("hufu-verify-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try """
        schema_list:
          - schema: tigress
          - schema: demo
        """.write(to: staging.appendingPathComponent("default.yaml"), atomically: true, encoding: .utf8)
        try "x".write(to: staging.appendingPathComponent("tigress.schema.yaml"), atomically: true, encoding: .utf8)

        #expect(DeployVerification.missingSchemas(stagingDir: staging) == ["demo"])
        try "x".write(to: staging.appendingPathComponent("demo.schema.yaml"), atomically: true, encoding: .utf8)
        #expect(DeployVerification.missingSchemas(stagingDir: staging).isEmpty)
    }
}

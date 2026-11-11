import Foundation
@testable import Petrel
import Testing

// The video upload flow: service token from the PDS, upload to the video
// service, poll the processing job. One stub server plays both services.

private let videoBlob: BskyJSON = [
    "$type": "blob",
    "ref": ["$link": "bafkreiclp443lavogvhj3d2ob2cxbfuscni2k5jk7bebjzg7khl3esabwq"],
    "mimeType": "video/mp4",
    "size": 4,
]

private func job(_ state: String, blob: Bool = false, error: String? = nil) -> BskyJSON {
    var status: BskyJSON = ["jobId": "job-1", "did": "did:plc:alice", "state": .string(state)]
    if blob { status["blob"] = videoBlob }
    if let error {
        status["error"] = .string(error)
        status["message"] = "Video must be under 3 minutes"
    }
    return status
}

/// A video service that answers the upload with `uploadResponse` and each poll
/// with the next of `polls` (repeating the last).
private func videoServer(uploadResponse: BskyStubResponse, polls: [BskyJSON]) -> BskyStubServer {
    let pollCount = BskyTestCounter()
    return BskyStubServer { request in
        switch request.nsid {
        case "com.atproto.server.getServiceAuth":
            return .json(["token": "service-token"])
        case "app.bsky.video.uploadVideo":
            return uploadResponse
        case "app.bsky.video.getJobStatus":
            let index = min(pollCount.increment() - 1, polls.count - 1)
            return .json(["jobStatus": polls[index]])
        default:
            return .error(501, "MethodNotImplemented")
        }
    }
}

@Suite("BskyAgent video upload")
struct BskyAgentVideoTests {
    private let bytes = Data([0x00, 0x00, 0x00, 0x18])

    @Test("uploads with a service token, then polls until the blob is ready")
    func uploadAndPoll() async throws {
        let server = videoServer(
            uploadResponse: .json(job("JOB_STATE_CREATED")),
            polls: [job("JOB_STATE_ENCODING"), job("JOB_STATE_COMPLETED", blob: true)]
        )
        let agent = try await server.makeAgent()
        let states = BskyTestRecorder()

        let blob = try await agent.uploadVideo(
            bytes,
            name: "landing.mp4",
            service: server.baseURL,
            pollInterval: .milliseconds(1),
            onProgress: { states.append($0.state) }
        )

        #expect(blob.mimeType == "video/mp4")
        #expect(states.values == ["JOB_STATE_CREATED", "JOB_STATE_ENCODING", "JOB_STATE_COMPLETED"])

        let requests = server.requests
        #expect(requests.map(\.nsid) == [
            "com.atproto.server.getServiceAuth", "app.bsky.video.uploadVideo",
            "app.bsky.video.getJobStatus", "app.bsky.video.getJobStatus",
        ])

        // The token is scoped to one blob upload on the account's PDS and is short-lived.
        let auth = requests[0]
        #expect(auth.query("aud") == ["did:web:127.0.0.1%3A\(server.port)"])
        #expect(auth.query("lxm") == ["com.atproto.repo.uploadBlob"])
        let expiry = try #require(auth.query("exp").first.flatMap(Int.init))
        let now = Int(Date().timeIntervalSince1970)
        #expect(expiry > now && expiry <= now + 30 * 60)

        // The bytes go to the video service with that token, not through the PDS proxy.
        let upload = requests[1]
        #expect(upload.method == "POST")
        #expect(upload.query("did") == ["did:plc:alice"])
        #expect(upload.query("name") == ["landing.mp4"])
        #expect(upload.header("Authorization") == "Bearer service-token")
        #expect(upload.header("Content-Type") == "video/mp4")
        #expect(upload.header("atproto-proxy") == nil)
        #expect(upload.body == bytes)

        #expect(requests[2].method == "GET")
        #expect(requests[2].query("jobId") == ["job-1"])
        #expect(requests[2].header("atproto-proxy") == nil)
    }

    @Test("accepts the lexicon's wrapped upload response and an explicit PDS DID")
    func wrappedResponse() async throws {
        let server = videoServer(
            uploadResponse: .json(["jobStatus": job("JOB_STATE_COMPLETED", blob: true)]),
            polls: []
        )
        let agent = try await server.makeAgent()
        let blob = try await agent.uploadVideo(
            bytes, service: server.baseURL, pdsDID: DID(didString: "did:web:pds.example.com")
        )
        #expect(blob.size == 4)
        #expect(server.requests[0].query("aud") == ["did:web:pds.example.com"])
        #expect(server.requests(to: "app.bsky.video.getJobStatus").isEmpty)
    }

    @Test("a video the service already has resumes from the existing job")
    func alreadyExists() async throws {
        let server = videoServer(
            uploadResponse: .json(
                ["error": "already_exists", "jobId": "job-1", "did": "did:plc:alice", "state": "JOB_STATE_COMPLETED"],
                status: 409
            ),
            polls: [job("JOB_STATE_COMPLETED", blob: true)]
        )
        let agent = try await server.makeAgent()
        let blob = try await agent.uploadVideo(bytes, service: server.baseURL, pollInterval: .milliseconds(1))
        #expect(blob.mimeType == "video/mp4")
    }

    @Test("a failed job throws videoProcessingFailed with the service's reason")
    func failedJob() async throws {
        let server = videoServer(
            uploadResponse: .json(job("JOB_STATE_CREATED")),
            polls: [job("JOB_STATE_FAILED", error: "VideoTooLong")]
        )
        let agent = try await server.makeAgent()
        await #expect(throws: BskyAgentError.videoProcessingFailed(
            jobId: "job-1", error: "VideoTooLong", message: "Video must be under 3 minutes"
        )) {
            try await agent.uploadVideo(bytes, service: server.baseURL, pollInterval: .milliseconds(1))
        }
    }

    @Test("a job that never finishes throws videoProcessingTimedOut")
    func timeout() async throws {
        let server = videoServer(uploadResponse: .json(job("JOB_STATE_CREATED")), polls: [job("JOB_STATE_ENCODING")])
        let agent = try await server.makeAgent()
        await #expect(throws: BskyAgentError.videoProcessingTimedOut(jobId: "job-1")) {
            try await agent.uploadVideo(
                bytes, service: server.baseURL, pollInterval: .milliseconds(2), timeout: .milliseconds(30)
            )
        }
    }

    @Test("a rejected upload surfaces the service's error; no session means no requests")
    func rejectedUpload() async throws {
        let server = videoServer(uploadResponse: .error(400, "InvalidMimeType", "Unsupported video type"), polls: [])
        let agent = try await server.makeAgent()
        await #expect(throws: BskyAgentError.xrpc(
            nsid: "app.bsky.video.uploadVideo", status: 400, error: "InvalidMimeType", message: "Unsupported video type"
        )) {
            try await agent.uploadVideo(bytes, service: server.baseURL)
        }

        let signedOut = try await server.makeAgent(did: nil)
        let before = server.requests.count
        await #expect(throws: BskyAgentError.notAuthenticated) {
            try await signedOut.uploadVideo(bytes, service: server.baseURL)
        }
        #expect(server.requests.count == before)
    }
}

import Foundation

public extension BskyAgent {
    /// The Bluesky video service.
    static let videoServiceURL = URL(staticString: "https://video.bsky.app")

    /// Uploads a video through the video service and waits until it has been processed.
    ///
    /// Video is not uploaded to the PDS like an image. The client asks its PDS
    /// for a short-lived service token that authorizes one blob upload, sends
    /// the bytes to the video service, and polls the processing job until the
    /// service hands back the blob to embed.
    ///
    /// **Video metadata is not removed.** The file is uploaded as given;
    /// container metadata such as location or device tags stays in what is
    /// sent to the video service. Remove it before calling this method if that
    /// matters for your users.
    ///
    /// ```swift
    /// let video = try await client.bsky.uploadVideo(data, name: "landing.mp4")
    /// try await client.bsky.post("Landing", embed: .video(video, alt: "A petrel landing"))
    /// ```
    ///
    /// - Parameters:
    ///   - data: The video file.
    ///   - mimeType: The media type of the file.
    ///   - name: A file name for the upload, with an extension the service recognises.
    ///   - service: The video service; defaults to Bluesky's.
    ///   - pdsDID: The DID of the account's PDS, the audience of the upload
    ///     token. Defaults to `did:web:` plus the host this agent sends requests to.
    ///   - pollInterval: How long to wait between checks of the processing job.
    ///   - timeout: How long to wait for processing before giving up.
    ///   - onProgress: Called with each job status received.
    /// - Returns: The processed video blob, ready for ``PostEmbed/video(_:alt:aspectRatio:captions:)``.
    /// - Throws: ``BskyAgentError/videoProcessingFailed(jobId:error:message:)``
    ///   when the service rejects the video, and
    ///   ``BskyAgentError/videoProcessingTimedOut(jobId:)`` when it does not finish in time.
    func uploadVideo(
        _ data: Data,
        mimeType: String = "video/mp4",
        name: String = "video.mp4",
        service: URL = BskyAgent.videoServiceURL,
        pdsDID: DID? = nil,
        pollInterval: Duration = .seconds(1),
        timeout: Duration = .seconds(600),
        onProgress: (@Sendable (AppBskyVideoDefs.JobStatus) -> Void)? = nil
    ) async throws -> Blob {
        let did = try await did()
        let audience: String
        if let pdsDID {
            audience = pdsDID.didString()
        } else {
            let base = await networkService.baseURL
            guard let host = base.host else {
                throw BskyAgentError.invalidInput("Cannot derive the PDS DID; pass pdsDID")
            }
            audience = "did:web:" + (base.port.map { "\(host)%3A\($0)" } ?? host)
        }

        // 1. A service token that lets the video service upload one blob on the account's behalf.
        let authNSID = "com.atproto.server.getServiceAuth"
        let expiry = Int(Date().timeIntervalSince1970) + 30 * 60
        let auth = try await xrpcQuery(authNSID, query: [
            URLQueryItem(name: "aud", value: audience),
            URLQueryItem(name: "lxm", value: "com.atproto.repo.uploadBlob"),
            URLQueryItem(name: "exp", value: String(expiry)),
        ])
        guard let token = try auth.json(nsid: authNSID)["token"]?.stringValue else {
            throw BskyAgentError.invalidResponse(nsid: authNSID, reason: "Missing token")
        }

        // 2. The upload itself, sent straight to the video service.
        let uploadNSID = "app.bsky.video.uploadVideo"
        let upload = try await xrpcAnyStatus(
            "POST",
            uploadNSID,
            query: [
                URLQueryItem(name: "did", value: did.didString()),
                URLQueryItem(name: "name", value: name),
            ],
            body: data,
            contentType: mimeType,
            options: BskyCallOptions(headers: ["Authorization": "Bearer \(token)"]),
            service: service
        )
        // A video the service has already processed answers 409 with the
        // existing job; anything else unsuccessful is an error.
        let uploadJSON = try? BskyJSON.parse(upload.data)
        let reportsExistingJob = upload.status == 409 && uploadJSON?["jobId"]?.stringValue != nil
        guard (200 ... 299).contains(upload.status) || reportsExistingJob else {
            throw upload.error(nsid: uploadNSID)
        }
        guard let uploadJSON else {
            throw BskyAgentError.invalidResponse(nsid: uploadNSID, reason: "Body is not JSON")
        }
        // The service answers with the job status itself; the lexicon wraps it in `jobStatus`.
        let first = uploadJSON["jobStatus"] ?? uploadJSON
        guard let jobId = first["jobId"]?.stringValue else {
            throw BskyAgentError.invalidResponse(nsid: uploadNSID, reason: "Missing jobId")
        }
        if let blob = try Self.finishedBlob(first, jobId: jobId, onProgress: onProgress) {
            return blob
        }

        // 3. Wait for processing.
        let statusNSID = "app.bsky.video.getJobStatus"
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            try await Task.sleep(for: pollInterval)
            let status = try await xrpcQuery(
                statusNSID,
                query: [URLQueryItem(name: "jobId", value: jobId)],
                service: service
            )
            guard let job = try status.json(nsid: statusNSID)["jobStatus"] else {
                throw BskyAgentError.invalidResponse(nsid: statusNSID, reason: "Missing jobStatus")
            }
            if let blob = try Self.finishedBlob(job, jobId: jobId, onProgress: onProgress) {
                return blob
            }
        }
        throw BskyAgentError.videoProcessingTimedOut(jobId: jobId)
    }

    /// The blob of a completed job, `nil` while it is still running; throws when it failed.
    private static func finishedBlob(
        _ job: BskyJSON,
        jobId: String,
        onProgress: (@Sendable (AppBskyVideoDefs.JobStatus) -> Void)?
    ) throws -> Blob? {
        if let onProgress, let status = try? job.decoded(as: AppBskyVideoDefs.JobStatus.self) {
            onProgress(status)
        }
        if let blob = job["blob"], let decoded = try? blob.decoded(as: Blob.self) {
            return decoded
        }
        if job["state"]?.stringValue == "JOB_STATE_FAILED" {
            throw BskyAgentError.videoProcessingFailed(
                jobId: jobId,
                error: job["error"]?.stringValue,
                message: job["message"]?.stringValue
            )
        }
        return nil
    }
}

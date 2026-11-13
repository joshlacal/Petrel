import Crypto
import Foundation
import PetrelCrypto

extension OAuthAuthorizationServer {
    // `__Host-` cookies must be Secure with Path=/ and no Domain attribute, so
    // a sibling subdomain cannot set one for this origin (it could set a
    // `__Secure-` cookie with a parent-domain Domain). Only the exact name is
    // read, so a cookie without the prefix is ignored.
    private var flowCookiePrefix: String { configuration.secureCookies ? "__Host-oauth-flow" : "oauth-flow" }

    /// Each authorization in progress has its own flow cookie, named after a
    /// digest of its CSRF token, so two authorizations in one browser (two
    /// tabs, two applications) do not overwrite each other. A form post names
    /// its flow by the CSRF token it carries; the cookie still has to match.
    private func flowCookieName(csrf: String) -> String {
        let digest = SHA256.hash(data: Data(csrf.utf8)).prefix(8)
        return flowCookiePrefix + "-" + digest.map { String(format: "%02x", $0) }.joined()
    }
    private var deviceCookieName: String { configuration.secureCookies ? "__Host-oauth-device" : "oauth-device" }

    /// What a form handler has in hand once the flow cookie, CSRF token and
    /// pushed request have all been checked.
    private struct ActiveFlow {
        var flow: OAuthBrowserFlow
        let request: OAuthPushedAuthorizationRequest
        let client: OAuthResolvedClientMetadata
        let fields: [String: String]
        let deviceID: String?
    }

    // MARK: - GET /oauth/authorize

    /// `GET /oauth/authorize?client_id=…&request_uri=…`. Only a pushed request
    /// is accepted; a request that carries its parameters in the query is
    /// refused.
    func handleAuthorize(_ request: OAuthHTTPRequest) async -> OAuthHTTPResponse {
        let now = clock.now()
        let query: [String: String]
        do {
            query = try OAuthForm.parseQuery(request.query)
        } catch {
            return errorPage(400, "Invalid request", "The authorization request is malformed.", request)
        }
        guard let clientID = query["client_id"], let requestURI = query["request_uri"] else {
            return errorPage(
                400, "Invalid request",
                "This server only accepts pushed authorization requests. The application must send client_id and request_uri.",
                request
            )
        }
        guard requestURI.hasPrefix(Self.requestURIPrefix), requestURI.utf8.count == Self.requestURIPrefix.utf8.count + 43
        else {
            return errorPage(400, "Invalid request", "The authorization request is not recognised.", request)
        }
        let pushed: OAuthPushedAuthorizationRequest?
        do {
            pushed = try await store.pushedAuthorizationRequest(
                requestDigest: digest.digest(requestURI, purpose: .requestURI), now: now
            )
        } catch {
            return errorPage(503, "Try again", "The server cannot answer right now.", request)
        }
        // The client is not yet verified, so nothing here may redirect to it.
        guard let pushed, pushed.binding.clientID == clientID else {
            return errorPage(
                400, "Request expired",
                "This authorization request has expired or was already used. Return to the application and try again.",
                request
            )
        }
        guard let client = await resolveForInterface(clientID, now: now) else {
            return errorPage(400, "Unknown application", "The application could not be verified.", request)
        }

        let flow = flows.begin(requestURI: requestURI, lifetime: min(configuration.requestLifetime, 600), now: now)
        let deviceID = cookie(deviceCookieName, in: request)
        let accounts = await deviceAccounts(deviceID: deviceID, restrictedBy: pushed.loginHint, now: now)
        let page: OAuthInterfacePage = accounts.isEmpty
            ? .signIn(.init(
                client: presentation(client),
                csrfToken: flow.csrfToken,
                formAction: Path.signIn,
                identifierHint: pushed.loginHint,
                errorMessage: nil
            ))
            : .selectAccount(.init(
                client: presentation(client),
                csrfToken: flow.csrfToken,
                formAction: Path.selectAccount,
                accounts: accounts
            ))
        return html(200, page, request, flow: flow, redirectURI: pushed.binding.redirectURI)
    }

    // MARK: - POST forms

    func handleSignIn(_ request: OAuthHTTPRequest) async -> OAuthHTTPResponse {
        let now = clock.now()
        let active: ActiveFlow
        switch await openFlow(request, now: now) {
        case let .success(value): active = value
        case let .failure(response): return response
        }
        guard let identifier = active.fields["identifier"], !identifier.isEmpty, identifier.utf8.count <= 512,
              let password = active.fields["password"], !password.isEmpty, password.utf8.count <= 1024
        else {
            return signInPage(active, request, error: "Enter your handle and password.", status: 400)
        }
        let result: OAuthSignInResult
        do {
            result = try await accounts.signIn(
                identifier: identifier,
                password: password,
                context: OAuthSignInContext(clientID: active.request.binding.clientID, remoteAddress: request.remoteAddress)
            )
        } catch {
            return signInPage(active, request, error: "Sign-in is temporarily unavailable. Try again.", status: 503)
        }
        return await continueAfter(result, active, request, now: now)
    }

    func handleSecondFactor(_ request: OAuthHTTPRequest) async -> OAuthHTTPResponse {
        let now = clock.now()
        let active: ActiveFlow
        switch await openFlow(request, now: now) {
        case let .success(value): active = value
        case let .failure(response): return response
        }
        guard let challenge = active.flow.pendingSecondFactor else {
            return signInPage(active, request, error: "Sign in again to continue.", status: 400)
        }
        guard let code = active.fields["code"], !code.isEmpty, code.utf8.count <= 64 else {
            return secondFactorPage(active, challenge, request, error: "Enter the code.", status: 400)
        }
        let result: OAuthSignInResult
        do {
            result = try await accounts.verifySecondFactor(
                challenge,
                code: code,
                context: OAuthSignInContext(clientID: active.request.binding.clientID, remoteAddress: request.remoteAddress)
            )
        } catch {
            return secondFactorPage(active, challenge, request, error: "Verification is temporarily unavailable.", status: 503)
        }
        switch result {
        case let .authenticated(account) where account.did == challenge.subject:
            return await continueAfter(result, active, request, now: now)
        case .authenticated, .secondFactorRequired, .rejected:
            return secondFactorPage(active, challenge, request, error: "That code was not accepted.", status: 401)
        }
    }

    func handleSelectAccount(_ request: OAuthHTTPRequest) async -> OAuthHTTPResponse {
        let now = clock.now()
        var active: ActiveFlow
        switch await openFlow(request, now: now) {
        case let .success(value): active = value
        case let .failure(response): return response
        }
        guard let chosen = active.fields["account"], !chosen.isEmpty else {
            return signInPage(active, request, error: nil, status: 200)
        }
        let offered = await rememberedAccounts(deviceID: active.deviceID, restrictedBy: active.request.loginHint, now: now)
        guard let (account, authenticatedAt) = offered.first(where: { $0.account.did == chosen }) else {
            return signInPage(active, request, error: "Sign in to continue.", status: 400)
        }
        active.flow.subject = account.did
        active.flow.authenticatedAt = authenticatedAt
        active.flow.pendingSecondFactor = nil
        return await consentPage(active, account: account, request)
    }

    func handleConsent(_ request: OAuthHTTPRequest) async -> OAuthHTTPResponse {
        let now = clock.now()
        let active: ActiveFlow
        switch await openFlow(request, now: now) {
        case let .success(value): active = value
        case let .failure(response): return response
        }
        guard let subject = active.flow.subject, let authenticatedAt = active.flow.authenticatedAt else {
            return signInPage(active, request, error: "Sign in to continue.", status: 400)
        }
        guard let decision = active.fields["decision"], decision == "approve" || decision == "deny" else {
            return errorPage(400, "Invalid request", "Choose to allow or deny the request.", request)
        }
        let account: OAuthAccount?
        do {
            account = try await accounts.account(did: subject)
        } catch {
            return errorPage(503, "Try again", "The server cannot answer right now.", request)
        }
        guard let account else {
            return errorPage(403, "Account unavailable", "This account can no longer be used.", request, clearFlow: active.flow.csrfToken)
        }

        // Consuming the pushed request is the linearization point: one
        // request_uri yields at most one code or one denial.
        let pushed: OAuthPushedAuthorizationRequest
        do {
            pushed = try await store.consumePushedAuthorizationRequest(
                requestDigest: active.request.requestDigest, now: now
            )
        } catch is OAuthStoreError {
            return errorPage(
                400, "Request expired",
                "This authorization request has expired or was already used. Return to the application and try again.",
                request, clearFlow: active.flow.csrfToken
            )
        } catch {
            return errorPage(503, "Try again", "The server cannot answer right now.", request)
        }

        guard decision == "approve" else {
            return redirect(pushed, [("error", "access_denied"), ("error_description", "the user denied the request")], clearing: active.flow.csrfToken)
        }

        let granted: Set<String>
        do {
            granted = try await effectiveGrant(for: pushed.binding.requestedScopes, stage: .pushedAuthorizationRequest).scopes
        } catch is OAuthScopeResolutionError {
            return redirect(pushed, [("error", "invalid_scope"), ("error_description", "a requested permission set could not be resolved")], clearing: active.flow.csrfToken)
        } catch {
            return redirect(pushed, [("error", "temporarily_unavailable")], clearing: active.flow.csrfToken)
        }

        let isConfidential = pushed.binding.clientKey != nil
        let sessionLifetime = isConfidential
            ? configuration.confidentialClientSessionLifetime
            : configuration.publicClientSessionLifetime
        let code = random.opaqueValue()
        let sessionID = UUID()
        let binding = pushed.binding.withGrantedScopes(granted)
        do {
            try await store.storeAuthorizationCode(
                OAuthAuthorizationCode(
                    codeDigest: digest.digest(code, purpose: .authorizationCode),
                    sessionID: sessionID,
                    subject: account.did,
                    binding: binding,
                    codeChallenge: pushed.codeChallenge,
                    expiresAt: now.addingTimeInterval(configuration.codeLifetime)
                ),
                session: OAuthSession(
                    sessionID: sessionID,
                    subject: account.did,
                    binding: binding,
                    createdAt: now,
                    expiresAt: sessionLifetime.map { now.addingTimeInterval($0) }
                ),
                authenticatedAt: authenticatedAt,
                now: now
            )
        } catch OAuthStoreError.revoked {
            // Every session of the account was revoked after this browser
            // authenticated: the approval it carries is no longer the user's.
            return redirect(pushed, [("error", "access_denied"), ("error_description", "the sign-in was revoked")], clearing: active.flow.csrfToken)
        } catch {
            return redirect(pushed, [("error", "server_error")], clearing: active.flow.csrfToken)
        }
        return redirect(pushed, [("code", code)], clearing: active.flow.csrfToken)
    }

    // MARK: - Flow plumbing

    private enum FlowOutcome {
        case success(ActiveFlow)
        case failure(OAuthHTTPResponse)
    }

    /// Checks everything a form post must carry: a form body, same-origin
    /// provenance, a valid flow cookie, the matching CSRF token and a pushed
    /// request that is still live.
    private func openFlow(_ request: OAuthHTTPRequest, now: Date) async -> FlowOutcome {
        guard OAuthForm.isFormContentType(request.headers),
              let fields = try? OAuthForm.parse(request.body, maximumBytes: 16 * 1024)
        else {
            return .failure(errorPage(400, "Invalid request", "The form could not be read.", request))
        }
        // Browsers send Origin on every cross-origin POST; a value that is not
        // this server is a forged cross-site submission.
        if let origin = request.headers.single("Origin"), origin != issuer {
            return .failure(errorPage(403, "Invalid request", "This form was submitted from another site.", request))
        }
        guard let csrf = fields["csrf"],
              let sealed = cookie(flowCookieName(csrf: csrf), in: request),
              let flow = try? flows.open(sealed, now: now),
              ConstantTime.equal(csrf, flow.csrfToken)
        else {
            return .failure(errorPage(
                400, "Session expired",
                "Your sign-in session expired. Return to the application and try again.",
                request, clearFlow: fields["csrf"]
            ))
        }
        let pushed: OAuthPushedAuthorizationRequest?
        do {
            pushed = try await store.pushedAuthorizationRequest(
                requestDigest: digest.digest(flow.requestURI, purpose: .requestURI), now: now
            )
        } catch {
            return .failure(errorPage(503, "Try again", "The server cannot answer right now.", request))
        }
        guard let pushed, let client = await resolveForInterface(pushed.binding.clientID, now: now) else {
            return .failure(errorPage(
                400, "Request expired",
                "This authorization request has expired or was already used. Return to the application and try again.",
                request, clearFlow: flow.csrfToken
            ))
        }
        return .success(ActiveFlow(
            flow: flow, request: pushed, client: client, fields: fields,
            deviceID: cookie(deviceCookieName, in: request)
        ))
    }

    private func continueAfter(
        _ result: OAuthSignInResult,
        _ active: ActiveFlow,
        _ request: OAuthHTTPRequest,
        now: Date
    ) async -> OAuthHTTPResponse {
        var active = active
        switch result {
        case .rejected:
            return signInPage(active, request, error: "That handle and password were not accepted.", status: 401)
        case let .secondFactorRequired(challenge):
            active.flow.subject = nil
            active.flow.authenticatedAt = nil
            active.flow.pendingSecondFactor = challenge
            return secondFactorPage(active, challenge, request, error: nil, status: 200)
        case let .authenticated(account):
            // A login_hint that names a local account restricts the request
            // to that account.
            if let hint = active.request.loginHint,
               let hinted = try? await accounts.resolveLoginHint(hint), hinted != account.did
            {
                return signInPage(
                    active, request,
                    error: "This application asked to sign in as a different account.", status: 403
                )
            }
            active.flow.subject = account.did
            active.flow.authenticatedAt = now
            active.flow.pendingSecondFactor = nil
            var response: OAuthHTTPResponse
            if configuration.deviceSessionLifetime > 0 {
                // A fresh device identifier at every sign-in: one that someone
                // else planted in this browser before it authenticated (session
                // fixation) is retired, and what it remembered moves to the
                // identifier only this browser now holds.
                let deviceID = random.opaqueValue()
                let deviceDigest = digest.digest(deviceID, purpose: .device)
                if let previous = active.deviceID {
                    try? await store.moveDeviceAccounts(
                        from: digest.digest(previous, purpose: .device), to: deviceDigest, now: now
                    )
                }
                try? await store.rememberDeviceAccount(
                    OAuthDeviceAccount(subject: account.did, authenticatedAt: now),
                    deviceDigest: deviceDigest,
                    now: now
                )
                response = await consentPage(active, account: account, request)
                response.headers.add("Set-Cookie", setCookie(
                    deviceCookieName, deviceID, path: "/",
                    maxAge: Int(configuration.deviceSessionLifetime)
                ))
            } else {
                response = await consentPage(active, account: account, request)
            }
            return response
        }
    }

    private func consentPage(
        _ active: ActiveFlow,
        account: OAuthAccount,
        _ request: OAuthHTTPRequest
    ) async -> OAuthHTTPResponse {
        let requested = active.request.binding.requestedScopes
        let sets = (try? await effectiveGrant(for: requested, stage: .pushedAuthorizationRequest))?.permissionSets ?? [:]
        let languages = Self.preferredLanguages(request)
        let page = OAuthInterfacePage.consent(.init(
            client: presentation(active.client),
            csrfToken: active.flow.csrfToken,
            formAction: Path.consent,
            account: account,
            permissions: OAuthScopeDescription.summarize(
                requestedScopes: requested, permissionSets: sets, languages: languages
            ),
            requestedScopes: requested.sorted()
        ))
        return html(200, page, request, flow: active.flow, redirectURI: active.request.binding.redirectURI)
    }

    private func signInPage(
        _ active: ActiveFlow,
        _ request: OAuthHTTPRequest,
        error: String?,
        status: Int
    ) -> OAuthHTTPResponse {
        var flow = active.flow
        flow.subject = nil
        flow.authenticatedAt = nil
        flow.pendingSecondFactor = nil
        return html(status, .signIn(.init(
            client: presentation(active.client),
            csrfToken: flow.csrfToken,
            formAction: Path.signIn,
            identifierHint: active.request.loginHint,
            errorMessage: error
        )), request, flow: flow, redirectURI: active.request.binding.redirectURI)
    }

    private func secondFactorPage(
        _ active: ActiveFlow,
        _ challenge: OAuthSecondFactorChallenge,
        _ request: OAuthHTTPRequest,
        error: String?,
        status: Int
    ) -> OAuthHTTPResponse {
        html(status, .secondFactor(.init(
            client: presentation(active.client),
            csrfToken: active.flow.csrfToken,
            formAction: Path.secondFactor,
            prompt: challenge.prompt,
            errorMessage: error
        )), request, flow: active.flow, redirectURI: active.request.binding.redirectURI)
    }

    private func resolveForInterface(_ clientID: String, now: Date) async -> OAuthResolvedClientMetadata? {
        guard let url = URL(string: clientID) else { return nil }
        return try? await clients.resolve(clientID: url, revalidate: false, now: now)
    }

    /// The accounts signed in on this browser that still exist, narrowed to
    /// the hinted account when the client's `login_hint` names a local one.
    private func deviceAccounts(deviceID: String?, restrictedBy hint: String?, now: Date) async -> [OAuthAccount] {
        await rememberedAccounts(deviceID: deviceID, restrictedBy: hint, now: now).map(\.account)
    }

    /// ``deviceAccounts(deviceID:restrictedBy:now:)`` with the time each
    /// account last signed in on this browser.
    private func rememberedAccounts(
        deviceID: String?,
        restrictedBy hint: String?,
        now: Date
    ) async -> [(account: OAuthAccount, authenticatedAt: Date)] {
        guard let deviceID, deviceID.utf8.count == 43, configuration.deviceSessionLifetime > 0,
              let remembered = try? await store.deviceAccounts(
                  deviceDigest: digest.digest(deviceID, purpose: .device),
                  maximumAge: configuration.deviceSessionLifetime,
                  now: now
              )
        else { return [] }
        var hinted: String?
        if let hint { hinted = try? await accounts.resolveLoginHint(hint) }
        var result: [(account: OAuthAccount, authenticatedAt: Date)] = []
        for entry in remembered {
            if let hinted, entry.subject != hinted { continue }
            if let account = try? await accounts.account(did: entry.subject) {
                result.append((account, entry.authenticatedAt))
            }
        }
        return result
    }

    private func presentation(_ client: OAuthResolvedClientMetadata) -> OAuthClientPresentation {
        let metadata = client.metadata
        let clientID = metadata.clientID.absoluteString
        let trusted = configuration.trustedClientIDs.contains(clientID)
        return OAuthClientPresentation(
            clientID: clientID,
            host: metadata.clientID.host ?? clientID,
            name: trusted ? metadata.clientName : nil,
            uri: trusted ? metadata.clientURI?.absoluteString : nil,
            logoURI: trusted ? metadata.logoURI?.absoluteString : nil,
            isTrusted: trusted,
            isLoopbackDevelopmentClient: metadata.isLoopbackDevelopmentClient
        )
    }

    // MARK: - Responses

    /// The redirect back to the client: always to the exact registered
    /// `redirect_uri` of the pushed request, always with `state` and `iss`
    /// (RFC 9207), and always `303` so the browser follows it with a GET.
    private func redirect(
        _ pushed: OAuthPushedAuthorizationRequest,
        _ parameters: [(String, String)],
        clearing csrf: String
    ) -> OAuthHTTPResponse {
        let all = parameters + [("state", pushed.state), ("iss", issuer)]
        let query = all.map { "\(OAuthForm.encodeComponent($0.0))=\(OAuthForm.encodeComponent($0.1))" }
            .joined(separator: "&")
        let base = pushed.binding.redirectURI
        let location: String = switch pushed.responseMode {
        case .query: base + (base.contains("?") ? "&" : "?") + query
        // Registered redirect URIs never carry a fragment, so this is the
        // only one.
        case .fragment: base + "#" + query
        }
        var headers = OAuthHTTPHeaders([
            ("Location", location),
            ("Cache-Control", "no-store"),
            ("Referrer-Policy", "no-referrer"),
        ])
        headers.add("Set-Cookie", setCookie(flowCookieName(csrf: csrf), "", path: "/", maxAge: 0))
        return OAuthHTTPResponse(status: 303, headers: headers)
    }

    private func errorPage(
        _ status: Int,
        _ title: String,
        _ message: String,
        _ request: OAuthHTTPRequest,
        clearFlow csrf: String? = nil
    ) -> OAuthHTTPResponse {
        var response = html(status, .error(.init(title: title, message: message)), request, flow: nil, redirectURI: nil)
        if let csrf {
            response.headers.add("Set-Cookie", setCookie(flowCookieName(csrf: csrf), "", path: "/", maxAge: 0))
        }
        return response
    }

    private func html(
        _ status: Int,
        _ page: OAuthInterfacePage,
        _ request: OAuthHTTPRequest,
        flow: OAuthBrowserFlow?,
        redirectURI: String?
    ) -> OAuthHTTPResponse {
        let nonce = JWTBase64URL.encode(random.bytes(count: 16))
        let body = interface.render(page, nonce: nonce, languages: Self.preferredLanguages(request))
        // The consent form's final answer is a redirect to the client, and
        // browsers apply form-action to that redirect, so the client's origin
        // (or custom scheme) is the one extra permitted target.
        var formAction = "'self'"
        if let redirectURI, let source = Self.formActionSource(redirectURI) { formAction += " \(source)" }
        var headers = OAuthHTTPHeaders([
            ("Content-Type", "text/html; charset=utf-8"),
            ("Cache-Control", "no-store"),
            ("Pragma", "no-cache"),
            ("Content-Security-Policy",
             "default-src 'none'; style-src 'nonce-\(nonce)'; script-src 'nonce-\(nonce)'; img-src https: data:; "
                 + "form-action \(formAction); frame-ancestors 'none'; base-uri 'none'"),
            ("X-Frame-Options", "DENY"),
            ("X-Content-Type-Options", "nosniff"),
            ("Referrer-Policy", "no-referrer"),
        ])
        if let flow, let sealed = try? flows.seal(flow) {
            headers.add("Set-Cookie", setCookie(
                flowCookieName(csrf: flow.csrfToken), sealed, path: "/",
                maxAge: max(1, Int(flow.expiresAt.timeIntervalSince(clock.now())))
            ))
        }
        return OAuthHTTPResponse(status: status, headers: headers, body: Data(body.utf8))
    }

    static func formActionSource(_ redirectURI: String) -> String? {
        guard let components = URLComponents(string: redirectURI), let scheme = components.scheme?.lowercased(),
              scheme.utf8.allSatisfy({ ($0 >= 0x61 && $0 <= 0x7A) || ($0 >= 0x30 && $0 <= 0x39) || $0 == 0x2B || $0 == 0x2D || $0 == 0x2E })
        else { return nil }
        guard scheme == "https" || scheme == "http", let host = components.host else {
            return "\(scheme):"
        }
        let hostText = host.contains(":") && !host.hasPrefix("[") ? "[\(host)]" : host
        return "\(scheme)://\(hostText)" + (components.port.map { ":\($0)" } ?? "")
    }

    private func setCookie(_ name: String, _ value: String, path: String, maxAge: Int) -> String {
        var cookie = "\(name)=\(value); Path=\(path); Max-Age=\(maxAge); HttpOnly; SameSite=Lax"
        if configuration.secureCookies { cookie += "; Secure" }
        return cookie
    }

    /// The value of a cookie that appears exactly once in the request.
    private func cookie(_ name: String, in request: OAuthHTTPRequest) -> String? {
        var found: [String] = []
        for header in request.headers.values(for: "Cookie") {
            for pair in header.split(separator: ";") {
                let trimmed = pair.trimmingCharacters(in: .whitespaces)
                guard let separator = trimmed.firstIndex(of: "=") else { continue }
                if trimmed[..<separator] == name {
                    found.append(String(trimmed[trimmed.index(after: separator)...]))
                }
            }
        }
        return found.count == 1 ? found[0] : nil
    }

    static func preferredLanguages(_ request: OAuthHTTPRequest) -> [String] {
        guard let header = request.headers["Accept-Language"], header.utf8.count <= 512 else { return [] }
        let weighted = header.split(separator: ",").compactMap { part -> (String, Double)? in
            let pieces = part.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            guard let tag = pieces.first, !tag.isEmpty, tag != "*" else { return nil }
            var quality = 1.0
            if pieces.count > 1, pieces[1].hasPrefix("q="), let parsed = Double(pieces[1].dropFirst(2)) {
                quality = parsed
            }
            return quality > 0 ? (tag, quality) : nil
        }
        return weighted.sorted { $0.1 > $1.1 }.map(\.0)
    }
}

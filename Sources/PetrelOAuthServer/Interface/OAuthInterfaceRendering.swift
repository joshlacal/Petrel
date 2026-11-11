import Foundation

/// How a client is identified to the user.
///
/// Any party can publish client metadata claiming any name, so the
/// self-declared `name`, `uri` and `logoURI` are populated only for clients
/// the server operator listed as trusted. The verified `clientID` is always
/// present and must always be shown.
public struct OAuthClientPresentation: Sendable, Equatable {
    /// The verified `client_id` URL.
    public let clientID: String
    /// The hostname of the `client_id`, the one identity the server verified.
    public let host: String
    /// The client's declared name. `nil` unless the client is trusted.
    public let name: String?
    /// The client's declared homepage. `nil` unless the client is trusted.
    public let uri: String?
    /// The client's declared logo. `nil` unless the client is trusted.
    public let logoURI: String?
    /// Whether the operator listed this client as trusted.
    public let isTrusted: Bool
    /// Whether this is an `http://localhost` development client.
    public let isLoopbackDevelopmentClient: Bool
}

/// A page of the Authorization Interface, as data. A renderer turns it into
/// HTML; the server owns the flow, the forms' targets and their field names.
///
/// Every form posts to the page model's `formAction` with `Content-Type:
/// application/x-www-form-urlencoded` and must include a `csrf` field holding
/// the model's `csrfToken`. The other fields are:
///
/// | page | field | value |
/// |---|---|---|
/// | sign-in | `identifier`, `password` | handle or DID, and password |
/// | account selection | `account` | the DID to continue as, or empty to sign in to another account |
/// | second factor | `code` | what the user entered |
/// | consent | `decision` | `approve` or `deny` |
public enum OAuthInterfacePage: Sendable, Equatable {
    /// Ask for a handle and password.
    case signIn(SignIn)
    /// Offer the accounts already signed in on this browser.
    case selectAccount(SelectAccount)
    /// Ask for a second authentication factor.
    case secondFactor(SecondFactor)
    /// Ask the user to approve or deny the client's request.
    case consent(Consent)
    /// A dead end: the request cannot proceed and cannot safely be redirected.
    case error(Failure)

    /// The sign-in page.
    public struct SignIn: Sendable, Equatable {
        /// The requesting client.
        public let client: OAuthClientPresentation
        /// The CSRF token for the form.
        public let csrfToken: String
        /// The path the form posts to.
        public let formAction: String
        /// The client's `login_hint`, to pre-fill the identifier.
        public let identifierHint: String?
        /// A message to show after a failed attempt.
        public let errorMessage: String?
    }

    /// The account-selection page.
    public struct SelectAccount: Sendable, Equatable {
        /// The requesting client.
        public let client: OAuthClientPresentation
        /// The CSRF token for the form.
        public let csrfToken: String
        /// The path the form posts to.
        public let formAction: String
        /// The accounts signed in on this browser.
        public let accounts: [OAuthAccount]
    }

    /// The second-factor page.
    public struct SecondFactor: Sendable, Equatable {
        /// The requesting client.
        public let client: OAuthClientPresentation
        /// The CSRF token for the form.
        public let csrfToken: String
        /// The path the form posts to.
        public let formAction: String
        /// What to ask for.
        public let prompt: String
        /// A message to show after a failed attempt.
        public let errorMessage: String?
    }

    /// The consent page.
    public struct Consent: Sendable, Equatable {
        /// The requesting client.
        public let client: OAuthClientPresentation
        /// The CSRF token for the form.
        public let csrfToken: String
        /// The path the form posts to.
        public let formAction: String
        /// The account that would be authorized.
        public let account: OAuthAccount
        /// What the client is asking for, in plain language.
        public let permissions: [OAuthScopeSummary]
        /// The requested scope strings, for an "advanced" disclosure.
        public let requestedScopes: [String]
    }

    /// The error page.
    public struct Failure: Sendable, Equatable {
        /// A short heading.
        public let title: String
        /// What went wrong, in terms the user can act on.
        public let message: String
    }
}

/// Renders the Authorization Interface. Implement this to replace the default
/// pages with the host application's own design.
///
/// The server wraps whatever is returned with its security headers: a
/// `Content-Security-Policy` that allows inline `<style>` and `<script>` only
/// when they carry the supplied nonce, `frame-ancestors 'none'`,
/// `X-Frame-Options: DENY`, `Cache-Control: no-store` and `Referrer-Policy:
/// no-referrer`. A renderer cannot weaken them.
public protocol OAuthInterfaceRendering: Sendable {
    /// Produces a complete HTML document for `page`.
    ///
    /// - Parameters:
    ///   - page: what to show.
    ///   - nonce: the CSP nonce inline `<style>` and `<script>` elements must
    ///     carry.
    ///   - languages: the browser's preferred languages, most preferred first.
    func render(_ page: OAuthInterfacePage, nonce: String, languages: [String]) -> String
}

/// The built-in, unbranded Authorization Interface: small server-rendered
/// pages with no scripts and no external resources.
public struct OAuthDefaultInterface: OAuthInterfaceRendering {
    /// The name shown in page titles, typically the service's name.
    public let serviceName: String

    /// Creates the default interface.
    public init(serviceName: String = "Sign in") {
        self.serviceName = serviceName
    }

    public func render(_ page: OAuthInterfacePage, nonce: String, languages _: [String]) -> String {
        switch page {
        case let .signIn(model):
            let error = model.errorMessage.map { "<p class=\"error\" role=\"alert\">\(Self.escape($0))</p>" } ?? ""
            let hint = model.identifierHint.map { " value=\"\(Self.escape($0))\"" } ?? ""
            return document(title: "Sign in", nonce: nonce, body: """
            \(clientBlock(model.client, verb: "Sign in to continue to"))
            \(error)
            <form method="post" action="\(Self.escape(model.formAction))">
            <input type="hidden" name="csrf" value="\(Self.escape(model.csrfToken))">
            <label>Handle or DID<input name="identifier" autocomplete="username" autocapitalize="none" \
            spellcheck="false" required\(hint)></label>
            <label>Password<input name="password" type="password" autocomplete="current-password" required></label>
            <button type="submit">Sign in</button>
            </form>
            """)
        case let .selectAccount(model):
            let choices = model.accounts.map { account in
                """
                <button type="submit" name="account" value="\(Self.escape(account.did))" class="account">\
                <b>\(Self.escape(account.handle ?? account.did))</b>\
                <small>\(Self.escape(account.did))</small></button>
                """
            }.joined()
            return document(title: "Choose an account", nonce: nonce, body: """
            \(clientBlock(model.client, verb: "Choose an account to continue to"))
            <form method="post" action="\(Self.escape(model.formAction))">
            <input type="hidden" name="csrf" value="\(Self.escape(model.csrfToken))">
            \(choices)
            <button type="submit" name="account" value="" class="secondary">Use another account</button>
            </form>
            """)
        case let .secondFactor(model):
            let error = model.errorMessage.map { "<p class=\"error\" role=\"alert\">\(Self.escape($0))</p>" } ?? ""
            return document(title: "Verify it is you", nonce: nonce, body: """
            \(clientBlock(model.client, verb: "One more step to continue to"))
            \(error)
            <form method="post" action="\(Self.escape(model.formAction))">
            <input type="hidden" name="csrf" value="\(Self.escape(model.csrfToken))">
            <label>\(Self.escape(model.prompt))<input name="code" autocomplete="one-time-code" inputmode="numeric" \
            required></label>
            <button type="submit">Continue</button>
            </form>
            """)
        case let .consent(model):
            let permissions = model.permissions.isEmpty
                ? "<p>This application is asking only to sign you in. It will learn your account identifier.</p>"
                : "<ul class=\"permissions\">" + model.permissions.map { line in
                    let details = line.details.map { "<li>\(Self.escape($0))</li>" }.joined()
                    let flag = line.isSensitive ? " class=\"sensitive\"" : ""
                    return "<li\(flag)><b>\(Self.escape(line.title))</b><ul>\(details)</ul></li>"
                }.joined() + "</ul>"
            let raw = model.requestedScopes.map { "<li><code>\(Self.escape($0))</code></li>" }.joined()
            return document(title: "Authorize access", nonce: nonce, body: """
            \(clientBlock(model.client, verb: "Allow access for"))
            <p>Signed in as <b>\(Self.escape(model.account.handle ?? model.account.did))</b>\
            <small>\(Self.escape(model.account.did))</small></p>
            \(permissions)
            <details><summary>Requested scopes</summary><ul>\(raw)</ul></details>
            <form method="post" action="\(Self.escape(model.formAction))">
            <input type="hidden" name="csrf" value="\(Self.escape(model.csrfToken))">
            <button type="submit" name="decision" value="approve">Allow</button>
            <button type="submit" name="decision" value="deny" class="secondary">Deny</button>
            </form>
            """)
        case let .error(model):
            return document(title: model.title, nonce: nonce, body: """
            <h1>\(Self.escape(model.title))</h1>
            <p>\(Self.escape(model.message))</p>
            """)
        }
    }

    private func clientBlock(_ client: OAuthClientPresentation, verb: String) -> String {
        let name = client.name.map { "<b>\(Self.escape($0))</b> " } ?? ""
        let logo = client.logoURI.map {
            "<img src=\"\(Self.escape($0))\" alt=\"\" width=\"48\" height=\"48\" referrerpolicy=\"no-referrer\">"
        } ?? ""
        let caution = client.isTrusted
            ? ""
            : "<p class=\"note\">Only the address above is verified. Check that you recognise it.</p>"
        return """
        <h1>\(Self.escape(serviceName))</h1>
        <p>\(Self.escape(verb)) \(logo)\(name)<code>\(Self.escape(client.clientID))</code></p>\(caution)
        """
    }

    private func document(title: String, nonce: String, body: String) -> String {
        """
        <!doctype html>
        <html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="robots" content="noindex">
        <title>\(Self.escape(title)) · \(Self.escape(serviceName))</title>
        <style nonce="\(Self.escape(nonce))">
        body{font:16px/1.5 system-ui,sans-serif;max-width:32rem;margin:2rem auto;padding:0 1rem;color:#111;background:#fff}
        h1{font-size:1.25rem}label{display:block;margin:.75rem 0}input{display:block;width:100%;box-sizing:border-box;\
        padding:.5rem;font:inherit;border:1px solid #888;border-radius:.375rem}
        button{font:inherit;padding:.5rem 1rem;margin:.5rem .5rem 0 0;border:1px solid #111;border-radius:.375rem;\
        background:#111;color:#fff;cursor:pointer}button.secondary{background:#fff;color:#111}
        button.account{display:block;width:100%;text-align:left;background:#fff;color:#111}
        small{display:block;color:#555;word-break:break-all}code{word-break:break-all}
        .error{color:#a00}.note{color:#555;font-size:.875rem}.sensitive>b{color:#a00}
        @media (prefers-color-scheme:dark){body{background:#111;color:#eee}input{background:#222;color:#eee}\
        button{background:#eee;color:#111;border-color:#eee}button.secondary,button.account{background:#111;color:#eee}\
        small,.note{color:#aaa}.error,.sensitive>b{color:#f88}}
        </style></head><body>
        \(body)
        </body></html>
        """
    }

    /// Escapes text for an HTML text node or a double-quoted attribute value.
    public static func escape(_ value: String) -> String {
        var output = ""
        output.reserveCapacity(value.utf8.count)
        for character in value {
            switch character {
            case "&": output += "&amp;"
            case "<": output += "&lt;"
            case ">": output += "&gt;"
            case "\"": output += "&quot;"
            case "'": output += "&#39;"
            default: output.append(character)
            }
        }
        return output
    }
}

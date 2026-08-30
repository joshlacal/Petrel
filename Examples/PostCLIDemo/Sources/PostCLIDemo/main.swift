//
// main.swift
// Petrel Example: CLI tool for posting to Bluesky
//
// This demo shows how to authenticate with an app password and post to Bluesky.
//
// Usage:
//   swift run PostCLIDemo
//

import Foundation
#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif
import Petrel

@main
struct PostCLIDemo {
    static func main() async {
        print("📱 Bluesky CLI Poster")
        print("=====================\n")

        do {
            // Initialize the client
            let client = await ATProtoClient(
                baseURL: URL(string: "https://bsky.social")!,
                oauthConfig: OAuthConfig(
                    clientId: "http://localhost",
                    redirectUri: "http://localhost/callback"
                ),
                namespace: "com.example.postcli"
            )

            // Get credentials from user
            print("Enter your Bluesky handle (e.g., alice.bsky.social):")
            guard let handle = readLine()?.trimmingCharacters(in: .whitespaces),
                  !handle.isEmpty
            else {
                print("❌ Handle is required")
                exit(1)
            }

            print("\nEnter your app password:")
            print("(Generate one at https://bsky.app/settings/app-passwords)")
            guard let password = readSecret()?.trimmingCharacters(in: .whitespaces),
                  !password.isEmpty
            else {
                print("❌ Password is required")
                exit(1)
            }

            // Login
            print("\n🔐 Authenticating...")
            try await client.loginWithPassword(
                identifier: handle,
                password: password
            )

            let did = try await client.getDid()
            print("✅ Logged in successfully!")
            print("   DID: \(did)\n")

            // Main loop
            while true {
                print("\n" + String(repeating: "─", count: 50))
                print("What would you like to do?")
                print("1. Post a message")
                print("2. View your profile")
                print("3. Exit")
                print(String(repeating: "─", count: 50))
                print("\nChoice: ", terminator: "")

                guard let choice = readLine()?.trimmingCharacters(in: .whitespaces) else {
                    continue
                }

                switch choice {
                case "1":
                    try await postMessage(client: client, handle: handle)

                case "2":
                    try await viewProfile(client: client, handle: handle)

                case "3":
                    print("\n👋 Goodbye!")
                    exit(0)

                default:
                    print("❌ Invalid choice. Please enter 1, 2, or 3.")
                }
            }

        } catch let error as AuthError {
            print("\n❌ Authentication Error: \(error.errorDescription ?? error.localizedDescription)")
            if let suggestion = error.recoverySuggestion {
                print("💡 Suggestion: \(suggestion)")
            }
            exit(1)
        } catch {
            print("\n❌ Error: \(error)")
            exit(1)
        }
    }

    private static func readSecret(prompt: String? = nil) -> String? {
        if let prompt {
            print(prompt, terminator: "")
            fflush(stdout)
        }

        let descriptor = STDIN_FILENO
        guard isatty(descriptor) != 0 else {
            return readLine(strippingNewline: true)?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var originalTermios = termios()
        guard tcgetattr(descriptor, &originalTermios) == 0 else {
            print("\n❌ Error: Failed to inspect terminal attributes for secure password input")
            exit(1)
        }

        var noEchoTermios = originalTermios
        #if canImport(Darwin)
        noEchoTermios.c_lflag &= ~UInt(ECHO)
        #else
        noEchoTermios.c_lflag &= ~tcflag_t(ECHO)
        #endif

        guard tcsetattr(descriptor, TCSANOW, &noEchoTermios) == 0 else {
            print("\n❌ Error: Failed to disable terminal echo for secure password input")
            exit(1)
        }

        defer {
            tcsetattr(descriptor, TCSANOW, &originalTermios)
            print("")
            fflush(stdout)
        }

        return readLine(strippingNewline: true)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func postMessage(client: ATProtoClient, handle: String) async throws {
        print("\n📝 Compose your post:")
        print("(Press Enter twice to finish, or type 'cancel' to abort)\n")

        var lines: [String] = []
        var emptyLineCount = 0

        while true {
            guard let line = readLine() else { break }

            if line.trimmingCharacters(in: .whitespaces).lowercased() == "cancel" {
                print("❌ Post cancelled")
                return
            }

            if line.isEmpty {
                emptyLineCount += 1
                if emptyLineCount >= 2 {
                    break
                }
            } else {
                emptyLineCount = 0
            }

            lines.append(line)
        }

        // Remove trailing empty lines
        while lines.last?.isEmpty == true {
            lines.removeLast()
        }

        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        if text.isEmpty {
            print("❌ Post cannot be empty")
            return
        }

        if text.count > 300 {
            print("⚠️  Warning: Post is \(text.count) characters (max 300)")
            print("Post anyway? (y/n): ", terminator: "")
            guard let confirm = readLine()?.lowercased(), confirm == "y" else {
                print("❌ Post cancelled")
                return
            }
        }

        print("\n⏳ Posting...")

        // Create the post record
        let post = AppBskyFeedPost(
            text: text,
            entities: nil,
            facets: nil,
            reply: nil,
            embed: nil,
            langs: [LanguageCodeContainer(code: "en")],
            labels: nil,
            tags: nil,
            createdAt: ATProtocolDate(date: Date())
        )

        // Wrap in ATProtocolValueContainer
        let recordContainer = ATProtocolValueContainer(post)

        // Create the record
        let input = try ComAtprotoRepoCreateRecord.Input(
            repo: ATIdentifier(handle),
            collection: NSID("app.bsky.feed.post"),
            rkey: nil,
            validate: true,
            record: recordContainer,
            swapCommit: nil
        )

        let (responseCode, response) = try await client.com.atproto.repo.createRecord(input: input)

        if responseCode == 200, let uri = response?.uri {
            print("✅ Post created successfully!")
            print("   URI: \(uri)")

            // Extract the post ID for a web link
            if let uriString = uri.description.split(separator: "/").last {
                let webLink = "https://bsky.app/profile/\(handle)/post/\(uriString)"
                print("   View: \(webLink)")
            }
        } else {
            print("⚠️  Post may have failed (Status: \(responseCode))")
        }
    }

    static func viewProfile(client: ATProtoClient, handle: String) async throws {
        print("\n👤 Fetching profile...")

        let params = AppBskyActorGetProfile.Parameters(actor: handle)
        let (responseCode, profile) = try await client.app.bsky.actor.getProfile(input: params)

        guard responseCode == 200, let profile = profile else {
            print("❌ Failed to fetch profile (Status: \(responseCode))")
            return
        }

        print("\n" + String(repeating: "═", count: 50))
        print("Profile: @\(profile.handle)")
        print(String(repeating: "═", count: 50))

        if let displayName = profile.displayName {
            print("📛 Name: \(displayName)")
        }

        if let description = profile.description {
            print("📝 Bio: \(description)")
        }

        print("\n📊 Stats:")
        print("   Followers: \(profile.followersCount ?? 0)")
        print("   Following: \(profile.followsCount ?? 0)")
        print("   Posts: \(profile.postsCount ?? 0)")

        if let createdAt = profile.createdAt {
            print("   Joined: \(createdAt)")
        }

        print(String(repeating: "═", count: 50))
    }
}

// Run the demo
await PostCLIDemo.main()

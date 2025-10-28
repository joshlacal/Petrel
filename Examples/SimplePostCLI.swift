#!/usr/bin/env swift

//
// SimplePostCLI.swift
// Petrel Example: Simplified CLI for posting to Bluesky
//
// This is a standalone script that demonstrates basic posting without the full Petrel library.
// For production use, see PostCLIDemo which uses the full Petrel library.
//
// Usage:
//   chmod +x SimplePostCLI.swift
//   ./SimplePostCLI.swift
//
// Or:
//   swift SimplePostCLI.swift
//

import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@main
struct SimplePostCLI {
    static func main() async {
        print("📱 Simple Bluesky Poster")
        print("========================\n")
        
        print("Enter your Bluesky handle (e.g., alice.bsky.social):")
        guard let handle = readLine()?.trimmingCharacters(in: .whitespaces), !handle.isEmpty else {
            print("❌ Handle is required")
            exit(1)
        }
        
        print("\nEnter your app password:")
        print("(Generate one at https://bsky.app/settings/app-passwords)")
        guard let password = readLine()?.trimmingCharacters(in: .whitespaces), !password.isEmpty else {
            print("❌ Password is required")
            exit(1)
        }
        
        do {
            // Step 1: Create session
            print("\n🔐 Authenticating...")
            let session = try await createSession(identifier: handle, password: password)
            print("✅ Logged in as: \(session.did)")
            
            // Step 2: Get post text
            print("\n📝 Enter your post:")
            guard let text = readLine()?.trimmingCharacters(in: .whitespaces), !text.isEmpty else {
                print("❌ Post cannot be empty")
                exit(1)
            }
            
            if text.count > 300 {
                print("⚠️  Warning: Post is \(text.count) characters (recommended max: 300)")
            }
            
            // Step 3: Create post
            print("\n⏳ Posting...")
            let uri = try await createPost(session: session, text: text)
            
            print("✅ Posted successfully!")
            print("   URI: \(uri)")
            
            // Extract post ID for web link
            if let postId = uri.split(separator: "/").last {
                print("   View: https://bsky.app/profile/\(handle)/post/\(postId)")
            }
            
        } catch {
            print("\n❌ Error: \(error)")
            exit(1)
        }
    }
    
    static func createSession(identifier: String, password: String) async throws -> Session {
        let url = URL(string: "https://bsky.social/xrpc/com.atproto.server.createSession")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "identifier": identifier,
            "password": password
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "Invalid credentials", code: -1)
        }
        
        return try JSONDecoder().decode(Session.self, from: data)
    }
    
    static func createPost(session: Session, text: String) async throws -> String {
        let url = URL(string: "https://bsky.social/xrpc/com.atproto.repo.createRecord")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessJwt)", forHTTPHeaderField: "Authorization")
        
        let now = ISO8601DateFormatter().string(from: Date())
        
        let record: [String: Any] = [
            "$type": "app.bsky.feed.post",
            "text": text,
            "createdAt": now
        ]
        
        let body: [String: Any] = [
            "repo": session.did,
            "collection": "app.bsky.feed.post",
            "record": record
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            if let errorString = String(data: data, encoding: .utf8) {
                print("Server response: \(errorString)")
            }
            throw NSError(domain: "Failed to create post", code: -1)
        }
        
        let result = try JSONDecoder().decode(CreateRecordResponse.self, from: data)
        return result.uri
    }
}

struct Session: Codable {
    let did: String
    let handle: String
    let accessJwt: String
    let refreshJwt: String
}

struct CreateRecordResponse: Codable {
    let uri: String
    let cid: String
}

// Run the demo
await SimplePostCLI.main()

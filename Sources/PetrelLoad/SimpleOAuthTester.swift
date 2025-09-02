import Foundation
import Petrel

struct SimpleOAuthTester {
    let authService: AuthenticationService
    let networkService: NetworkService
    let namespace: String
    
    func runBasicDPoPTest(endpoint: String, iterations: Int) async {
        print("=== Basic DPoP Stress Test ===")
        print("Endpoint: \(endpoint)")
        print("Iterations: \(iterations)")
        
        var nonceRotations = 0
        var authErrors = 0
        var successfulRequests = 0
        var latencies: [TimeInterval] = []
        
        for i in 0..<iterations {
            let startTime = Date()
            
            do {
                let request = try await networkService.createURLRequest(
                    endpoint: endpoint,
                    method: "GET",
                    headers: [:],
                    body: nil,
                    queryItems: [URLQueryItem(name: "actor", value: "bsky.app")]
                )
                
                let (_, response) = try await networkService.request(request)
                
                let latency = Date().timeIntervalSince(startTime)
                latencies.append(latency)
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 401 {
                        authErrors += 1
                        if let wwwAuth = httpResponse.value(forHTTPHeaderField: "WWW-Authenticate"),
                           wwwAuth.contains("use_dpop_nonce") {
                            nonceRotations += 1
                            print("  Nonce rotation detected at request \(i + 1)")
                        }
                    } else if httpResponse.statusCode == 200 {
                        successfulRequests += 1
                    }
                }
                
                if i % 10 == 0 && i > 0 {
                    print("  Processed \(i) requests...")
                }
                
            } catch {
                authErrors += 1
                print("  Error at request \(i + 1): \(error)")
            }
            
            // Small delay to avoid overwhelming
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Calculate metrics
        let avgLatency = latencies.isEmpty ? 0 : latencies.reduce(0, +) / Double(latencies.count)
        let successRate = Double(successfulRequests) / Double(iterations) * 100
        
        print("\n=== DPoP Test Results ===")
        print("Total requests: \(iterations)")
        print("Successful: \(successfulRequests)")
        print("Auth errors: \(authErrors)")
        print("DPoP nonce rotations: \(nonceRotations)")
        print("Success rate: \(String(format: "%.1f", successRate))%")
        print("Average latency: \(String(format: "%.3f", avgLatency))s")
        
        if !latencies.isEmpty {
            let sorted = latencies.sorted()
            let p95 = sorted[Int(Double(sorted.count - 1) * 0.95)]
            let p99 = sorted[Int(Double(sorted.count - 1) * 0.99)]
            print("Latency p95: \(String(format: "%.3f", p95))s")
            print("Latency p99: \(String(format: "%.3f", p99))s")
        }
    }
    
    func runTokenRefreshTest() async {
        print("=== Token Refresh Test ===")
        
        do {
            print("Attempting forced token refresh...")
            let startTime = Date()
            
            _ = try await authService.refreshTokenIfNeeded(forceRefresh: true)
            
            let refreshTime = Date().timeIntervalSince(startTime)
            print("✓ Token refresh completed in \(String(format: "%.3f", refreshTime))s")
            
            // Test that the refreshed token works
            print("Testing refreshed token...")
            let request = try await networkService.createURLRequest(
                endpoint: "app.bsky.actor.getProfile",
                method: "GET",
                headers: [:],
                body: nil,
                queryItems: [URLQueryItem(name: "actor", value: "bsky.app")]
            )
            
            let (_, response) = try await networkService.request(request)
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    print("✓ Refreshed token working correctly")
                } else {
                    print("✗ Refreshed token failed with status: \(httpResponse.statusCode)")
                }
            }
            
        } catch {
            print("✗ Token refresh failed: \(error)")
        }
    }
    
    func validateDPoPHeaders() async {
        print("=== DPoP Header Validation ===")
        
        do {
            let request = try await networkService.createURLRequest(
                endpoint: "app.bsky.actor.getProfile",
                method: "GET",
                headers: [:],
                body: nil,
                queryItems: [URLQueryItem(name: "actor", value: "bsky.app")]
            )
            
            // Check for DPoP header
            if let dpopHeader = request.value(forHTTPHeaderField: "DPoP") {
                print("✓ DPoP header present")
                print("  DPoP header length: \(dpopHeader.count) characters")
                
                // Basic JWT format check (should have 3 parts separated by dots)
                let parts = dpopHeader.components(separatedBy: ".")
                if parts.count == 3 {
                    print("✓ DPoP header has correct JWT structure (3 parts)")
                } else {
                    print("✗ DPoP header malformed - expected 3 parts, got \(parts.count)")
                }
            } else {
                print("✗ DPoP header missing")
            }
            
            // Check for Authorization header
            if let authHeader = request.value(forHTTPHeaderField: "Authorization") {
                print("✓ Authorization header present")
                if authHeader.hasPrefix("DPoP ") {
                    print("✓ Authorization header uses DPoP scheme")
                } else {
                    print("✗ Authorization header scheme: \(authHeader.prefix(10))...")
                }
            } else {
                print("✗ Authorization header missing")
            }
            
        } catch {
            print("✗ Failed to create request: \(error)")
        }
    }
    
    func runComprehensiveTest(endpoint: String, basicIterations: Int = 20) async {
        print("=== Comprehensive OAuth Test Suite ===")
        print("Endpoint: \(endpoint)")
        print("Starting at: \(Date())")
        
        // 1. DPoP Header Validation
        await validateDPoPHeaders()
        print()
        
        // 2. Token Refresh Test
        await runTokenRefreshTest()
        print()
        
        // 3. Basic DPoP Stress Test
        await runBasicDPoPTest(endpoint: endpoint, iterations: basicIterations)
        print()
        
        print("=== Test Suite Complete ===")
        print("Completed at: \(Date())")
    }
}
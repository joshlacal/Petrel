// Debug-only extensions for ATProtoClient
// This file provides test helpers used by PetrelLoad and demo apps.
#if DEBUG
import Foundation

extension ATProtoClient {
    /// Debug helper to simulate an ambiguous refresh timeout scenario.
    /// Sleeps for the provided number of seconds and then triggers app-startup handling
    /// so the AuthenticationService can observe any interrupted refresh state.
    /// This is a no-op in release builds.
    public func simulateAmbiguousRefreshTimeout(durationSeconds: Int) async {
        // Bound the duration to a reasonable maximum to avoid accidental long sleeps in tests.
        let bounded = max(0, min(durationSeconds, 60 * 60))
        let ns = UInt64(bounded) * 1_000_000_000
        do {
            try await Task.sleep(nanoseconds: ns)
        } catch {
            // Task was cancelled; just return
            return
        }

    // After sleeping, trigger the public activation hook so the auth service inspects state.
    self.applicationDidBecomeActive()
    }
}
#endif

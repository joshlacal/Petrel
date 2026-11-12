import Foundation

/// The current time for credential-lifetime decisions (``Session`` expiry and
/// space-credential reuse).
///
/// Release builds always read the system clock. DEBUG builds let a test pin the
/// time for the duration of a task with `PetrelClock.$pinned.withValue(_:)`, so a
/// CI runner that freezes the process mid-test cannot age a credential across a
/// lifetime boundary. The pin is task-local: concurrently running tests never see
/// each other's pinned time.
package enum PetrelClock {
    #if DEBUG
        @TaskLocal package static var pinned: Date?
    #endif

    package static func now() -> Date {
        #if DEBUG
            if let pinned { return pinned }
        #endif
        return Date()
    }
}

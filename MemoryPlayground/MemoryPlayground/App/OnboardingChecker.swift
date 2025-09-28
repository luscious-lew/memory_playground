import Contacts
import Foundation

struct OnboardingChecker {
    func currentState() -> OnboardingState {
        var state: OnboardingState = []

        if canReadChatDatabase() {
            state.insert(.fullDiskAccess)
        }

        if hasContactsAccess() {
            state.insert(.contactsAccess)
        }

        if hasAPIKeysConfigured() {
            state.insert(.apiKeysConfigured)
        }

        return state
    }

    private func canReadChatDatabase() -> Bool {
        let path = ProcessInfo.processInfo.environment["IMESSAGE_DB_PATH"] ?? "/Users/lewisclements/Library/Messages/chat.db"
        return FileManager.default.isReadableFile(atPath: path)
    }

    private func hasContactsAccess() -> Bool {
        #if os(macOS)
        let status = CNContactStore.authorizationStatus(for: .contacts)
        return status == .authorized
        #else
        return true
        #endif
    }

    private func hasAPIKeysConfigured() -> Bool {
        let env = ProcessInfo.processInfo.environment
        return env["OPENAI_API_KEY"]?.isEmpty == false && env["OMI_API_KEY"]?.isEmpty == false
    }
}

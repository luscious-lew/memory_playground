import Foundation

struct OnboardingState: OptionSet {
    let rawValue: Int

    static let fullDiskAccess = OnboardingState(rawValue: 1 << 0)
    static let contactsAccess = OnboardingState(rawValue: 1 << 1)
    static let apiKeysConfigured = OnboardingState(rawValue: 1 << 2)

    static let all: OnboardingState = [.fullDiskAccess, .contactsAccess, .apiKeysConfigured]
}

import Contacts
import Foundation

@MainActor
final class ContactResolver {
    static let shared = ContactResolver()

    private let store = CNContactStore()
    private var cache: [String: String] = [:]
    private let nameFormatter = PersonNameComponentsFormatter()
    private let keysToFetch: [CNKeyDescriptor] = [
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactNicknameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor
    ]

    private init() {}

    func requestAccessIfNeeded() async {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        guard status == .notDetermined else { return }
        do {
            _ = try await store.requestAccess(for: .contacts)
        } catch {
            // Permission denied — caller will fall back to raw handles.
        }
    }

    func displayName(for identifier: String) -> String {
        if let cached = cache[identifier] {
            return cached
        }

        let name: String

        if identifier.contains("@") {
            name = lookupEmail(identifier.lowercased()) ?? identifier
        } else {
            let normalized = normalize(identifier)
            name = lookupPhone(normalized) ?? identifier
        }

        cache[identifier] = name
        return name
    }

    private func lookupPhone(_ phone: String) -> String? {
        let number = CNPhoneNumber(stringValue: phone)
        let predicate = CNContact.predicateForContacts(matching: number)
        return try? store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
            .first
            .map(fullName)
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    private func lookupEmail(_ email: String) -> String? {
        let predicate = CNContact.predicateForContacts(matchingEmailAddress: email)
        return try? store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
            .first
            .map(fullName)
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    private func fullName(for contact: CNContact) -> String {
        if !contact.nickname.isEmpty { return contact.nickname }
        let nameComponents = PersonNameComponents(givenName: contact.givenName, familyName: contact.familyName)
        let formatted = nameFormatter.string(from: nameComponents).trimmingCharacters(in: .whitespaces)
        if !formatted.isEmpty { return formatted }
        return contact.organizationName
    }

    private func normalize(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
    }
}

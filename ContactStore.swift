import Contacts
import Foundation

struct DuplicateGroup: Identifiable {
    let id: String
    let label: String
    let contacts: [CNContact]
}

@MainActor
final class ContactStore: ObservableObject {
    @Published private(set) var groups: [DuplicateGroup] = []
    @Published private(set) var isScanning = false
    @Published var errorMessage: String?

    private let store = CNContactStore()

    func scan() async {
        isScanning = true
        errorMessage = nil
        defer { isScanning = false }

        do {
            let allowed = try await requestAccessIfNeeded()
            guard allowed else {
                errorMessage = "Contacts access was denied. Enable it in Settings > Privacy & Security > Contacts."
                return
            }

            let keys: [CNKeyDescriptor] = [
                CNContactIdentifierKey as CNKeyDescriptor,
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor
            ]
            let request = CNFetchRequest<CNContact>(keysToFetch: keys)
            var contacts: [CNContact] = []
            try store.enumerateContacts(with: request) { contact, _ in
                contacts.append(contact)
            }

            let buckets = Dictionary(grouping: contacts) { duplicateKey(for: $0) }
            groups = buckets.compactMap { key, values in
                guard values.count > 1, !key.isEmpty else { return nil }
                let sorted = values.sorted { displayName($0) < displayName($1) }
                return DuplicateGroup(id: key, label: label(for: key), contacts: sorted)
            }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ contacts: [CNContact]) throws {
        guard !contacts.isEmpty else { return }
        let saveRequest = CNSaveRequest()
        for contact in contacts {
            saveRequest.delete(contact.mutableCopy() as! CNMutableContact)
        }
        try store.execute(saveRequest)

        let removed = Set(contacts.map(\.identifier))
        groups = groups.compactMap { group in
            let remaining = group.contacts.filter { !removed.contains($0.identifier) }
            guard remaining.count > 1 else { return nil }
            return DuplicateGroup(id: group.id, label: group.label, contacts: remaining)
        }
    }

    nonisolated func displayName(_ contact: CNContact) -> String {
        let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
        return name.isEmpty ? "Unnamed contact" : name
    }

    private func requestAccessIfNeeded() async throws -> Bool {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return try await store.requestAccess(for: .contacts)
        @unknown default:
            return false
        }
    }

    private func duplicateKey(for contact: CNContact) -> String {
        if let phone = contact.phoneNumbers
            .map({ normalizePhone($0.value.stringValue) })
            .first(where: { $0.count >= 7 }) {
            return "phone:\(phone)"
        }
        if let email = contact.emailAddresses
            .map({ $0.value as String })
            .map({ normalizeEmail($0) })
            .first(where: { !$0.isEmpty }) {
            return "email:\(email)"
        }
        return ""
    }

    private func normalizePhone(_ value: String) -> String {
        let digits = value.filter { $0.isNumber }
        return String(digits.suffix(10))
    }

    private func normalizeEmail(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func label(for key: String) -> String {
        key.hasPrefix("phone:") ? "Same phone number" : "Same email address"
    }
}

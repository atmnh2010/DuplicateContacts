import Contacts
import SwiftUI

struct ContentView: View {
    @StateObject private var contactStore = ContactStore()
    @State private var selectedIDs = Set<String>()
    @State private var showingDeleteConfirmation = false

    private var selectedContacts: [CNContact] {
        contactStore.groups.flatMap(\.contacts).filter { selectedIDs.contains($0.identifier) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if contactStore.isScanning {
                    ProgressView("Scanning contacts…")
                } else if contactStore.groups.isEmpty {
                    ContentUnavailableView(
                        "No duplicates found",
                        systemImage: "person.2.slash",
                        description: Text("Tap Scan to check your contacts on this device.")
                    )
                } else {
                    List {
                        ForEach(contactStore.groups) { group in
                            Section(group.label) {
                                ForEach(Array(group.contacts.enumerated()), id: \.element.identifier) { index, contact in
                                    ContactRow(
                                        contact: contact,
                                        isPrimary: index == 0,
                                        isSelected: selectedIDs.contains(contact.identifier)
                                    ) {
                                        toggle(contact)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Duplicate Contacts")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Scan") {
                        Task {
                            selectedIDs.removeAll()
                            await contactStore.scan()
                            selectDuplicatesByDefault()
                        }
                    }
                    .disabled(contactStore.isScanning)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(selectedContacts.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !selectedContacts.isEmpty {
                    Text("\(selectedContacts.count) selected")
                        .font(.footnote.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.thinMaterial)
                }
            }
            .alert("Could not scan contacts", isPresented: errorBinding) {
                Button("OK", role: .cancel) { contactStore.errorMessage = nil }
            } message: {
                Text(contactStore.errorMessage ?? "Unknown error")
            }
            .confirmationDialog(
                "Delete \(selectedContacts.count) contacts?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    do {
                        try contactStore.delete(selectedContacts)
                        selectedIDs.removeAll()
                    } catch {
                        contactStore.errorMessage = error.localizedDescription
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The selected contacts will be removed from this device and synced accounts.")
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { contactStore.errorMessage != nil },
            set: { if !$0 { contactStore.errorMessage = nil } }
        )
    }

    private func toggle(_ contact: CNContact) {
        if selectedIDs.contains(contact.identifier) {
            selectedIDs.remove(contact.identifier)
        } else {
            selectedIDs.insert(contact.identifier)
        }
    }

    private func selectDuplicatesByDefault() {
        selectedIDs = Set(contactStore.groups.flatMap { group in
            Array(group.contacts.dropFirst()).map(\.identifier)
        })
    }
}

private struct ContactRow: View {
    let contact: CNContact
    let isPrimary: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(CNContactFormatter.string(from: contact, style: .fullName) ?? "Unnamed contact")
                        .foregroundStyle(.primary)
                    if let phone = contact.phoneNumbers.first?.value.stringValue {
                        Text(phone).font(.caption).foregroundStyle(.secondary)
                    } else if let email = contact.emailAddresses.first?.value as String? {
                        Text(email).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isPrimary {
                    Text("Keep")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

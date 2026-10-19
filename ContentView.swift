import Contacts
import SwiftUI

struct ContentView: View {
    @StateObject private var contactStore = ContactStore()
    @State private var selectedIDs = Set<String>()
    @State private var showingDeleteConfirmation = false
    @State private var hasScanned = false

    private var selectedContacts: [CNContact] {
        contactStore.groups.flatMap(\.contacts).filter { selectedIDs.contains($0.identifier) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                content
            }
            .navigationTitle("Contacts Cleaner")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: scan) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Scan contacts")
                    .disabled(contactStore.isScanning)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !selectedContacts.isEmpty { deleteBar }
            }
            .alert("Scan failed", isPresented: errorBinding) {
                Button("OK", role: .cancel) { contactStore.errorMessage = nil }
            } message: {
                Text(contactStore.errorMessage ?? "Please try again.")
            }
            .confirmationDialog("Delete \(selectedContacts.count) contacts?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete selected", role: .destructive) { deleteSelected() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The selected contacts will be removed from this device and synced accounts.")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if contactStore.isScanning { scanningView }
        else if !hasScanned { welcomeView }
        else if contactStore.groups.isEmpty { emptyView }
        else { resultsView }
    }

    private var welcomeView: some View {
        VStack(spacing: 22) {
            Spacer()
            iconCard(symbol: "person.2.wave.2.fill", color: .blue)
            VStack(spacing: 8) {
                Text("Keep your contacts tidy").font(.title2.bold())
                Text("Find duplicate phone numbers and email addresses in seconds. Everything stays on your iPhone.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            Button(action: scan) {
                Label("Scan my contacts", systemImage: "magnifyingglass")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 28)
            Spacer()
            Text("Your contacts are never uploaded.").font(.caption).foregroundStyle(.secondary)
                .padding(.bottom, 20)
        }
    }

    private var scanningView: some View {
        VStack(spacing: 18) {
            ProgressView().controlSize(.large)
            Text("Scanning your contacts…").font(.headline)
            Text("This may take a moment for large address books.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            iconCard(symbol: "checkmark.circle.fill", color: .green)
            Text("You're all clear").font(.title2.bold())
            Text("No duplicate contacts were found.").foregroundStyle(.secondary)
            Button("Scan again", action: scan).buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding()
    }

    private var resultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard
                HStack {
                    Text("Duplicate groups").font(.headline)
                    Spacer()
                    Button(selectedContacts.count == contactStore.duplicateContactCount ? "Deselect all" : "Select all") {
                        toggleAll()
                    }.font(.subheadline.weight(.semibold))
                }
                ForEach(contactStore.groups) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(group.label.uppercased()).font(.caption.weight(.bold))
                            .foregroundStyle(.secondary).padding(.horizontal, 16).padding(.top, 14)
                        ForEach(group.contacts.indices, id: \.self) { index in
                            let contact = group.contacts[index]
                            ContactRow(contact: contact, isPrimary: index == 0,
                                       isSelected: selectedIDs.contains(contact.identifier)) { toggle(contact) }
                            if index < group.contacts.count - 1 { Divider().padding(.leading, 68) }
                        }
                    }
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }.padding()
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.2.fill").font(.title2).foregroundStyle(.blue)
                .frame(width: 48, height: 48).background(.blue.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("Duplicates found").font(.subheadline).foregroundStyle(.secondary)
                Text("\(contactStore.duplicateContactCount) contacts to review").font(.headline)
            }
            Spacer()
            Text("\(contactStore.groups.count)")
                .font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.blue)
        }
        .padding().background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var deleteBar: some View {
        Button { showingDeleteConfirmation = true } label: {
            Label("Delete \(selectedContacts.count) selected", systemImage: "trash.fill")
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 13)
        }
        .buttonStyle(.borderedProminent).tint(.red)
        .padding(.horizontal).padding(.top, 8).padding(.bottom, 4).background(.thinMaterial)
    }

    private func iconCard(symbol: String, color: Color) -> some View {
        Image(systemName: symbol).font(.system(size: 40, weight: .semibold)).foregroundStyle(color)
            .frame(width: 88, height: 88)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { contactStore.errorMessage != nil }, set: { if !$0 { contactStore.errorMessage = nil } })
    }

    private func scan() {
        selectedIDs.removeAll()
        hasScanned = true
        Task { @MainActor in
            await contactStore.scan()
            selectDuplicatesByDefault()
        }
    }

    private func toggle(_ contact: CNContact) {
        if selectedIDs.contains(contact.identifier) { selectedIDs.remove(contact.identifier) }
        else { selectedIDs.insert(contact.identifier) }
    }

    private func toggleAll() {
        let removable = Set(contactStore.groups.flatMap { Array($0.contacts.dropFirst()).map(\.identifier) })
        selectedIDs = selectedContacts.count == removable.count ? [] : removable
    }

    private func selectDuplicatesByDefault() {
        selectedIDs = Set(contactStore.groups.flatMap { Array($0.contacts.dropFirst()).map(\.identifier) })
    }

    private func deleteSelected() {
        do {
            try contactStore.delete(selectedContacts)
            selectedIDs.removeAll()
        } catch {
            contactStore.errorMessage = "We couldn't delete the selected contacts.\n\n\(error.localizedDescription)"
        }
    }
}

private struct ContactRow: View {
    let contact: CNContact
    let isPrimary: Bool
    let isSelected: Bool
    let action: () -> Void

    private var name: String {
        let value = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
        return value.isEmpty ? "Unnamed contact" : value
    }

    private var initials: String {
        String(name.split(separator: " ").prefix(2).compactMap { $0.first }).uppercased()
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(initials.isEmpty ? "?" : initials).font(.caption.bold()).foregroundStyle(.blue)
                    .frame(width: 40, height: 40).background(.blue.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(name).font(.body.weight(.medium)).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if isPrimary {
                    Text("KEEP").font(.system(size: 10, weight: .bold)).foregroundStyle(.green)
                } else {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3).foregroundStyle(isSelected ? .red : .secondary)
                }
            }
            .padding(16).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var detail: String {
        if let phone = contact.phoneNumbers.first?.value.stringValue { return phone }
        if let email = contact.emailAddresses.first?.value as String? { return email }
        return "No phone or email"
    }
}

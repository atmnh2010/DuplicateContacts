import SwiftUI
import Contacts

struct ContentView: View {
    @StateObject private var store = ContactStore()
    @State private var showingDeleteConfirmation = false
    @State private var isLoading = false
    @State private var alertMessage: String?

    var body: some View {
        NavigationView {
            Group {
                if !store.isAuthorized {
                    VStack(spacing: 16) {
                        Text("Contacts permission is required to find duplicates.")
                            .multilineTextAlignment(.center)
                        Button("Request Access") {
                            Task {
                                await store.requestAccessAndLoad()
                            }
                        }
                    }
                    .padding()
                } else if store.duplicateGroups.isEmpty {
                    VStack {
                        Text("No duplicate contacts found.")
                        Button("Rescan") {
                            Task {
                                await store.reload()
                            }
                        }
                    }
                    .padding()
                } else {
                    List {
                        ForEach(store.duplicateGroups) { group in
                            Section(header: GroupHeaderView(group: group)) {
                                ForEach(group.contacts) { item in
                                    ContactRowView(item: item)
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("Duplicate Contacts")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if store.isAuthorized {
                        Button("Rescan") {
                            Task {
                                await store.reload()
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if store.hasSelectableItems {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Text("Delete Selected")
                        }
                        .disabled(!store.hasSelectedItems)
                    }
                }
            }
            .alert(item: $alertMessage) { msg in
                Alert(title: Text("Error"), message: Text(msg), dismissButton: .default(Text("OK")))
            }
            .confirmationDialog(
                "This will permanently delete the selected contacts from your device. This cannot be undone.",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    Task {
                        do {
                            try await store.deleteSelected()
                        } catch {
                            alertMessage = error.localizedDescription
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear {
                Task {
                    await store.requestAccessAndLoad()
                }
            }
        }
    }
}

struct GroupHeaderView: View {
    @ObservedObject var group: DuplicateGroup

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(group.primaryDisplayName)
                    .font(.headline)
                Text("\(group.contacts.count) duplicate(s)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ContactRowView: View {
    @ObservedObject var item: ContactItem

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.displayName)
                if let details = item.subtitle {
                    Text(details).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: $item.isSelected)
                .labelsHidden()
                .accessibilityLabel("Select \(item.displayName)")
                .disabled(item.isPrimary)
        }
        .padding(.vertical, 4)
    }
}

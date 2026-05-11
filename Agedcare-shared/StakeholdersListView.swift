import SwiftUI

struct StakeholdersListView: View {
    @StateObject private var store = StakeholderStore.shared
    @State private var showAdd = false
    @State private var editingStakeholder: Stakeholder?
    @State private var searchText = ""
    @State private var selectedClassification: Stakeholder.Classification? = nil

    var body: some View {
        NavigationStack {
            List {
                filterBar
                clinicalSection
                nonClinicalSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppTheme.gradientDiamond.ignoresSafeArea())
            .navigationTitle("Team Management")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search by name or role")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(AppTheme.emeraldGreen)
                    }
                    .accessibilityLabel("Add new stakeholder")
                }
            }
            .sheet(isPresented: $showAdd) {
                AddStakeholderView(mode: .add) { store.add($0) }
            }
            .sheet(item: $editingStakeholder) { s in
                AddStakeholderView(mode: .edit(s)) { store.update($0) }
            }
        }
    }

    @ViewBuilder private var filterBar: some View {
        Section {
            Picker("Filter", selection: $selectedClassification) {
                Text("All").tag(Optional<Stakeholder.Classification>.none)
                ForEach(Stakeholder.Classification.allCases) {
                    Text($0.rawValue).tag(Optional($0))
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(.init())
        }
    }

    @ViewBuilder private var clinicalSection: some View {
        let items = filtered(store.clinical())
        if !items.isEmpty || selectedClassification == nil || selectedClassification == .clinical {
            Section(header: sectionHeader("Clinical", systemImage: "stethoscope", color: .blue)) {
                if items.isEmpty {
                    emptyRow("No clinical staff added yet")
                } else {
                    ForEach(items) { s in
                        stakeholderRow(s)
                    }
                    .onDelete { offsets in
                        offsets.map { items[$0].id }.forEach { store.delete(id: $0) }
                    }
                }
            }
        }
    }

    @ViewBuilder private var nonClinicalSection: some View {
        let items = filtered(store.nonClinical())
        if !items.isEmpty || selectedClassification == nil || selectedClassification == .nonClinical {
            Section(header: sectionHeader("Non-Clinical", systemImage: "briefcase.fill", color: .purple)) {
                if items.isEmpty {
                    emptyRow("No non-clinical stakeholders added yet")
                } else {
                    ForEach(items) { s in
                        stakeholderRow(s)
                    }
                    .onDelete { offsets in
                        offsets.map { items[$0].id }.forEach { store.delete(id: $0) }
                    }
                }
            }
        }
    }

    @ViewBuilder private func stakeholderRow(_ s: Stakeholder) -> some View {
        HStack(spacing: 12) {
            if let data = s.photoData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 44, height: 44).clipShape(Circle())
            } else {
                ProfileImageView(name: s.fullName, imageURL: nil, size: .small)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(s.fullName).font(.subheadline.bold()).foregroundStyle(AppTheme.textPrimary)
                Text(s.role).font(.caption).foregroundStyle(AppTheme.textSecondary)
                if !s.department.isEmpty {
                    Text(s.department).font(.caption2).foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(s.employmentType.rawValue)
                    .font(.caption2).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(AppTheme.emeraldGreenLight.opacity(0.4)).cornerRadius(4)
                    .foregroundStyle(AppTheme.emeraldGreenDark)
                if !s.isActive {
                    Text("Inactive").font(.caption2).foregroundStyle(AppTheme.danger)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { editingStakeholder = s }
        .listRowBackground(AppTheme.surface)
    }

    private func sectionHeader(_ title: String, systemImage: String, color: Color) -> some View {
        Label(title, systemImage: systemImage).foregroundStyle(color)
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(AppTheme.textSecondary)
            .listRowBackground(AppTheme.surface)
    }

    private func filtered(_ list: [Stakeholder]) -> [Stakeholder] {
        guard !searchText.isEmpty else { return list }
        let q = searchText.lowercased()
        return list.filter {
            $0.fullName.lowercased().contains(q) || $0.role.lowercased().contains(q)
        }
    }
}

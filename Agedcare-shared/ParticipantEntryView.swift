import SwiftUI

struct ParticipantEntryView: View {
    @StateObject private var store = ParticipantStore.shared
    @State private var showAddForm = false
    @State private var searchText = ""
    @State private var filterRisk: Participant.RiskLevel?
    @State private var editingParticipant: Participant?

    var body: some View {
        NavigationStack {
            Group {
                if store.participants.isEmpty && searchText.isEmpty {
                    emptyState
                } else {
                    participantList
                }
            }
            .navigationTitle("Participants")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddForm = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel("Add new participant")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("All") { filterRisk = nil }
                        ForEach(Participant.RiskLevel.allCases) { risk in
                            Button(risk.rawValue) { filterRisk = risk }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            if let risk = filterRisk {
                                Text(risk.rawValue)
                                    .font(.caption)
                            }
                        }
                    }
                    .accessibilityLabel("Filter by risk level")
                }
            }
            .searchable(text: $searchText, prompt: "Search participants")
            .sheet(isPresented: $showAddForm) {
                ParticipantFormView(mode: .add) { participant in
                    store.add(participant)
                }
            }
            .sheet(item: $editingParticipant) { participant in
                ParticipantFormView(mode: .edit(participant)) { updated in
                    store.update(updated)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.rectangle.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.emeraldGreen)

            Text("No Participants Yet")
                .font(.title2.bold())
                .foregroundColor(AppTheme.textPrimary)

            Text("Manually add participant details including\npersonal info, medical history, and emergency contacts.")
                .font(.body)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showAddForm = true
            } label: {
                Label("Add First Participant", systemImage: "plus.circle.fill")
                    .primaryButtonStyle()
                    .frame(maxWidth: 280)
            }
        }
        .padding(32)
    }

    private var participantList: some View {
        List {
            statsHeader

            ForEach(filteredParticipants) { participant in
                NavigationLink {
                    ParticipantDetailView(participant: participant)
                } label: {
                    ParticipantRowView(participant: participant)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        store.delete(id: participant.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        editingParticipant = participant
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(AppTheme.emeraldGreen)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var statsHeader: some View {
        Section {
            HStack(spacing: 16) {
                StatPill(label: "Total", value: "\(store.participants.count)", color: AppTheme.emeraldGreen)
                StatPill(label: "Active", value: "\(store.activeParticipants().count)", color: .blue)
                StatPill(label: "High Risk",
                         value: "\(store.participants.filter { $0.riskLevel == .high || $0.riskLevel == .critical }.count)",
                         color: .red)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .padding(.vertical, 4)
        }
    }

    private var filteredParticipants: [Participant] {
        var result = store.participants
        if let risk = filterRisk {
            result = result.filter { $0.riskLevel == risk }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.fullName.localizedCaseInsensitiveContains(searchText) ||
                $0.roomNumber.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result.sorted { $0.lastName < $1.lastName }
    }
}

// MARK: - Participant Row

struct ParticipantRowView: View {
    let participant: Participant

    var body: some View {
        HStack(spacing: 14) {
            participantAvatar
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(participant.fullName)
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    if !participant.isActive {
                        Text("INACTIVE")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.gray)
                            .cornerRadius(4)
                    }
                }
                HStack(spacing: 8) {
                    riskBadge
                    if !participant.roomNumber.isEmpty {
                        Label(participant.roomNumber, systemImage: "door.left.hand.closed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(participant.mobilityStatus.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if !participant.linkedStaffIds.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.caption)
                    Text("\(participant.linkedStaffIds.count)")
                        .font(.caption.bold())
                }
                .foregroundColor(AppTheme.emeraldGreen)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var participantAvatar: some View {
        if let data = participant.photoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(Circle().stroke(riskColor, lineWidth: 2))
        } else {
            ProfileImageView(name: participant.fullName, imageURL: nil, size: .custom(48))
                .overlay(Circle().stroke(riskColor, lineWidth: 2))
        }
    }

    private var riskBadge: some View {
        Text(participant.riskLevel.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(riskColor.opacity(0.15))
            .foregroundColor(riskColor)
            .cornerRadius(6)
    }

    private var riskColor: Color {
        switch participant.riskLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
}

// MARK: - Participant Detail

struct ParticipantDetailView: View {
    let participant: Participant
    @StateObject private var store = ParticipantStore.shared
    @State private var showEdit = false
    @State private var showLinkStaff = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileHeader
                quickActions
                personalInfoSection
                medicalSection
                emergencySection
                staffLinkSection
            }
            .padding()
        }
        .background(AppTheme.gradientDiamond.ignoresSafeArea())
        .navigationTitle(participant.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showEdit = true
                } label: {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            ParticipantFormView(mode: .edit(participant)) { updated in
                store.update(updated)
            }
        }
        .sheet(isPresented: $showLinkStaff) {
            StaffLinkSheet(participant: participant)
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            if let data = participant.photoData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.emeraldGreen, lineWidth: 3))
            } else {
                ProfileImageView(name: participant.fullName, imageURL: nil, size: .custom(100))
                    .overlay(Circle().stroke(AppTheme.emeraldGreen, lineWidth: 3))
            }

            Text(participant.fullName)
                .font(.title2.bold())
                .foregroundColor(AppTheme.textPrimary)

            HStack(spacing: 12) {
                Badge(participant.riskLevel.rawValue, color: riskColor)
                Badge(participant.mobilityStatus.rawValue, color: .blue)
                if participant.isActive {
                    Badge("Active", color: .green)
                } else {
                    Badge("Inactive", color: .gray)
                }
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            QuickActionButton(icon: "person.badge.key.fill", label: "Link Staff") {
                showLinkStaff = true
            }
            QuickActionButton(icon: "phone.fill", label: "Call GP") {
                if let url = URL(string: "tel:\(participant.gpPhone)"), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
            }
            QuickActionButton(icon: "phone.arrow.up.right", label: "Emergency") {
                if let url = URL(string: "tel:\(participant.emergencyContactPhone)"), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private var personalInfoSection: some View {
        DetailSection(title: "Personal Information", icon: "person.fill") {
            DetailRow(label: "Room", value: participant.roomNumber.isEmpty ? "—" : participant.roomNumber)
            DetailRow(label: "Gender", value: participant.gender.rawValue)
            if let dob = participant.dateOfBirth {
                DetailRow(label: "Date of Birth", value: dob.formatted(date: .long, time: .omitted))
                DetailRow(label: "Age", value: "\(Calendar.current.dateComponents([.year], from: dob, to: Date()).year ?? 0) years")
            }
            DetailRow(label: "Phone", value: participant.phoneNumber.isEmpty ? "—" : participant.phoneNumber)
            DetailRow(label: "Admitted", value: participant.admissionDate.formatted(date: .abbreviated, time: .omitted))
        }
    }

    private var medicalSection: some View {
        DetailSection(title: "Medical Information", icon: "cross.case.fill") {
            DetailRow(label: "Mobility", value: participant.mobilityStatus.rawValue)
            if !participant.allergies.isEmpty {
                DetailRow(label: "Allergies", value: participant.allergies)
            }
            if !participant.medications.isEmpty {
                DetailRow(label: "Medications", value: participant.medications)
            }
            if !participant.dietaryRequirements.isEmpty {
                DetailRow(label: "Dietary", value: participant.dietaryRequirements)
            }
            if !participant.medicalNotes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(participant.medicalNotes)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
        }
    }

    private var emergencySection: some View {
        DetailSection(title: "Emergency Contacts", icon: "phone.badge.waveform.fill") {
            if !participant.emergencyContactName.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Primary: \(participant.emergencyContactName)")
                        .font(.subheadline.bold())
                    Text("\(participant.emergencyContactRelation) — \(participant.emergencyContactPhone)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            if !participant.secondaryContactName.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Secondary: \(participant.secondaryContactName)")
                        .font(.subheadline.bold())
                    Text(participant.secondaryContactPhone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            if !participant.gpName.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GP: \(participant.gpName)")
                        .font(.subheadline.bold())
                    Text(participant.gpPhone)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var staffLinkSection: some View {
        DetailSection(title: "Linked Staff (\(participant.linkedStaffIds.count))", icon: "person.badge.key.fill") {
            if participant.linkedStaffIds.isEmpty {
                Text("No staff linked yet. Tap \"Link Staff\" above.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(participant.linkedStaffIds, id: \.self) { staffId in
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(AppTheme.emeraldGreen)
                        Text("Staff \(staffId.uuidString.prefix(8))…")
                            .font(.subheadline)
                        Spacer()
                        Button {
                            store.unlinkStaff(staffId, from: participant.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red.opacity(0.7))
                        }
                    }
                }
            }
        }
    }

    private var riskColor: Color {
        switch participant.riskLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
}

// MARK: - Supporting Views

private struct StatPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }
}

private struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption2.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppTheme.emeraldGreen.opacity(0.1))
            .foregroundColor(AppTheme.emeraldGreen)
            .cornerRadius(12)
        }
    }
}

private struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .cornerRadius(14)
        .shadow(color: AppTheme.darkChocolate.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundColor(AppTheme.textPrimary)
            Spacer()
        }
    }
}

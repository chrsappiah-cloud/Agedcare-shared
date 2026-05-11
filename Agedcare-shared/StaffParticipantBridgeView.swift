import SwiftUI

struct StaffParticipantBridgeView: View {
    let staff: StaffUserModel
    @StateObject private var store = ParticipantStore.shared
    @EnvironmentObject var container: DependencyContainer
    @EnvironmentObject var handoff: HandoffService
    @State private var selectedTab: BridgeTab = .myParticipants
    @State private var showAssignSheet = false
    @State private var showAddParticipant = false

    enum BridgeTab: String, CaseIterable, Identifiable {
        case myParticipants = "My Assigned"
        case allParticipants = "All Participants"
        case quickActions = "Quick Actions"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                bridgeTabBar
                tabContent
            }
            .background(AppTheme.gradientDiamond.ignoresSafeArea())
            .navigationTitle("Staff-Participant Bridge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showAddParticipant = true
                        } label: {
                            Label("Add Participant", systemImage: "person.badge.plus")
                        }
                        Button {
                            showAssignSheet = true
                        } label: {
                            Label("Assign to Me", systemImage: "person.badge.key.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddParticipant) {
                ParticipantFormView(mode: .add) { participant in
                    var p = participant
                    p.linkedStaffIds = [staff.id]
                    store.add(p)
                }
            }
            .sheet(isPresented: $showAssignSheet) {
                AssignParticipantsSheet(staffId: staff.id)
            }
        }
    }

    // MARK: - Tab Bar

    private var bridgeTabBar: some View {
        HStack(spacing: 0) {
            ForEach(BridgeTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 4) {
                        Text(tab.rawValue)
                            .font(.caption.bold())
                            .foregroundColor(selectedTab == tab ? AppTheme.emeraldGreen : .secondary)
                        Rectangle()
                            .fill(selectedTab == tab ? AppTheme.emeraldGreen : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .myParticipants:
            myParticipantsView
        case .allParticipants:
            allParticipantsView
        case .quickActions:
            quickActionsView
        }
    }

    // MARK: - My Participants

    private var myParticipantsView: some View {
        let linked = store.participantsLinkedTo(staffId: staff.id)
        return Group {
            if linked.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("No participants assigned to you")
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Assign participants from the \"All Participants\" tab\nor add a new one with the + menu.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        showAssignSheet = true
                    } label: {
                        Label("Assign Participants", systemImage: "person.badge.key.fill")
                            .primaryButtonStyle()
                            .frame(maxWidth: 240)
                    }
                    Spacer()
                }
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        staffSummaryCard(linked: linked)

                        ForEach(linked) { participant in
                            NavigationLink {
                                ParticipantDetailView(participant: participant)
                            } label: {
                                LinkedParticipantCard(
                                    participant: participant,
                                    staff: staff,
                                    onAlert: { sendAlert(for: participant) },
                                    onUnlink: { store.unlinkStaff(staff.id, from: participant.id) }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func staffSummaryCard(linked: [Participant]) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(staff.displayName ?? staff.role.capitalized)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Text("\(linked.count) participant\(linked.count == 1 ? "" : "s") assigned")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(spacing: 4) {
                let highRisk = linked.filter { $0.riskLevel == .high || $0.riskLevel == .critical }.count
                Text("\(highRisk)")
                    .font(.title2.bold())
                    .foregroundColor(highRisk > 0 ? .red : .green)
                Text("High Risk")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            VStack(spacing: 4) {
                Text("\(linked.filter { $0.isActive }.count)")
                    .font(.title2.bold())
                    .foregroundColor(.blue)
                Text("Active")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(AppTheme.surface)
        .cornerRadius(14)
        .shadow(color: AppTheme.darkChocolate.opacity(0.06), radius: 4, x: 0, y: 2)
    }

    // MARK: - All Participants

    private var allParticipantsView: some View {
        let all = store.activeParticipants()
        return Group {
            if all.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("No participants in the system")
                        .font(.headline)
                    Button {
                        showAddParticipant = true
                    } label: {
                        Label("Add First Participant", systemImage: "plus.circle.fill")
                            .primaryButtonStyle()
                            .frame(maxWidth: 240)
                    }
                    Spacer()
                }
            } else {
                List {
                    ForEach(all) { participant in
                        HStack {
                            NavigationLink {
                                ParticipantDetailView(participant: participant)
                            } label: {
                                ParticipantRowView(participant: participant)
                            }
                        }
                        .swipeActions(edge: .leading) {
                            if participant.linkedStaffIds.contains(staff.id) {
                                Button {
                                    store.unlinkStaff(staff.id, from: participant.id)
                                } label: {
                                    Label("Unassign", systemImage: "person.badge.minus")
                                }
                                .tint(.orange)
                            } else {
                                Button {
                                    store.linkStaff(staff.id, to: participant.id)
                                } label: {
                                    Label("Assign to Me", systemImage: "person.badge.plus")
                                }
                                .tint(AppTheme.emeraldGreen)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                BridgeActionCard(
                    icon: "person.crop.rectangle.badge.plus",
                    title: "Add New Participant",
                    description: "Manually upload participant information",
                    color: AppTheme.emeraldGreen
                ) {
                    showAddParticipant = true
                }

                BridgeActionCard(
                    icon: "person.badge.key.fill",
                    title: "Assign Participants",
                    description: "Link existing participants to your dashboard",
                    color: .blue
                ) {
                    showAssignSheet = true
                }

                BridgeActionCard(
                    icon: "bell.and.waves.left.and.right.fill",
                    title: "Broadcast Alert",
                    description: "Send alert to all your assigned participants",
                    color: AppTheme.emeraldRed
                ) {
                    broadcastAlert()
                }

                NavigationLink {
                    ParticipantEntryView()
                } label: {
                    BridgeActionCardContent(
                        icon: "list.bullet.rectangle.portrait.fill",
                        title: "Full Participant Registry",
                        description: "View and manage the complete participant list",
                        color: .purple
                    )
                }
                .buttonStyle(.plain)

                BridgeActionCard(
                    icon: "square.and.arrow.up",
                    title: "Export Participant Data",
                    description: "Generate a summary of all assigned participants",
                    color: .indigo
                ) {
                    exportParticipantData()
                }
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func sendAlert(for participant: Participant) {
        Task {
            await handoff.requestStaff(
                facilityId: staff.facilityId.uuidString,
                residentId: participant.id.uuidString,
                residentName: participant.fullName
            )
        }
    }

    private func broadcastAlert() {
        let linked = store.participantsLinkedTo(staffId: staff.id)
        for participant in linked where participant.riskLevel == .high || participant.riskLevel == .critical {
            sendAlert(for: participant)
        }
    }

    private func exportParticipantData() {
        let linked = store.participantsLinkedTo(staffId: staff.id)
        var text = "Participant Summary — \(staff.displayName ?? staff.role)\n"
        text += "Generated: \(Date().formatted())\n\n"
        for p in linked {
            text += "• \(p.fullName) | Room \(p.roomNumber) | Risk: \(p.riskLevel.rawValue) | Mobility: \(p.mobilityStatus.rawValue)\n"
        }
        UIPasteboard.general.string = text
    }
}

// MARK: - Linked Participant Card

private struct LinkedParticipantCard: View {
    let participant: Participant
    let staff: StaffUserModel
    let onAlert: () -> Void
    let onUnlink: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                if let data = participant.photoData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    ProfileImageView(name: participant.fullName, imageURL: nil, size: .custom(44))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(participant.fullName)
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)
                    HStack(spacing: 6) {
                        Badge(participant.riskLevel.rawValue, color: riskColor)
                        if !participant.roomNumber.isEmpty {
                            Text("Room \(participant.roomNumber)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                Button(action: onAlert) {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.badge.fill")
                            .font(.caption2)
                        Text("Alert")
                            .font(.caption2.bold())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.emeraldRed.opacity(0.1))
                    .foregroundColor(AppTheme.emeraldRed)
                    .cornerRadius(8)
                }

                if let phone = participant.emergencyContactPhone.nilIfEmpty {
                    Link(destination: URL(string: "tel:\(phone)")!) {
                        HStack(spacing: 4) {
                            Image(systemName: "phone.fill")
                                .font(.caption2)
                            Text("Emergency")
                                .font(.caption2.bold())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                }

                Spacer()

                Button(action: onUnlink) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.minus")
                            .font(.caption2)
                        Text("Unassign")
                            .font(.caption2.bold())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .background(AppTheme.surface)
        .cornerRadius(14)
        .shadow(color: AppTheme.darkChocolate.opacity(0.06), radius: 4, x: 0, y: 2)
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

// MARK: - Bridge Action Card

private struct BridgeActionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            BridgeActionCardContent(icon: icon, title: title, description: description, color: color)
        }
        .buttonStyle(.plain)
    }
}

private struct BridgeActionCardContent: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(AppTheme.surface)
        .cornerRadius(14)
        .shadow(color: AppTheme.darkChocolate.opacity(0.06), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Assign Participants Sheet

struct AssignParticipantsSheet: View {
    let staffId: UUID
    @StateObject private var store = ParticipantStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if store.participants.isEmpty {
                    ContentUnavailableView(
                        "No Participants",
                        systemImage: "person.slash",
                        description: Text("Add participants first from the Participants tab.")
                    )
                } else {
                    ForEach(store.participants) { participant in
                        let isLinked = participant.linkedStaffIds.contains(staffId)
                        Button {
                            if isLinked {
                                store.unlinkStaff(staffId, from: participant.id)
                            } else {
                                store.linkStaff(staffId, to: participant.id)
                            }
                        } label: {
                            HStack {
                                Image(systemName: isLinked ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(isLinked ? AppTheme.emeraldGreen : .secondary)
                                Text(participant.fullName)
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                if !participant.roomNumber.isEmpty {
                                    Text("Room \(participant.roomNumber)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Assign Participants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Staff Link Sheet (from Participant Detail)

struct StaffLinkSheet: View {
    let participant: Participant
    @StateObject private var store = ParticipantStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var staffIdText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 48))
                    .foregroundColor(AppTheme.emeraldGreen)

                Text("Link Staff to \(participant.fullName)")
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                Text("Enter a staff member's UUID to link them,\nor they can assign themselves from the Bridge tab.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                TextField("Staff UUID", text: $staffIdText)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .padding(.horizontal)

                Button {
                    if let uuid = UUID(uuidString: staffIdText.trimmingCharacters(in: .whitespaces)) {
                        store.linkStaff(uuid, to: participant.id)
                        dismiss()
                    }
                } label: {
                    Label("Link Staff Member", systemImage: "link.badge.plus")
                        .primaryButtonStyle()
                        .frame(maxWidth: 280)
                }
                .disabled(UUID(uuidString: staffIdText.trimmingCharacters(in: .whitespaces)) == nil)

                if !participant.linkedStaffIds.isEmpty {
                    Divider()
                    Text("Currently Linked (\(participant.linkedStaffIds.count))")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    ForEach(participant.linkedStaffIds, id: \.self) { sid in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(AppTheme.emeraldGreen)
                            Text(sid.uuidString.prefix(12) + "…")
                                .font(.caption)
                            Spacer()
                            Button {
                                store.unlinkStaff(sid, from: participant.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Link Staff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

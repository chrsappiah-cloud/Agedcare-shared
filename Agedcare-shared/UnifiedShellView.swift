import SwiftUI

enum ShellMode {
    case resident(facilityId: UUID, residentId: UUID)
    case staff(StaffUserModel)
}

struct UnifiedShellView: View {
    let mode: ShellMode
    let session: SessionViewModel
    @EnvironmentObject var container: DependencyContainer
    @EnvironmentObject var handoff: HandoffService
    @State private var selectedTab: Tab = .home
    @State private var showHandoffBanner = false
    @State private var showResidentDetail = false

    enum Tab: Hashable {
        case home
        case alerts
        case participants
        case bridge
        case aiMonitor
        case settings
        case switchPanel   // returns to hero / role-selection page
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            residentTab
            alertsTab
            participantsTab
            bridgeTab
            aiMonitorTab
            settingsTab
            switchPanelTab
        }
        .tint(AppTheme.emeraldGreen)
        .overlay(alignment: .top) { handoffBanner }
        .onAppear {
            selectedTab = isStaff ? .alerts : .home
            if case .staff(let staff) = mode {
                handoff.startPolling(facilityId: staff.facilityId.uuidString)
            }
        }
        .onDisappear {
            if isStaff { handoff.stopPolling() }
        }
        .onChange(of: selectedTab) { _, newTab in
            // Intercept the Switch Panel tap and navigate to the hero page
            guard newTab == .switchPanel else { return }
            selectedTab = isStaff ? .alerts : .home
            if isStaff { handoff.stopPolling() }
            session.state = .onboarding
        }
        .onChange(of: handoff.pendingHandoff) { _, newValue in
            showHandoffBanner = newValue != nil
        }
        .sheet(isPresented: $showHandoffBanner) {
            if isStaff, case .requestStaff(let fid, let rid, let name) = handoff.pendingHandoff {
                HandoffRequestView(
                    facilityId: fid, residentId: rid, residentName: name,
                    staff: staffUser!, session: session, handoff: handoff
                )
            }
        }
        .onChange(of: handoff.routingResidentId) { _, newValue in
            showResidentDetail = newValue != nil
        }
        .sheet(isPresented: $showResidentDetail) {
            routingSheet
        }
    }

    // MARK: - Tabs

    @ViewBuilder
    private var residentTab: some View {
        Group {
            switch mode {
            case .resident(let facilityId, let residentId):
                ResidentShellView(facilityId: facilityId, residentId: residentId)
            case .staff:
                ResidentPreviewForStaff()
            }
        }
        .tabItem { Label("Home", systemImage: "heart.circle.fill") }
        .tag(Tab.home)
        .accessibilityLabel("Home tab")
    }

    @ViewBuilder
    private var alertsTab: some View {
        Group {
            if let staff = staffUser {
                AlertsHomeView(staff: staff)
            } else {
                staffOnlyPlaceholder(feature: "Alerts")
            }
        }
        .tabItem { Label("Alerts", systemImage: "bell.badge.fill") }
        .tag(Tab.alerts)
        .accessibilityLabel("Alerts tab")
    }

    @ViewBuilder
    private var participantsTab: some View {
        ParticipantEntryView()
            .tabItem { Label("Participants", systemImage: "person.crop.rectangle.badge.plus") }
            .tag(Tab.participants)
            .accessibilityLabel("Participants tab")
    }

    @ViewBuilder
    private var bridgeTab: some View {
        Group {
            if let staff = staffUser {
                StaffParticipantBridgeView(staff: staff)
            } else {
                staffOnlyPlaceholder(feature: "Staff Bridge")
            }
        }
        .tabItem { Label("Bridge", systemImage: "person.badge.key.fill") }
        .tag(Tab.bridge)
        .accessibilityLabel("Staff-Participant Bridge tab")
    }

    @ViewBuilder
    private var aiMonitorTab: some View {
        Group {
            if let staff = staffUser {
                MediaInsightsDashboardView(staff: staff)
            } else {
                staffOnlyPlaceholder(feature: "AI Monitor")
            }
        }
        .tabItem { Label("AI Monitor", systemImage: "waveform.and.magnifyingglass") }
        .tag(Tab.aiMonitor)
        .accessibilityLabel("AI Monitoring tab")
        .badge(isStaff ? aiBadgeCount + handoffBadgeCount : 0)
    }

    @ViewBuilder
    private var settingsTab: some View {
        NavigationStack {
            if let staff = staffUser {
                SettingsView(staff: staff, session: session)
            } else {
                residentSettingsView
            }
        }
        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        .tag(Tab.settings)
        .accessibilityLabel("Settings tab")
    }

    /// A tab whose sole purpose is navigating back to the hero / role-selection page.
    /// The actual navigation is handled in the `.onChange(of: selectedTab)` modifier above.
    @ViewBuilder
    private var switchPanelTab: some View {
        Color.clear
            .tabItem {
                Label(
                    isStaff ? "Resident Panel" : "Switch Panel",
                    systemImage: isStaff ? "bed.double.fill" : "arrow.left.arrow.right.circle.fill"
                )
            }
            .tag(Tab.switchPanel)
            .accessibilityIdentifier("switch_panel_tab")
            .accessibilityLabel(isStaff ? "Switch to Resident Panel" : "Switch to Staff Panel")
            .accessibilityHint("Returns to the home page where you can select the other panel")
    }

    // MARK: - Helpers

    private var isStaff: Bool {
        if case .staff = mode { return true }
        return false
    }

    private var staffUser: StaffUserModel? {
        if case .staff(let s) = mode { return s }
        return nil
    }

    private func staffOnlyPlaceholder(feature: String) -> some View {
        NavigationStack {
            ContentUnavailableView(
                "Staff Only",
                systemImage: "lock.shield",
                description: Text("\(feature) is available when signed in as staff.")
            )
            .navigationTitle(feature)
        }
    }

    private var residentSettingsView: some View {
        List {
            Section("Device") {
                if case .resident(let fid, let rid) = mode {
                    HStack {
                        Text("Facility")
                        Spacer()
                        Text(fid.uuidString.prefix(8) + "…")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Resident")
                        Spacer()
                        Text(rid.uuidString.prefix(8) + "…")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Account") {
                Button(role: .destructive) {
                    session.state = .onboarding
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        }
        .navigationTitle("Settings")
    }

    // MARK: - Handoff

    @ViewBuilder
    private var handoffBanner: some View {
        if case .requestStaff(_, _, let name) = handoff.pendingHandoff, isStaff {
            Button(action: { showHandoffBanner = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "bell.and.waves.left.and.right.fill")
                        .font(.subheadline)
                    Text("\(name) needs assistance")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .padding(12)
                .background(AppTheme.gradientEmeraldRed)
                .foregroundColor(AppTheme.textOnPrimary)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 6)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.spring, value: showHandoffBanner)
            .accessibilityLabel("\(name) has requested staff assistance. Tap to respond.")
        }
    }

    @ViewBuilder
    private var routingSheet: some View {
        if let rid = handoff.routingResidentId, let staff = staffUser {
            let resident = ResidentModel(
                id: rid,
                facilityId: staff.facilityId,
                name: "Resident \(rid.uuidString.prefix(6))",
                riskLevel: nil,
                dateOfBirth: nil
            )
            NavigationStack {
                ResidentOverviewView(resident: resident)
                    .environmentObject(container)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                handoff.routingResidentId = nil
                                showResidentDetail = false
                            }
                        }
                    }
            }
        } else {
            EmptyView()
        }
    }

    private var aiBadgeCount: Int {
        AIMonitoringService.shared.recentEvents.filter { !$0.acknowledged }.count
    }

    private var handoffBadgeCount: Int {
        handoff.pendingHandoff != nil ? 1 : 0
    }
}

// MARK: - Resident Preview (shown to Staff on Home tab)

struct ResidentPreviewForStaff: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(AppTheme.emeraldRed)

                Text("Resident View")
                    .font(.title2.bold())

                Text("This is how residents see the app.\nSwitch to the other tabs to manage alerts, residents, and insights.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    QuickNavRow(icon: "bell.badge.fill", title: "Alerts", description: "View and manage real-time alerts")
                    QuickNavRow(icon: "person.crop.rectangle.badge.plus", title: "Participants", description: "Add and manage participant records")
                    QuickNavRow(icon: "person.badge.key.fill", title: "Bridge", description: "Link participants to staff dashboards")
                    QuickNavRow(icon: "waveform.and.magnifyingglass", title: "AI Monitor", description: "Camera and sensor insights")
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Home")
        }
    }
}

private struct QuickNavRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppTheme.emeraldGreen)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

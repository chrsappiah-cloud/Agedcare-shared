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
        case navigator
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
            navigatorTab
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
            selectedTab = .home
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
            selectedTab = .home
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
            case .staff(let staff):
                ResidentsHomeView(staff: staff)
            }
        }
        .tabItem {
            Label(
                isStaff ? "Residents" : "Home",
                systemImage: isStaff ? "person.3.fill" : "heart.circle.fill"
            )
        }
        .tag(Tab.home)
        .accessibilityLabel(isStaff ? "Residents tab" : "Home tab")
    }

    @ViewBuilder
    private var navigatorTab: some View {
        NavigationStack {
            NavigatorPanelView(
                isStaff: isStaff,
                onSelectTab: { tab in
                    selectedTab = tab
                },
                onSwitchPanel: {
                    selectedTab = .switchPanel
                }
            )
        }
        .tabItem { Label("Navigate", systemImage: "square.grid.2x2.fill") }
        .tag(Tab.navigator)
        .accessibilityLabel("Navigator tab")
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

struct NavigatorPanelView: View {
    let isStaff: Bool
    let onSelectTab: (UnifiedShellView.Tab) -> Void
    let onSwitchPanel: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: isStaff ? "slider.horizontal.3" : "square.grid.2x2.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(AppTheme.emeraldGreen)

                Text(isStaff ? "Staff Navigator" : "Resident Navigator")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.textPrimary)

                Text(
                    isStaff
                    ? "Jump between resident records, alerts, AI monitoring, bridge tools, and settings from one place."
                    : "Move between your home screen, care tools, and the staff/admin interface quickly during testing."
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    NavigatorButton(icon: isStaff ? "person.3.fill" : "heart.circle.fill",
                                    title: isStaff ? "Residents" : "Home",
                                    description: isStaff ? "Resident list, risk levels, and drill-in details" : "Resident monitoring and SOS actions") {
                        onSelectTab(.home)
                    }
                    NavigatorButton(icon: "bell.badge.fill",
                                    title: "Alerts",
                                    description: isStaff ? "View and manage live facility alerts" : "Open the alert panel used during testing") {
                        onSelectTab(.alerts)
                    }
                    NavigatorButton(icon: "person.crop.rectangle.badge.plus",
                                    title: "Participants",
                                    description: "Manage participant records and entries") {
                        onSelectTab(.participants)
                    }
                    NavigatorButton(icon: "person.badge.key.fill",
                                    title: "Bridge",
                                    description: isStaff ? "Link staff to participant and resident workflows" : "Open the staff bridge and shared navigation tools") {
                        onSelectTab(.bridge)
                    }
                    NavigatorButton(icon: "waveform.and.magnifyingglass",
                                    title: "AI Monitor",
                                    description: isStaff ? "Inspect AI events and monitoring sessions" : "Open AI monitoring controls and previews") {
                        onSelectTab(.aiMonitor)
                    }
                    NavigatorButton(icon: "gearshape.fill",
                                    title: "Settings",
                                    description: "Account, care access, and testing preferences") {
                        onSelectTab(.settings)
                    }
                    NavigatorButton(icon: isStaff ? "bed.double.fill" : "person.crop.circle.badge.checkmark",
                                    title: isStaff ? "Switch to Resident Panel" : "Switch to Staff/Admin Panel",
                                    description: "Return to the role selector and open the other interface") {
                        onSwitchPanel()
                    }
                }

                Spacer()
            }
            .padding(.top, 40)
            .padding(.horizontal, 20)
            .navigationTitle("Navigate")
        }
    }
}

private struct NavigatorButton: View {
    let icon: String
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(AppTheme.emeraldGreen)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(AppTheme.textPrimary)
                    Text(description).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(AppTheme.surface)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

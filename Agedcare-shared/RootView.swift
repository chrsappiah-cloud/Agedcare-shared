import SwiftUI

struct RootView: View {
  @EnvironmentObject var container: DependencyContainer
  @StateObject private var session = SessionViewModel()
  @StateObject private var accessibilityManager = AccessibilityManager.shared

  var body: some View {
    Group {
      switch session.state {
      case .onboarding:
        RoleSelectionView()
          .environmentObject(session)
          .environmentObject(accessibilityManager)
      case .loading:
        ZStack {
          AppTheme.background.ignoresSafeArea()
          VStack(spacing: 16) {
            ProgressView()
              .tint(AppTheme.emeraldGreen)
              .scaleEffect(1.3)
            Text("Signing in\u{2026}")
              .foregroundColor(AppTheme.textSecondary)
              .accessibilityLabel("Signing in")
          }
        }
      case .resident(let facilityId, let residentId):
        UnifiedShellView(
          mode: .resident(facilityId: facilityId, residentId: residentId),
          session: session
        )
        .environmentObject(container)
        .environmentObject(HandoffService.shared)
      case .staff(let staff):
        UnifiedShellView(
          mode: .staff(staff),
          session: session
        )
        .environmentObject(container)
        .environmentObject(HandoffService.shared)
      }
    }
    .dynamicTypeSize(...DynamicTypeSize.accessibility5)
  }
}

struct RoleSelectionView: View {
  enum PanelRoute: String, CaseIterable, Identifiable {
    case resident = "Resident"
    case staff = "Staff"
    var id: String { rawValue }
  }

  @EnvironmentObject var session: SessionViewModel
  @EnvironmentObject var accessibilityManager: AccessibilityManager
  @State private var showLogin = false
  @State private var showResidentSetup = false
  @State private var selectedRoute: PanelRoute = .resident

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 28) {
          heroHeader
          panelRouter
          panelCards
          testAccountsFooter
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
      }
      .background(AppTheme.gradientDiamond.ignoresSafeArea())
      .accessibilityElement(children: .contain)
      .sheet(isPresented: $showResidentSetup) {
        ResidentSetupView()
          .environmentObject(session)
      }
      .sheet(isPresented: $showLogin) {
        LoginView()
          .environmentObject(session)
      }
    }
  }

  private var heroHeader: some View {
    VStack(spacing: 6) {
      Image(systemName: "heart.circle.fill")
        .font(.system(size: 50))
        .foregroundColor(AppTheme.emeraldRed)
        .accessibilityHidden(true)

      Text("AgedCare")
        .font(.largeTitle.bold())
        .foregroundColor(AppTheme.textPrimary)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel("Aged Care")

      Text("Compassionate care, connected")
        .font(.subheadline)
        .foregroundColor(AppTheme.darkChocolateLight)

      Text("Choose a panel to continue")
        .font(.callout)
        .foregroundColor(AppTheme.textSecondary)
        .padding(.top, 4)
        .accessibilityLabel("Choose a panel to continue")
    }
  }

  private var panelRouter: some View {
    Picker("Panel", selection: $selectedRoute) {
      ForEach(PanelRoute.allCases) { route in
        Text(route.rawValue).tag(route)
      }
    }
    .pickerStyle(.segmented)
    .accessibilityIdentifier("panel_router")
    .accessibilityHint("Switches between the resident and staff panels")
  }

  private var panelCards: some View {
    VStack(spacing: 16) {
      PanelCard(
        title: "Resident Panel",
        subtitle: session.savedResidentSession != nil
          ? "Continue as configured resident"
          : "Set up bedside device for a resident",
        systemImage: "bed.double.fill",
        accentColor: AppTheme.emeraldRed,
        isHighlighted: selectedRoute == .resident,
        accessibilityIdentifier: "setup_resident",
        accessibilityHint: session.savedResidentSession != nil
          ? "Opens the resident panel directly"
          : "Sets up this device for a resident room",
        action: {
          selectedRoute = .resident
          if let saved = session.savedResidentSession {
            session.setResident(facilityId: saved.facilityId, residentId: saved.residentId)
          } else {
            showResidentSetup = true
          }
        }
      )

      PanelCard(
        title: "Staff Panel",
        subtitle: "Sign in as a staff member",
        systemImage: "person.crop.circle.badge.checkmark",
        accentColor: AppTheme.emeraldGreen,
        isHighlighted: selectedRoute == .staff,
        accessibilityIdentifier: "staff_login",
        accessibilityHint: "Opens the staff sign in screen",
        action: {
          selectedRoute = .staff
          showLogin = true
        }
      )
    }
  }

  private var testAccountsFooter: some View {
    Text("Test accounts: admin@gvcare.com / nurse@gvcare.com / carer@gvcare.com\nPassword: password")
      .font(.caption)
      .foregroundColor(AppTheme.textSecondary)
      .multilineTextAlignment(.center)
      .padding(.top, 8)
      .accessibilityLabel("Test accounts available. Admin, nurse, and carer logins with password password")
  }
}

private struct PanelCard: View {
  let title: String
  let subtitle: String
  let systemImage: String
  let accentColor: Color
  let isHighlighted: Bool
  let accessibilityIdentifier: String
  let accessibilityHint: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 16) {
        Image(systemName: systemImage)
          .font(.system(size: 28))
          .foregroundColor(accentColor)
          .frame(width: 44)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.headline)
            .foregroundColor(AppTheme.textPrimary)
          Text(subtitle)
            .font(.subheadline)
            .foregroundColor(AppTheme.textSecondary)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .font(.callout)
          .foregroundColor(AppTheme.textSecondary)
          .accessibilityHidden(true)
      }
      .padding(18)
      .frame(maxWidth: .infinity)
      .background(AppTheme.surface)
      .cornerRadius(16)
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(accentColor, lineWidth: isHighlighted ? 2.5 : 1)
      )
      .shadow(color: AppTheme.darkChocolate.opacity(isHighlighted ? 0.12 : 0.06), radius: isHighlighted ? 10 : 6, x: 0, y: 4)
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(accessibilityIdentifier)
    .accessibilityHint(accessibilityHint)
    .accessibilityAddTraits(.isButton)
  }
}

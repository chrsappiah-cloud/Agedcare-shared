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
  @StateObject private var backendHealth = BackendHealthService.shared
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
      .task { await backendHealth.refresh() }
    }
  }

  private var heroHeader: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 30)
        .fill(
          LinearGradient(
            colors: [
              Color(red: 0.08, green: 0.10, blue: 0.22),
              Color(red: 0.17, green: 0.38, blue: 0.48),
              Color(red: 0.47, green: 0.16, blue: 0.43)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .overlay {
          RoundedRectangle(cornerRadius: 30)
            .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 24, x: 0, y: 14)

      VStack(alignment: .leading, spacing: 18) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 10) {
            Label("Live care intelligence", systemImage: "sparkles")
              .font(.caption.bold())
              .padding(.horizontal, 12)
              .padding(.vertical, 7)
              .background(.white.opacity(0.16))
              .clipShape(Capsule())

            Text("AgedCare")
              .font(.system(size: 36, weight: .bold, design: .rounded))
              .foregroundStyle(.white)
              .accessibilityAddTraits(.isHeader)
              .accessibilityLabel("Aged Care")

            Text("Futuristic monitoring, premium incident capture, and live staff response in one care platform.")
              .font(.subheadline)
              .foregroundStyle(.white.opacity(0.82))
          }

          Spacer()

          ZStack {
            Circle()
              .fill(.white.opacity(0.10))
              .frame(width: 68, height: 68)
            Image(systemName: "heart.circle.fill")
              .font(.system(size: 34))
              .foregroundStyle(.white)
          }
          .accessibilityHidden(true)
        }

        HStack(spacing: 12) {
          HeroMetricPill(title: "Preview", value: backendHealth.isDemoAccessReady ? "Ready" : "Checking")
          HeroMetricPill(title: "Panels", value: "Resident + Staff")
          HeroMetricPill(title: "Capture", value: "Video + Motion")
        }

        Text("Choose a panel to continue")
          .font(.callout.weight(.semibold))
          .foregroundStyle(.white.opacity(0.92))
          .accessibilityLabel("Choose a panel to continue")
      }
      .padding(24)
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
    VStack(spacing: 6) {
      Text("Preview access: \(backendHealth.demoAccessStatus)")
        .font(.caption)
        .foregroundColor(backendHealth.isDemoAccessReady ? AppTheme.emeraldGreen : AppTheme.warning)
        .multilineTextAlignment(.center)

      if backendHealth.isDemoAccessReady {
        Text("Staff preview sign-in is available now.")
          .font(.caption2)
          .foregroundColor(AppTheme.textSecondary)
          .multilineTextAlignment(.center)
      } else {
        Text("Staff preview sign-in will appear automatically when care access is ready.")
          .font(.caption2)
          .foregroundColor(AppTheme.textSecondary)
          .multilineTextAlignment(.center)
      }

      Text("Creator, administrator, and tester programme access is always available for Starter, Care Pro, and Care Team review.")
        .font(.caption2)
        .foregroundColor(AppTheme.textSecondary)
        .multilineTextAlignment(.center)

      Text("© 2026 World Class Scholars Productions. All rights reserved.")
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.86))
        .multilineTextAlignment(.center)
        .padding(.top, 6)
    }
    .padding(.top, 8)
    .accessibilityLabel("Preview access status: \(backendHealth.demoAccessStatus)")
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
      .background(
        LinearGradient(
          colors: isHighlighted
            ? [accentColor.opacity(0.20), .white.opacity(0.96)]
            : [AppTheme.surface, AppTheme.diamondSilver.opacity(0.18)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .cornerRadius(20)
      .overlay(
        RoundedRectangle(cornerRadius: 20)
          .stroke(accentColor, lineWidth: isHighlighted ? 2.5 : 1)
      )
      .shadow(color: accentColor.opacity(isHighlighted ? 0.20 : 0.08), radius: isHighlighted ? 14 : 8, x: 0, y: 8)
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier(accessibilityIdentifier)
    .accessibilityHint(accessibilityHint)
    .accessibilityAddTraits(.isButton)
  }
}

private struct HeroMetricPill: View {
  let title: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title.uppercased())
        .font(.caption2.bold())
        .foregroundStyle(.white.opacity(0.68))
      Text(value)
        .font(.subheadline.bold())
        .foregroundStyle(.white)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(.white.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }
}

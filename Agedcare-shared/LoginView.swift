import SwiftUI

struct LoginView: View {
  @EnvironmentObject var session: SessionViewModel
  @StateObject private var backendHealth = BackendHealthService.shared
  @State private var email = ""
  @State private var password = ""
  private let isUITestSession =
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    || ProcessInfo.processInfo.environment["UITEST_ADMIN_ACCESS"] == "1"

  private var testingProfiles: [TestingAccessProfile] {
    AppHost.visibleTestingAccessProfiles
  }

  private var uiTestAdminProfile: TestingAccessProfile? {
    AppHost.testingAccessProfile(email: "admin@gvcare.com") ?? AppHost.testingAccessProfiles.first
  }

  private var showPreviewSections: Bool {
    !testingProfiles.isEmpty || !backendHealth.configuredDemoProfiles.isEmpty
  }

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      Image(systemName: "person.badge.key.fill")
        .font(.system(size: 60))
        .foregroundColor(AppTheme.emeraldGreen)
        .accessibilityHidden(true)

      Text("Staff Sign In")
        .font(.title.bold())
        .foregroundColor(AppTheme.textPrimary)
        .accessibilityAddTraits(.isHeader)

      if isUITestSession, let profile = uiTestAdminProfile {
        Button(action: {
          session.signInForTesting(profile)
        }) {
          Label("Instant UI Test Access", systemImage: "bolt.fill")
            .primaryButtonStyle()
        }
        .accessibilityHint("Signs in with the administrator testing profile")
        .accessibilityIdentifier("ui_test_admin_access")
      }

      TextField("Email", text: $email)
        .textContentType(.emailAddress)
        .autocapitalization(.none)
        .keyboardType(.emailAddress)
        .padding(12)
        .background(AppTheme.diamondSilver.opacity(0.25))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.diamondSilver, lineWidth: 1))
        .accessibilityLabel("Email address")
        .accessibilityHint("Enter your email address to sign in")

      SecureField("Password", text: $password)
        .textContentType(.password)
        .padding(12)
        .background(AppTheme.diamondSilver.opacity(0.25))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.diamondSilver, lineWidth: 1))
        .accessibilityLabel("Password")
        .accessibilityHint("Enter your password")

      if let error = session.loginError {
        Text(error)
          .foregroundColor(AppTheme.danger)
          .font(.callout)
          .accessibilityLabel("Login error: \(error)")
      }

      Text(backendHealth.statusSummary)
        .font(.caption)
        .foregroundColor(backendHealth.isHealthy ? AppTheme.emeraldGreen : AppTheme.warning)
        .multilineTextAlignment(.center)

      VStack(spacing: 8) {
        Button(action: {
          Task { await session.login(email: email, password: password) }
        }) {
          Text("Sign In")
            .primaryButtonStyle()
        }
        .disabled(email.isEmpty || password.isEmpty)
        .opacity(email.isEmpty || password.isEmpty ? 0.5 : 1)
        .accessibilityHint("Signs you in with your email and password")
        .accessibilityIdentifier("sign_in_button")

        Text(showPreviewSections
          ? "Use your assigned care account, or continue with the testing programme below."
          : "Use your assigned care account to continue.")
          .font(.caption2)
          .foregroundColor(AppTheme.textSecondary)
      }

      if !testingProfiles.isEmpty {
        Text("Testing Programme Access")
          .font(.subheadline.bold())
          .foregroundColor(AppTheme.darkChocolateLight)
          .padding(.top, 8)
          .accessibilityAddTraits(.isHeader)

        VStack(spacing: 10) {
          Text("Creator, administrator, and tester cohorts are mapped to Starter, Care Pro, and Care Team access during preview review.")
            .font(.caption)
            .foregroundColor(AppTheme.textSecondary)
            .multilineTextAlignment(.center)

          ForEach(testingProfiles) { profile in
            TestingAccessButton(profile: profile, session: session)
          }
        }
        .accessibilityLabel("Subscription testing access")
      }

      if !backendHealth.configuredDemoProfiles.isEmpty {
        Text("Preview Access")
          .font(.subheadline.bold())
          .foregroundColor(AppTheme.darkChocolateLight)
          .padding(.top, 8)
          .accessibilityAddTraits(.isHeader)

        VStack(spacing: 10) {
          Text(backendHealth.demoAccessStatus)
            .font(.caption)
            .foregroundColor(backendHealth.isDemoAccessReady ? AppTheme.emeraldGreen : AppTheme.warning)
            .multilineTextAlignment(.center)

          Text("Preview staff sign-in becomes available automatically when access checks are complete.")
            .font(.caption2)
            .foregroundColor(AppTheme.textSecondary)
            .multilineTextAlignment(.center)

          ForEach(backendHealth.configuredDemoProfiles) { profile in
            DemoButton(profile: profile, session: session, isEnabled: backendHealth.isDemoAccessReady)
          }
        }
        .accessibilityLabel("Demo accounts")
      }

      Button(action: { session.state = .onboarding }) {
        Text("Back")
          .font(.subheadline)
          .foregroundColor(AppTheme.emeraldGreen)
      }
      .accessibilityHint("Returns to the setup screen")

      Spacer()
    }
    .padding(32)
    .background(AppTheme.background)
    .task { await backendHealth.refresh() }
    .accessibilityElement(children: .contain)
  }
}

private struct TestingAccessButton: View {
  let profile: TestingAccessProfile
  let session: SessionViewModel

  var body: some View {
    Button(action: {
      session.signInForTesting(profile)
    }) {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Image(systemName: profile.accessKind == .creator ? "crown.fill" : "person.badge.key.fill")
            .foregroundColor(AppTheme.emeraldGreen)
            .accessibilityHidden(true)
          Text(profile.title)
            .font(.subheadline.bold())
            .foregroundColor(AppTheme.textPrimary)
          Spacer()
          Text(profile.subscriptionTier.name)
            .font(.caption2.bold())
            .foregroundColor(AppTheme.textOnPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppTheme.emeraldGreen)
            .cornerRadius(6)
            .accessibilityHidden(true)
        }

        Text("\(profile.accessKind.label) • \(profile.betaTrack.rawValue)")
          .font(.caption)
          .foregroundColor(AppTheme.textSecondary)

        Text(profile.accessNotes)
          .font(.caption2)
          .foregroundColor(AppTheme.textSecondary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(AppTheme.diamondSilver.opacity(0.2))
      .cornerRadius(8)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Enter as \(profile.title)")
    .accessibilityHint("Signs in using the subscription testing plan")
    .accessibilityIdentifier("testing_\(profile.id)")
  }
}

private struct DemoButton: View {
  let profile: DemoAccessProfile
  let session: SessionViewModel
  let isEnabled: Bool

  var body: some View {
    Button(action: {
      Task { await session.login(email: profile.email, password: profile.password) }
    }) {
      HStack {
        Image(systemName: "person.circle.fill")
          .font(.caption)
          .foregroundColor(AppTheme.emeraldGreen)
          .accessibilityHidden(true)
        Text(profile.title)
          .font(.caption)
          .foregroundColor(isEnabled ? AppTheme.textPrimary : AppTheme.textSecondary)
        Spacer()
        Text(isEnabled ? "Tap" : "Offline")
          .font(.caption2.bold())
          .foregroundColor(AppTheme.textOnPrimary)
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          .background(isEnabled ? AppTheme.emeraldGreen : AppTheme.warning)
          .cornerRadius(6)
          .accessibilityHidden(true)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(AppTheme.diamondSilver.opacity(0.2))
      .cornerRadius(8)
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.65)
    .accessibilityLabel("Sign in as \(profile.title)")
    .accessibilityHint(isEnabled ? "Instantly signs in with a preview account" : "Unavailable while access is being prepared")
    .accessibilityIdentifier("demo_\(profile.title.prefix(5))")
  }
}

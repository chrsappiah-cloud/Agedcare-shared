import SwiftUI

struct PromotionalMaterialsView: View {
    @Environment(\.openURL) private var openURL
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var selectedPlatform: SocialPlatform = .twitter

    enum SocialPlatform: String, CaseIterable, Identifiable {
        case twitter = "Twitter / X"
        case instagram = "Instagram"
        case linkedin = "LinkedIn"
        case facebook = "Facebook"
        case tiktok = "TikTok"
        case threads = "Threads"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .twitter: return "bird.fill"
            case .instagram: return "camera.fill"
            case .linkedin: return "link.circle.fill"
            case .facebook: return "person.2.fill"
            case .tiktok: return "music.note"
            case .threads: return "at.circle.fill"
            }
        }

        var charLimit: Int {
            switch self {
            case .twitter: return 280
            case .linkedin: return 3000
            case .threads: return 500
            default: return 2200
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                platformSelector
                suitePromoSection
                appSpecificPosts
                investorSection
                quickShareSection
                hashtagsSection
            }
            .padding()
        }
        .background(AppTheme.gradientDiamond.ignoresSafeArea())
        .navigationTitle("Promo Materials")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "megaphone.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.emeraldGreen)

            Text("Promotional Materials")
                .font(.title2.bold())
                .foregroundColor(AppTheme.textPrimary)

            Text("Ready-to-post content for all social platforms.\nTap any post to copy or share.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Platform Selector

    private var platformSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SocialPlatform.allCases) { platform in
                    Button {
                        withAnimation { selectedPlatform = platform }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: platform.icon)
                                .font(.caption)
                            Text(platform.rawValue)
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedPlatform == platform ? AppTheme.emeraldGreen : AppTheme.emeraldGreen.opacity(0.12))
                        .foregroundColor(selectedPlatform == platform ? .white : AppTheme.emeraldGreen)
                        .cornerRadius(20)
                    }
                }
            }
        }
    }

    // MARK: - Suite Promo

    private var suitePromoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Suite Announcement", systemImage: "sparkles")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            PostCard(
                title: "App Suite Launch",
                content: suiteAnnouncementPost,
                onShare: { share(suiteAnnouncementPost) }
            )

            PostCard(
                title: "Beta Invite",
                content: betaInvitePost,
                onShare: { share(betaInvitePost) }
            )

            PostCard(
                title: "Pricing Reveal",
                content: pricingPost,
                onShare: { share(pricingPost) }
            )
        }
        .padding()
        .background(AppTheme.surface)
        .cornerRadius(16)
    }

    // MARK: - App-Specific Posts

    private var appSpecificPosts: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Individual App Posts", systemImage: "app.badge.fill")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            ForEach(WCSMarketingConfig.appProducts) { app in
                PostCard(
                    title: app.name,
                    content: appPost(for: app),
                    onShare: { share(appPost(for: app)) }
                )
            }
        }
        .padding()
        .background(AppTheme.surface)
        .cornerRadius(16)
    }

    // MARK: - Investor Section

    private var investorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Investor & Partner Materials", systemImage: "chart.bar.fill")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            PostCard(
                title: "Investor Pitch Post",
                content: investorPitchPost,
                onShare: { share(investorPitchPost) }
            )

            PostCard(
                title: "Partnership Inquiry",
                content: partnershipPost,
                onShare: { share(partnershipPost) }
            )

            PostCard(
                title: "Grant Application Summary",
                content: grantPost,
                onShare: { share(grantPost) }
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Key Metrics for Investors")
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)

                MetricRow(label: "Apps on TestFlight", value: "12")
                MetricRow(label: "Apps Uploaded Today", value: "4")
                MetricRow(label: "Unit Tests Passing", value: "42")
                MetricRow(label: "Beta Tracks Active", value: "6")
                MetricRow(label: "Subscription Tiers", value: "3 (Free / Pro / Team)")
                MetricRow(label: "Target Markets", value: "Health, Education, Creative, Finance")
                MetricRow(label: "Revenue Model", value: "Freemium + SaaS + B2B Pilots")
                MetricRow(label: "Team ID", value: "TM2WG7HH96")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding()
        .background(AppTheme.surface)
        .cornerRadius(16)
    }

    // MARK: - Quick Share

    private var quickShareSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick Share Links", systemImage: "link")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            ForEach([
                ("All Apps", WCSMarketingConfig.allAppsURL),
                ("Website", WCSMarketingConfig.websiteURL),
                ("Personal Link", WCSMarketingConfig.personalLinkURL),
                ("Pricing", WCSMarketingConfig.pricingPageURL),
                ("TestFlight", WCSMarketingConfig.testFlightURL),
                ("Gumroad", WCSMarketingConfig.gumroadURL),
            ], id: \.0) { name, url in
                Button {
                    openURL(url)
                } label: {
                    HStack {
                        Text(name)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Text(url.absoluteString)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(AppTheme.emeraldGreen)
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(AppTheme.surface)
        .cornerRadius(16)
    }

    // MARK: - Hashtags

    private var hashtagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommended Hashtags")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            let hashtags = "#WCS #WorldClassScholars #TestFlight #iOS #SwiftUI #AgedCare #DementiaCare #EdTech #DigitalArt #HealthTech #StartupAustralia #AppDev #BetaTesting #IndieApps #MobileApps #iOSDev #SwiftDev #HealthKit #AI #MachineLearning"

            Text(hashtags)
                .font(.caption)
                .foregroundColor(AppTheme.emeraldGreen)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .onTapGesture {
                    UIPasteboard.general.string = hashtags
                }

            Text("Tap to copy")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(AppTheme.surface)
        .cornerRadius(16)
    }

    // MARK: - Post Content Generators

    private var suiteAnnouncementPost: String {
        switch selectedPlatform {
        case .twitter:
            return """
            We just shipped 12 iOS apps to TestFlight.

            Health. Education. Creative. Finance.

            All free to test. Built by @christopherappi at World Class Scholars.

            Try them: wcs-full.vercel.app/apps

            #TestFlight #iOS #WCS
            """
        case .linkedin:
            return """
            Excited to announce that World Class Scholars has 12 iOS applications live on Apple TestFlight.

            Our suite spans four key sectors:
            - Health & Aged Care (AgedCare Monitor, CareLens, MemoryCanvas)
            - Education (WCS-Platform, medlingo)
            - Creative & Art (EtherealVeil, NeuroCanvas)
            - Finance, Fashion & Productivity (Equity Kombat, African Fashion, GeoWCS, WCSLIB, build-space)

            Each app follows a clear principle: solve a specific problem, ship it finished, learn from real users.

            We're currently in beta with a 12-month growth roadmap, freemium pricing model, and are seeking institutional partners for pilot programs in aged care and education.

            Interested in testing or partnering? Visit wcs-full.vercel.app or reach out directly.

            #HealthTech #EdTech #TestFlight #iOS #StartupAustralia #AgedCare #WCS
            """
        default:
            return """
            12 iOS apps. All on TestFlight. All free to test.

            Health | Education | Creative | Finance

            Built by Dr Christopher Appiah-Thompson at World Class Scholars.

            Download free: wcs-full.vercel.app/apps
            Personal: christopherappiahthompson.link

            #TestFlight #iOS #WCS #BetaTesting #SwiftUI
            """
        }
    }

    private var betaInvitePost: String {
        """
        We're looking for beta testers!

        12 apps on TestFlight covering health, education, art, and finance.

        What you get:
        - Free access to all apps
        - Direct influence on features
        - Early-access pricing when we launch

        What we need:
        - Honest feedback
        - 5 minutes of your time

        Join: wcs-full.vercel.app/apps
        Email: \(WCSMarketingConfig.supportEmail)

        #TestFlight #BetaTesting #WCS
        """
    }

    private var pricingPost: String {
        """
        Our pricing is simple:

        Starter — Free
        Daily routines, mood logs, basic features

        Care Pro — $9.99/mo
        Unlimited profiles, reports, shared notes, premium activities

        Care Team — Custom
        Multi-user staff access, admin dashboard, onboarding support

        Currently free during TestFlight beta. Join the waitlist for early-access pricing.

        wcs-full.vercel.app/pricing

        #WCS #SaaS #Pricing #HealthTech
        """
    }

    private func appPost(for app: WCSAppProduct) -> String {
        if selectedPlatform == .twitter {
            return """
            \(app.name) — \(app.tagline)

            \(app.tier) tier | \(app.price)
            Free on TestFlight now.

            Try it: \(app.testFlightLink.absoluteString)

            #\(app.name.replacingOccurrences(of: " ", with: "")) #TestFlight #WCS
            """
        } else {
            return """
            Introducing \(app.name)

            \(app.tagline)

            Category: \(app.category)
            Tier: \(app.tier) — \(app.price)
            Platform: \(app.platform)

            Currently free on TestFlight beta.

            Try it: \(app.testFlightLink.absoluteString)
            Details: \(app.websitePage.absoluteString)
            Feedback: \(app.feedbackLink.absoluteString)

            Built by @christopherappi | World Class Scholars
            christopherappiahthompson.link

            #\(app.name.replacingOccurrences(of: " ", with: "")) #TestFlight #iOS #WCS
            """
        }
    }

    private var investorPitchPost: String {
        """
        World Class Scholars — 12 iOS apps across Health, Education, Creative, and Finance.

        Traction:
        - 12 apps on Apple TestFlight
        - 42 automated unit tests
        - 6 segmented beta tracks
        - 3-tier monetization (Free / $9.99 Pro / Custom Enterprise)
        - 12-month growth roadmap with institutional pilot strategy

        Market:
        - Global Aged Care: $1.8T by 2030
        - EdTech: $400B+
        - Digital Art Tools: $13B

        Revenue Model: Freemium + SaaS subscriptions + B2B institutional pilots

        We're seeking:
        - Angel investors and grants
        - Institutional partners (care facilities, schools, art programs)
        - Strategic advisors in health tech and education

        Contact: \(WCSMarketingConfig.supportEmail)
        Website: wcs-full.vercel.app
        Founder: christopherappiahthompson.link

        #Investment #HealthTech #EdTech #StartupAustralia
        """
    }

    private var partnershipPost: String {
        """
        Seeking partners for structured 8-12 week pilots.

        If you're a:
        - Care facility or dementia support organization
        - School, university, or education provider
        - Art program or creative institution

        We offer:
        - Free pilot access to our app suite
        - Custom onboarding materials
        - Dedicated pilot success dashboard
        - Clear engagement and satisfaction metrics

        Submit interest: wcs-full.vercel.app/pilot-request
        Or email: \(WCSMarketingConfig.supportEmail)

        #Partnership #Pilot #HealthTech #EdTech #WCS
        """
    }

    private var grantPost: String {
        """
        World Class Scholars is applying for healthcare and education grants.

        Our evidence:
        - 12 functional iOS apps on TestFlight
        - Dementia care tools with routine builder, mood logging, and calming activities
        - Education platform with courses, mentoring, and community
        - AI-powered monitoring with fall detection and HealthKit integration
        - 42 automated tests, CI/CD pipeline, 12-month roadmap

        We're building technology that reduces confusion, saves time, and improves consistency for carers, educators, and creative professionals.

        Contact: \(WCSMarketingConfig.supportEmail)
        Evidence: wcs-full.vercel.app

        #GrantFunding #HealthTech #DementiaCare #EdTech #WCS
        """
    }

    // MARK: - Helpers

    private func share(_ text: String) {
        shareItems = [text]
        showShareSheet = true
    }
}

// MARK: - Post Card

private struct PostCard: View {
    let title: String
    let content: String
    let onShare: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("\(content.count) chars")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(content)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(6)

            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = content
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied!" : "Copy")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(copied ? Color.green.opacity(0.2) : AppTheme.emeraldGreen.opacity(0.12))
                    .foregroundColor(copied ? .green : AppTheme.emeraldGreen)
                    .cornerRadius(8)
                }

                Button(action: onShare) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.emeraldGreen)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

private struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
                .foregroundColor(AppTheme.emeraldGreen)
        }
    }
}

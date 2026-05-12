import Testing
@testable import Agedcare_shared

@Suite("End-to-End Smoke Tests")
struct EndToEndSmokeTests {
    @Test("Testing access profiles resolve through demo resident, timeline, and facility stats layers")
    func testingProfilesResolveAcrossDemoDataLayers() throws {
        let store = DemoResidentStore.shared

        for profile in AppHost.testingAccessProfiles {
            let residents = try #require(store.residents(facilityId: profile.facilityId))
            #expect(!residents.isEmpty)

            let firstResident = residents[0]
            let timeline = try #require(store.timeline(residentId: firstResident.id, limit: 10))
            #expect(!timeline.isEmpty)

            let fallsFromTimeline = timeline.filter { $0.kind == "fall" }.count
            let fallCount = try #require(store.fallCount(residentId: firstResident.id, days: 30))
            #expect(fallCount >= fallsFromTimeline)

            let stats = try #require(store.facilityStats(facilityId: profile.facilityId))
            #expect(stats.open_alerts >= 1)
            #expect(stats.avg_acknowledge_minutes > 0)
        }
    }

    @Test("Testing access sign-in drives the staff shell state and plan mapping")
    @MainActor
    func testingAccessSignInTransitionsToStaffState() throws {
        let session = SessionViewModel()

        for profile in AppHost.testingAccessProfiles {
            session.signInForTesting(profile)

            guard case .staff(let staff) = session.state else {
                Issue.record("Expected staff state for \(profile.email)")
                continue
            }

            #expect(staff.email == profile.email)
            #expect(staff.role == profile.role)
            #expect(staff.facilityId == profile.facilityId)
            #expect(staff.subscriptionTier == profile.subscriptionTier)
            #expect(staff.betaTrack == profile.betaTrack)
            #expect(staff.accessSource == .localTesting)
        }
    }

    @Test("Backend RPC contract stays complete and duplicate-free")
    func backendRPCContractRemainsComplete() {
        let expectedRPCs: Set<String> = [
            "acknowledge_alert",
            "close_alert",
            "create_fall_alert",
            "create_handoff_request",
            "create_sos_alert",
            "get_facility_stats",
            "get_fall_summary_for_resident",
            "get_open_alerts_for_facility",
            "get_pending_handoffs",
            "get_resident_timeline",
            "get_residents_for_facility",
            "get_staff_info",
            "record_vital_event",
            "resolve_handoff_request",
        ]

        #expect(Set(BackendHealthService.requiredRPCs) == expectedRPCs)
        #expect(Set(BackendHealthService.requiredRPCs).count == BackendHealthService.requiredRPCs.count)
    }

    @Test("Default resident demo facility is backed by seeded residents")
    func defaultResidentFacilityRemainsSeeded() throws {
        let facilityId = try #require(AppHost.defaultResidentDemoFacilityID)
        let residents = try #require(DemoResidentStore.shared.residents(facilityId: facilityId))
        #expect(residents.count >= 3)
        #expect(residents.contains { ($0.risk_level ?? "").isEmpty == false })
    }
}

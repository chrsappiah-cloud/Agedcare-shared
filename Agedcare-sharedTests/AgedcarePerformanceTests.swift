import XCTest
@testable import Agedcare_shared

final class AgedcarePerformanceTests: XCTestCase {
    func testDemoResidentStoreLookupPerformance() {
        let store = DemoResidentStore.shared
        let profiles = AppHost.testingAccessProfiles

        measure {
            for _ in 0..<200 {
                for profile in profiles {
                    _ = store.residents(facilityId: profile.facilityId)
                    if let residentId = store.residents(facilityId: profile.facilityId)?.first?.id {
                        _ = store.timeline(residentId: residentId, limit: 10)
                        _ = store.fallCount(residentId: residentId, days: 30)
                    }
                    _ = store.facilityStats(facilityId: profile.facilityId)
                }
            }
        }
    }

    func testTestingAccessLookupPerformance() {
        let emails = AppHost.testingAccessProfiles.map(\.email)

        measure {
            for _ in 0..<500 {
                for email in emails {
                    _ = AppHost.testingAccessProfile(email: email)
                }
            }
        }
    }
}

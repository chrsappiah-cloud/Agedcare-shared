import Foundation
import Combine
import UIKit

// MARK: - Stakeholder model
struct Stakeholder: Identifiable, Codable, Equatable {
    let id: UUID
    var firstName: String
    var lastName: String
    var dateOfBirth: Date?
    var gender: Gender
    var phoneNumber: String
    var email: String
    var classification: Classification
    var role: String
    var department: String
    var qualifications: String
    var employmentType: EmploymentType
    var startDate: Date
    var emergencyContactName: String
    var emergencyContactPhone: String
    var notes: String
    var isActive: Bool
    var photoData: Data?

    var fullName: String { "\(firstName) \(lastName)" }
    var isClinical: Bool { classification == .clinical }

    enum Gender: String, Codable, CaseIterable, Identifiable {
        case male = "Male"
        case female = "Female"
        case other = "Other"
        case preferNotToSay = "Prefer not to say"
        var id: String { rawValue }
    }

    enum Classification: String, Codable, CaseIterable, Identifiable {
        case clinical = "Clinical"
        case nonClinical = "Non-Clinical"
        var id: String { rawValue }
    }

    enum EmploymentType: String, Codable, CaseIterable, Identifiable {
        case fullTime = "Full-Time"
        case partTime = "Part-Time"
        case casual = "Casual"
        case contractor = "Contractor"
        case volunteer = "Volunteer"
        var id: String { rawValue }
    }

    static func blank() -> Stakeholder {
        Stakeholder(
            id: UUID(),
            firstName: "",
            lastName: "",
            dateOfBirth: nil,
            gender: .preferNotToSay,
            phoneNumber: "",
            email: "",
            classification: .clinical,
            role: "",
            department: "",
            qualifications: "",
            employmentType: .fullTime,
            startDate: Date(),
            emergencyContactName: "",
            emergencyContactPhone: "",
            notes: "",
            isActive: true,
            photoData: nil
        )
    }
}

// MARK: - Store
@MainActor
final class StakeholderStore: ObservableObject {
    static let shared = StakeholderStore()

    @Published var stakeholders: [Stakeholder] = [] {
        didSet { persist() }
    }

    private let storageKey = "wcs.agedcare.stakeholders"

    init() { load() }

    func add(_ s: Stakeholder) { stakeholders.append(s) }

    func update(_ s: Stakeholder) {
        guard let idx = stakeholders.firstIndex(where: { $0.id == s.id }) else { return }
        stakeholders[idx] = s
    }

    func delete(id: UUID) { stakeholders.removeAll { $0.id == id } }

    func stakeholder(for id: UUID) -> Stakeholder? { stakeholders.first { $0.id == id } }

    func clinical() -> [Stakeholder] { stakeholders.filter { $0.isClinical && $0.isActive } }
    func nonClinical() -> [Stakeholder] { stakeholders.filter { !$0.isClinical && $0.isActive } }

    private func persist() {
        guard let data = try? JSONEncoder().encode(stakeholders) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode([Stakeholder].self, from: data) else { return }
        stakeholders = stored
    }
}

import Foundation
import Combine
import UIKit

struct Participant: Identifiable, Codable, Equatable {
    let id: UUID
    var firstName: String
    var lastName: String
    var dateOfBirth: Date?
    var gender: Gender
    var roomNumber: String
    var phoneNumber: String
    var riskLevel: RiskLevel
    var medicalNotes: String
    var allergies: String
    var medications: String
    var mobilityStatus: MobilityStatus
    var dietaryRequirements: String
    var emergencyContactName: String
    var emergencyContactPhone: String
    var emergencyContactRelation: String
    var secondaryContactName: String
    var secondaryContactPhone: String
    var gpName: String
    var gpPhone: String
    var admissionDate: Date
    var linkedStaffIds: [UUID]
    var isActive: Bool
    var photoData: Data?

    var fullName: String { "\(firstName) \(lastName)" }

    enum Gender: String, Codable, CaseIterable, Identifiable {
        case male = "Male"
        case female = "Female"
        case other = "Other"
        case preferNotToSay = "Prefer not to say"
        var id: String { rawValue }
    }

    enum RiskLevel: String, Codable, CaseIterable, Identifiable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"
        var id: String { rawValue }

        var color: String {
            switch self {
            case .low: return "green"
            case .medium: return "orange"
            case .high: return "red"
            case .critical: return "purple"
            }
        }
    }

    enum MobilityStatus: String, Codable, CaseIterable, Identifiable {
        case independent = "Independent"
        case assistedWalking = "Assisted Walking"
        case wheelchair = "Wheelchair"
        case bedBound = "Bed-bound"
        var id: String { rawValue }
    }

    static func blank() -> Participant {
        Participant(
            id: UUID(),
            firstName: "",
            lastName: "",
            dateOfBirth: nil,
            gender: .preferNotToSay,
            roomNumber: "",
            phoneNumber: "",
            riskLevel: .low,
            medicalNotes: "",
            allergies: "",
            medications: "",
            mobilityStatus: .independent,
            dietaryRequirements: "",
            emergencyContactName: "",
            emergencyContactPhone: "",
            emergencyContactRelation: "",
            secondaryContactName: "",
            secondaryContactPhone: "",
            gpName: "",
            gpPhone: "",
            admissionDate: Date(),
            linkedStaffIds: [],
            isActive: true,
            photoData: nil
        )
    }
}

@MainActor
final class ParticipantStore: ObservableObject {
    static let shared = ParticipantStore()

    @Published var participants: [Participant] = [] {
        didSet { persist() }
    }

    private let storageKey = "wcs.agedcare.participants"

    init() {
        load()
    }

    func add(_ participant: Participant) {
        participants.append(participant)
    }

    func update(_ participant: Participant) {
        guard let idx = participants.firstIndex(where: { $0.id == participant.id }) else { return }
        participants[idx] = participant
    }

    func delete(id: UUID) {
        participants.removeAll { $0.id == id }
    }

    func participant(for id: UUID) -> Participant? {
        participants.first { $0.id == id }
    }

    func linkStaff(_ staffId: UUID, to participantId: UUID) {
        guard let idx = participants.firstIndex(where: { $0.id == participantId }) else { return }
        if !participants[idx].linkedStaffIds.contains(staffId) {
            participants[idx].linkedStaffIds.append(staffId)
        }
    }

    func unlinkStaff(_ staffId: UUID, from participantId: UUID) {
        guard let idx = participants.firstIndex(where: { $0.id == participantId }) else { return }
        participants[idx].linkedStaffIds.removeAll { $0 == staffId }
    }

    func participantsLinkedTo(staffId: UUID) -> [Participant] {
        participants.filter { $0.linkedStaffIds.contains(staffId) }
    }

    func activeParticipants() -> [Participant] {
        participants.filter { $0.isActive }
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(participants) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let stored = try? JSONDecoder().decode([Participant].self, from: data) else { return }
        participants = stored
    }
}

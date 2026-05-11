import SwiftUI

struct ParticipantFormView: View {
    enum Mode {
        case add
        case edit(Participant)
    }

    let mode: Mode
    let onSave: (Participant) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -75, to: Date()) ?? Date()
    @State private var hasDOB = false
    @State private var gender: Participant.Gender = .preferNotToSay
    @State private var roomNumber = ""
    @State private var phoneNumber = ""
    @State private var riskLevel: Participant.RiskLevel = .low
    @State private var medicalNotes = ""
    @State private var allergies = ""
    @State private var medications = ""
    @State private var mobilityStatus: Participant.MobilityStatus = .independent
    @State private var dietaryRequirements = ""
    @State private var emergencyContactName = ""
    @State private var emergencyContactPhone = ""
    @State private var emergencyContactRelation = ""
    @State private var secondaryContactName = ""
    @State private var secondaryContactPhone = ""
    @State private var gpName = ""
    @State private var gpPhone = ""
    @State private var admissionDate = Date()
    @State private var isActive = true
    @State private var showPhotoPicker = false
    @State private var profileImage: UIImage?
    @State private var currentSection = 0

    private var participantId: UUID

    init(mode: Mode, onSave: @escaping (Participant) -> Void) {
        self.mode = mode
        self.onSave = onSave
        switch mode {
        case .add:
            self.participantId = UUID()
        case .edit(let p):
            self.participantId = p.id
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                progressHeader

                Section("Photo") {
                    photoSection
                }

                Section("Personal Details") {
                    personalSection
                }

                Section("Medical Information") {
                    medicalSection
                }

                Section("Emergency Contacts") {
                    emergencySection
                }

                Section("GP / Doctor") {
                    gpSection
                }

                Section("Administration") {
                    adminSection
                }
            }
            .navigationTitle(isEditing ? "Edit Participant" : "New Participant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                        .fontWeight(.bold)
                }
            }
            .onAppear { populateIfEditing() }
            .sheet(isPresented: $showPhotoPicker) {
                ImagePicker(sourceType: .photoLibrary, onPick: { image in
                    profileImage = image
                }, onCancel: {})
            }
        }
    }

    // MARK: - Progress

    private var progressHeader: some View {
        Section {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(0..<6, id: \.self) { idx in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(sectionComplete(idx) ? AppTheme.emeraldGreen : AppTheme.emeraldGreen.opacity(0.15))
                            .frame(height: 4)
                    }
                }
                Text("\(completedSections)/6 sections complete")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Photo

    private var photoSection: some View {
        HStack {
            Spacer()
            Button { showPhotoPicker = true } label: {
                if let img = profileImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 90)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(AppTheme.emeraldGreen, lineWidth: 2))
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.circle.fill")
                                .font(.title3)
                                .foregroundColor(AppTheme.emeraldGreen)
                                .background(Circle().fill(.white).padding(2))
                        }
                } else {
                    ZStack {
                        Circle()
                            .fill(AppTheme.emeraldGreen.opacity(0.1))
                            .frame(width: 90, height: 90)
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundColor(AppTheme.emeraldGreen)
                    }
                }
            }
            Spacer()
        }
    }

    // MARK: - Personal

    private var personalSection: some View {
        Group {
            TextField("First Name *", text: $firstName)
                .textContentType(.givenName)
                .autocorrectionDisabled()
            TextField("Last Name *", text: $lastName)
                .textContentType(.familyName)
                .autocorrectionDisabled()
            Picker("Gender", selection: $gender) {
                ForEach(Participant.Gender.allCases) { g in
                    Text(g.rawValue).tag(g)
                }
            }
            Toggle("Date of Birth Known", isOn: $hasDOB)
            if hasDOB {
                DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
            }
            TextField("Room Number", text: $roomNumber)
                .keyboardType(.default)
            TextField("Phone Number", text: $phoneNumber)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
        }
    }

    // MARK: - Medical

    private var medicalSection: some View {
        Group {
            Picker("Risk Level", selection: $riskLevel) {
                ForEach(Participant.RiskLevel.allCases) { level in
                    HStack {
                        Circle()
                            .fill(riskColor(level))
                            .frame(width: 10, height: 10)
                        Text(level.rawValue)
                    }
                    .tag(level)
                }
            }
            Picker("Mobility", selection: $mobilityStatus) {
                ForEach(Participant.MobilityStatus.allCases) { status in
                    Text(status.rawValue).tag(status)
                }
            }
            TextField("Allergies", text: $allergies, axis: .vertical)
                .lineLimit(2...4)
            TextField("Current Medications", text: $medications, axis: .vertical)
                .lineLimit(2...4)
            TextField("Dietary Requirements", text: $dietaryRequirements, axis: .vertical)
                .lineLimit(2...4)
            TextField("Medical Notes", text: $medicalNotes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    // MARK: - Emergency

    private var emergencySection: some View {
        Group {
            TextField("Contact Name *", text: $emergencyContactName)
                .textContentType(.name)
            TextField("Phone *", text: $emergencyContactPhone)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
            TextField("Relationship", text: $emergencyContactRelation)
            TextField("Secondary Contact Name", text: $secondaryContactName)
                .textContentType(.name)
            TextField("Secondary Phone", text: $secondaryContactPhone)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
        }
    }

    // MARK: - GP

    private var gpSection: some View {
        Group {
            TextField("GP / Doctor Name", text: $gpName)
                .textContentType(.name)
            TextField("GP Phone", text: $gpPhone)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
        }
    }

    // MARK: - Admin

    private var adminSection: some View {
        Group {
            DatePicker("Admission Date", selection: $admissionDate, displayedComponents: .date)
            Toggle("Active Participant", isOn: $isActive)
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !emergencyContactName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !emergencyContactPhone.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    // MARK: - Progress Tracking

    private func sectionComplete(_ idx: Int) -> Bool {
        switch idx {
        case 0: return profileImage != nil
        case 1: return !firstName.isEmpty && !lastName.isEmpty
        case 2: return true
        case 3: return !emergencyContactName.isEmpty && !emergencyContactPhone.isEmpty
        case 4: return !gpName.isEmpty
        case 5: return true
        default: return false
        }
    }

    private var completedSections: Int {
        (0..<6).filter { sectionComplete($0) }.count
    }

    // MARK: - Save

    private func save() {
        let participant = Participant(
            id: participantId,
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            dateOfBirth: hasDOB ? dateOfBirth : nil,
            gender: gender,
            roomNumber: roomNumber,
            phoneNumber: phoneNumber,
            riskLevel: riskLevel,
            medicalNotes: medicalNotes,
            allergies: allergies,
            medications: medications,
            mobilityStatus: mobilityStatus,
            dietaryRequirements: dietaryRequirements,
            emergencyContactName: emergencyContactName,
            emergencyContactPhone: emergencyContactPhone,
            emergencyContactRelation: emergencyContactRelation,
            secondaryContactName: secondaryContactName,
            secondaryContactPhone: secondaryContactPhone,
            gpName: gpName,
            gpPhone: gpPhone,
            admissionDate: admissionDate,
            linkedStaffIds: existingLinkedStaff,
            isActive: isActive,
            photoData: profileImage?.jpegData(compressionQuality: 0.7)
        )
        onSave(participant)
        dismiss()
    }

    private var existingLinkedStaff: [UUID] {
        if case .edit(let p) = mode { return p.linkedStaffIds }
        return []
    }

    private func populateIfEditing() {
        guard case .edit(let p) = mode else { return }
        firstName = p.firstName
        lastName = p.lastName
        if let dob = p.dateOfBirth {
            dateOfBirth = dob
            hasDOB = true
        }
        gender = p.gender
        roomNumber = p.roomNumber
        phoneNumber = p.phoneNumber
        riskLevel = p.riskLevel
        medicalNotes = p.medicalNotes
        allergies = p.allergies
        medications = p.medications
        mobilityStatus = p.mobilityStatus
        dietaryRequirements = p.dietaryRequirements
        emergencyContactName = p.emergencyContactName
        emergencyContactPhone = p.emergencyContactPhone
        emergencyContactRelation = p.emergencyContactRelation
        secondaryContactName = p.secondaryContactName
        secondaryContactPhone = p.secondaryContactPhone
        gpName = p.gpName
        gpPhone = p.gpPhone
        admissionDate = p.admissionDate
        isActive = p.isActive
        if let data = p.photoData {
            profileImage = UIImage(data: data)
        }
    }

    private func riskColor(_ level: Participant.RiskLevel) -> Color {
        switch level {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
}

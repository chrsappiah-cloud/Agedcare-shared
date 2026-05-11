import SwiftUI

struct AddStakeholderView: View {
    enum Mode { case add; case edit(Stakeholder) }

    let mode: Mode
    let onSave: (Stakeholder) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -35, to: Date()) ?? Date()
    @State private var hasDOB = false
    @State private var gender: Stakeholder.Gender = .preferNotToSay
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var classification: Stakeholder.Classification = .clinical
    @State private var role = ""
    @State private var department = ""
    @State private var qualifications = ""
    @State private var employmentType: Stakeholder.EmploymentType = .fullTime
    @State private var startDate = Date()
    @State private var emergencyContactName = ""
    @State private var emergencyContactPhone = ""
    @State private var notes = ""
    @State private var isActive = true
    @State private var showPhotoPicker = false
    @State private var profileImage: UIImage?

    private var stakeholderId: UUID
    private var isEditing: Bool { if case .edit = mode { return true }; return false }
    private var isValid: Bool { !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
                                !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
                                !role.trimmingCharacters(in: .whitespaces).isEmpty }

    init(mode: Mode, onSave: @escaping (Stakeholder) -> Void) {
        self.mode = mode
        self.onSave = onSave
        self.stakeholderId = { if case .edit(let s) = mode { return s.id }; return UUID() }()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    HStack {
                        Spacer()
                        photoThumb
                            .onTapGesture { showPhotoPicker = true }
                        Spacer()
                    }
                }
                Section("Personal Details") { personalSection }
                Section("Role & Employment") { roleSection }
                Section("Emergency Contact") { emergencySection }
                Section("Notes") {
                    TextEditor(text: $notes).frame(minHeight: 80)
                }
                Section {
                    Toggle("Active", isOn: $isActive)
                }
            }
            .navigationTitle(isEditing ? "Edit Stakeholder" : "New Stakeholder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!isValid).fontWeight(.bold)
                }
            }
            .onAppear { populateIfEditing() }
            .sheet(isPresented: $showPhotoPicker) {
                ImagePicker(sourceType: .photoLibrary, onPick: { profileImage = $0 }, onCancel: {})
            }
        }
    }

    @ViewBuilder private var photoThumb: some View {
        if let img = profileImage {
            Image(uiImage: img).resizable().scaledToFill()
                .frame(width: 80, height: 80).clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill.badge.plus")
                .font(.system(size: 60)).foregroundStyle(AppTheme.emeraldGreen)
        }
    }

    @ViewBuilder private var personalSection: some View {
        TextField("First Name", text: $firstName)
        TextField("Last Name", text: $lastName)
        Picker("Gender", selection: $gender) {
            ForEach(Stakeholder.Gender.allCases) { Text($0.rawValue).tag($0) }
        }
        Toggle("Date of Birth", isOn: $hasDOB)
        if hasDOB { DatePicker("DOB", selection: $dateOfBirth, displayedComponents: .date) }
        TextField("Phone", text: $phoneNumber).keyboardType(.phonePad)
        TextField("Email", text: $email).keyboardType(.emailAddress).autocapitalization(.none)
    }

    @ViewBuilder private var roleSection: some View {
        Picker("Classification", selection: $classification) {
            ForEach(Stakeholder.Classification.allCases) { Text($0.rawValue).tag($0) }
        }.pickerStyle(.segmented)
        TextField("Job Title / Role", text: $role)
        TextField("Department", text: $department)
        TextField("Qualifications / Credentials", text: $qualifications)
        Picker("Employment Type", selection: $employmentType) {
            ForEach(Stakeholder.EmploymentType.allCases) { Text($0.rawValue).tag($0) }
        }
        DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
    }

    @ViewBuilder private var emergencySection: some View {
        TextField("Contact Name", text: $emergencyContactName)
        TextField("Contact Phone", text: $emergencyContactPhone).keyboardType(.phonePad)
    }

    private func save() {
        let s = Stakeholder(
            id: stakeholderId,
            firstName: firstName, lastName: lastName,
            dateOfBirth: hasDOB ? dateOfBirth : nil,
            gender: gender, phoneNumber: phoneNumber, email: email,
            classification: classification, role: role, department: department,
            qualifications: qualifications, employmentType: employmentType,
            startDate: startDate,
            emergencyContactName: emergencyContactName,
            emergencyContactPhone: emergencyContactPhone,
            notes: notes, isActive: isActive,
            photoData: profileImage.flatMap { $0.jpegData(compressionQuality: 0.7) }
        )
        onSave(s); dismiss()
    }

    private func populateIfEditing() {
        guard case .edit(let s) = mode else { return }
        firstName = s.firstName; lastName = s.lastName
        if let dob = s.dateOfBirth { hasDOB = true; dateOfBirth = dob }
        gender = s.gender; phoneNumber = s.phoneNumber; email = s.email
        classification = s.classification; role = s.role; department = s.department
        qualifications = s.qualifications; employmentType = s.employmentType
        startDate = s.startDate
        emergencyContactName = s.emergencyContactName
        emergencyContactPhone = s.emergencyContactPhone
        notes = s.notes; isActive = s.isActive
        if let d = s.photoData { profileImage = UIImage(data: d) }
    }
}

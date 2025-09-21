import SwiftUI

struct AddDealView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel

    @State private var dealKind: DealKind = .service
    @State private var dealName: String = ""
    @State private var discount: String = ""
    @State private var description: String = ""
    @State private var location: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var hasEndDate: Bool = true

    @State private var showFinalConfirmation = false
    @State private var showSubmissionSheet = false
    @State private var isSubmitting = false
    @State private var invalidFields: Set<String> = []
    @State private var submissionErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Deal Details") {
                    Picker("Type", selection: $dealKind) {
                        ForEach(DealKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }

                    TextField("Deal Name", text: $dealName)
                        .modifier(ValidationHighlight(isInvalid: invalidFields.contains("name")))

                    TextField("Discount (e.g. 20% off)", text: $discount)
                        .modifier(ValidationHighlight(isInvalid: invalidFields.contains("discount")))

                    TextField("Location (optional)", text: $location)
                }

                Section("Timing") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .modifier(ValidationHighlight(isInvalid: invalidFields.contains("start")))

                    Toggle("Has an end date", isOn: $hasEndDate)

                    if hasEndDate {
                        DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                            .modifier(ValidationHighlight(isInvalid: invalidFields.contains("end")))
                    }

                    Text(validitySummary)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Section("Description") {
                    TextField("Describe the deal", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .modifier(ValidationHighlight(isInvalid: invalidFields.contains("description")))
                }

                Section {
                    Button {
                        validate()
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text("Send")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
            .navigationTitle("New Deal")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Submit Deal?", isPresented: $showFinalConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Send", role: .destructive) {
                    submitDeal()
                }
            } message: {
                Text("We'll review this deal before publishing it to students.")
            }
            .sheet(isPresented: $showSubmissionSheet) {
                SubmissionConfirmationView { dismiss() }
            }
            .alert("Submission Failed", isPresented: Binding(
                get: { submissionErrorMessage != nil },
                set: { newValue in
                    if !newValue { submissionErrorMessage = nil }
                }
            )) {
                Button("OK", role: .cancel) { submissionErrorMessage = nil }
            } message: {
                Text(submissionErrorMessage ?? "An unknown error occurred.")
            }
        }
    }

    private var normalizedStartDate: Date {
        Calendar.current.startOfDay(for: startDate)
    }

    private var normalizedEndDate: Date? {
        guard hasEndDate else { return nil }
        let calendar = Calendar.current
        let startOfSelectedDay = calendar.startOfDay(for: endDate)
        let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfSelectedDay) ?? startOfSelectedDay
        if endOfDay < normalizedStartDate {
            return normalizedStartDate
        }
        return endOfDay
    }

    private var validitySummary: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let startString = formatter.string(from: normalizedStartDate)

        if let end = normalizedEndDate {
            if end == normalizedStartDate {
                return "Valid on \(startString)"
            }
            let endString = formatter.string(from: end)
            return "Valid from \(startString) to \(endString)"
        }

        return "Valid starting \(startString)"
    }

    private func validate() {
        guard !isSubmitting else { return }

        var missing: Set<String> = []

        if dealName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.insert("name")
        }

        if discount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.insert("discount")
        }

        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            missing.insert("description")
        }

        if hasEndDate && (normalizedEndDate ?? normalizedStartDate) < normalizedStartDate {
            missing.insert("end")
        }

        invalidFields = missing

        if missing.isEmpty {
            showFinalConfirmation = true
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation {
                    invalidFields.removeAll()
                }
            }
        }
    }

    private func submitDeal() {
        guard !isSubmitting else { return }
        guard let token = authViewModel.token else {
            submissionErrorMessage = "You need to be logged in to submit a deal."
            return
        }

        guard let email = authViewModel.loggedInEmail ?? (authViewModel.email.isEmpty ? nil : authViewModel.email) else {
            submissionErrorMessage = "We couldn't determine your email address. Please try logging in again."
            return
        }

        let payload = DealSubmissionPayload(
            name: dealName.trimmingCharacters(in: .whitespacesAndNewlines),
            type: dealKind.rawValue,
            discount: discount.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: normalizedStartDate,
            endDate: normalizedEndDate
        )

        isSubmitting = true

        Task {
            do {
                try await APIService.shared.submitDeal(payload: payload, token: token, creatorEmail: email.lowercased())
                await MainActor.run {
                    showSubmissionSheet = true
                }
            } catch {
                await MainActor.run {
                    submissionErrorMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                isSubmitting = false
            }
        }
    }
}

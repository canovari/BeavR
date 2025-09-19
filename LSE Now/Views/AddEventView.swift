import SwiftUI
import MapKit

// MARK: - Draft model
struct PostDraft {
    var title: String
    var startTime: Date
    var endTime: Date?
    var location: String
    var description: String
    var organization: String
    var category: String
    var contact: ContactInfo
    var latitude: Double
    var longitude: Double
    var creator: String
}

// MARK: - AddEventView
struct AddEventView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel

    // Event fields
    @State private var title = ""
    @State private var startDate = Date()
    @State private var startTime = Date()
    @State private var durationHours = 1
    @State private var durationMinutes = 0
    @State private var locationQuery = ""
    @State private var description = ""
    @State private var organization = ""
    @State private var category = ""
    @State private var contact: ContactInfo?

    // Confirmation & validation
    @State private var showFinalConfirmation = false
    @State private var showSubmissionSheet = false
    @State private var invalidFields: Set<String> = []
    @State private var pickedCoordinate: CLLocationCoordinate2D?
    @FocusState private var focusedField: String?
    @State private var isSubmitting = false
    @State private var submissionErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                // Title
                TextField("Event Title", text: $title)
                    .modifier(ValidationHighlight(isInvalid: invalidFields.contains("title")))
                    .focused($focusedField, equals: "title")

                // Date + Time
                DatePicker("Date", selection: $startDate, displayedComponents: .date)
                    .modifier(ValidationHighlight(isInvalid: invalidFields.contains("date")))

                DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    .modifier(ValidationHighlight(isInvalid: invalidFields.contains("startTime")))
                    .focused($focusedField, equals: "time")

                Section("Duration") {
                    DurationPickerView(
                        hours: $durationHours,
                        minutes: $durationMinutes,
                        isInvalid: invalidFields.contains("duration")
                    )

                    Text(durationDescription)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                // Location & Map Pin
                NavigationLink {
                    ConfirmEventSpotView(
                        initialCoordinate: pickedCoordinate,
                        locationText: $locationQuery
                    ) { coordinate in
                        pickedCoordinate = coordinate
                    }
                } label: {
                    HStack {
                        Text("Map Pin")
                        Spacer()
                        if !locationQuery.isEmpty {
                            Text(locationQuery)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(2)
                                .font(.callout)
                        } else if pickedCoordinate != nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                .modifier(ValidationHighlight(
                    isInvalid: invalidFields.contains("mapPin") || invalidFields.contains("location")
                ))

                // Category
                NavigationLink {
                    CategorySelectionView(selectedCategory: $category)
                } label: {
                    HStack {
                        Text("Category")
                        Spacer()
                        Text(category)
                            .foregroundColor(.secondary)
                    }
                }
                .modifier(ValidationHighlight(isInvalid: invalidFields.contains("category")))

                // Hosted by
                TextField("Hosted by", text: $organization)
                    .modifier(ValidationHighlight(isInvalid: invalidFields.contains("organization")))
                    .focused($focusedField, equals: "organization")

                // Contact
                NavigationLink {
                    EventContactView(contact: $contact)
                } label: {
                    HStack {
                        Text("Contact")
                        Spacer()
                        if let c = contact {
                            Text("\(c.type): \(c.displayValue)")
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("Not set")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .modifier(ValidationHighlight(isInvalid: invalidFields.contains("contact")))

                // Description
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(nil)
                    .modifier(ValidationHighlight(isInvalid: invalidFields.contains("description")))
                    .focused($focusedField, equals: "description")

                // Send
                Section {
                    Button {
                        validateFields()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Send")
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.large)
            .scrollDismissesKeyboard(.immediately)
            .alert("Send Event?", isPresented: $showFinalConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Send", role: .destructive) {
                    actuallySend()
                }
            } message: {
                Text("Are you sure you want to send this event for review?")
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
                Button("OK", role: .cancel) {
                    submissionErrorMessage = nil
                }
            } message: {
                Text(submissionErrorMessage ?? "An unknown error occurred.")
            }
        }
    }

    // MARK: - Validation
    private func validateFields() {
        guard !isSubmitting else { return }

        submissionErrorMessage = nil

        var missing: Set<String> = []
        if title.isEmpty { missing.insert("title") }
        if locationQuery.isEmpty { missing.insert("location") }
        if pickedCoordinate == nil { missing.insert("mapPin") }
        if category.isEmpty { missing.insert("category") }
        if organization.isEmpty { missing.insert("organization") }
        if contact == nil { missing.insert("contact") }
        if description.isEmpty { missing.insert("description") }
        if durationTotalSeconds <= 0 { missing.insert("duration") }

        if missing.isEmpty {
            showFinalConfirmation = true
        } else {
            withAnimation { invalidFields = missing }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation { invalidFields.removeAll() }
            }
        }
    }

    // MARK: - Actually send
    private func actuallySend() {
        guard let coord = pickedCoordinate, let contact = contact else { return }
        guard let token = authViewModel.token else {
            submissionErrorMessage = "You need to be logged in to submit an event."
            return
        }

        guard let email = authViewModel.loggedInEmail ?? (authViewModel.email.isEmpty ? nil : authViewModel.email) else {
            submissionErrorMessage = "We couldn't determine your email address. Please try logging in again."
            return
        }

        let normalizedEmail = email.lowercased()

        let startDateTime = merge(date: startDate, time: startTime)
        let totalDurationSeconds = durationTotalSeconds
        let computedEndTime = totalDurationSeconds > 0 ? startDateTime.addingTimeInterval(TimeInterval(totalDurationSeconds)) : nil

        let draft = PostDraft(
            title: title,
            startTime: startDateTime,
            endTime: computedEndTime,
            location: locationQuery,
            description: description,
            organization: organization,
            category: category,
            contact: contact,
            latitude: coord.latitude,
            longitude: coord.longitude,
            creator: normalizedEmail
        )

        isSubmitting = true

        Task {
            do {
                try await APIService.shared.submitEvent(draft: draft, token: token)
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

    private func merge(date: Date, time: Date) -> Date {
        let cal = Calendar.current
        let d = cal.dateComponents([.year, .month, .day], from: date)
        let t = cal.dateComponents([.hour, .minute], from: time)
        return cal.date(from: DateComponents(
            year: d.year, month: d.month, day: d.day,
            hour: t.hour, minute: t.minute)) ?? date
    }

    private var durationTotalSeconds: Int {
        max(0, (durationHours * 3600) + (durationMinutes * 60))
    }

    private var durationDescription: String {
        let total = durationTotalSeconds
        guard total > 0 else {
            return "Select how long the event lasts."
        }

        var parts: [String] = []
        if durationHours > 0 {
            parts.append(durationHours == 1 ? "1 hour" : "\(durationHours) hours")
        }
        if durationMinutes > 0 {
            parts.append(durationMinutes == 1 ? "1 minute" : "\(durationMinutes) minutes")
        }

        let joined = parts.joined(separator: " and ")
        return "Event lasts \(joined). We'll calculate the end time automatically when you submit."
    }
}

private struct DurationPickerView: View {
    @Binding var hours: Int
    @Binding var minutes: Int
    var isInvalid: Bool

    private let hourRange = Array(0...12)
    private let minuteValues = Array(stride(from: 0, through: 55, by: 5))

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))

            RoundedRectangle(cornerRadius: 12)
                .stroke(isInvalid ? Color.red : Color.clear, lineWidth: 2)

            HStack(spacing: 0) {
                Picker("Hours", selection: $hours) {
                    ForEach(hourRange, id: \.self) { hour in
                        Text(hour == 1 ? "1 hr" : "\(hour) hrs")
                            .tag(hour)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .clipped()
                .pickerStyle(.wheel)

                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1, height: 120)

                Picker("Minutes", selection: $minutes) {
                    ForEach(minuteValues, id: \.self) { minute in
                        Text(minute == 1 ? "1 min" : "\(minute) mins")
                            .tag(minute)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .clipped()
                .pickerStyle(.wheel)
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 150)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Validation highlight
struct ValidationHighlight: ViewModifier {
    var isInvalid: Bool
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isInvalid ? Color.red : Color.clear, lineWidth: 2)
            )
            .modifier(JiggleEffect(animating: isInvalid))
    }
}

// MARK: - Jiggle Effect
struct JiggleEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit = 3
    var animating: Bool
    var animatableData: CGFloat = 0

    init(animating: Bool) {
        self.animating = animating
        self.animatableData = animating ? 1 : 0
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        if !animating { return .init(.identity) }
        let translation = sin(animatableData * .pi * CGFloat(shakesPerUnit)) * amount
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}


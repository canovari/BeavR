import SwiftUI
import MapKit

// MARK: - Draft model
struct PostDraft {
    var title: String
    var startTime: Date
    var endTime: Date
    var location: String
    var description: String
    var organization: String
    var category: String
    var contact: ContactInfo?
    var latitude: Double
    var longitude: Double
    var creator: String
}

// MARK: - AddEventView
struct AddEventView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var locationManager: LocationManager

    // Event fields
    @State private var title = ""
    @State private var startDate = Date()
    @State private var startTime = Date()
    @State private var endTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
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
    @State private var didSeedLocationFromDevice = false
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

                DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                    .modifier(ValidationHighlight(isInvalid: invalidFields.contains("endTime")))

                Text(eventTimingSummary)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

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
                        Text("Contact (optional)")
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
        .onAppear {
            locationManager.refreshLocation()
        }
        .onReceive(locationManager.$latestLocation) { location in
            guard !didSeedLocationFromDevice else { return }
            guard pickedCoordinate == nil else { return }
            guard let location = location else { return }

            let coordinate = location.coordinate
            pickedCoordinate = coordinate

            if locationQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                locationQuery = fallbackLocationLabel(for: coordinate)
            }

            didSeedLocationFromDevice = true
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
        if description.isEmpty { missing.insert("description") }
        if eventDuration <= 0 { missing.insert("endTime") }

        if missing.isEmpty {
            showFinalConfirmation = true
        } else {
            withAnimation { invalidFields = missing }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                withAnimation { invalidFields.removeAll() }
            }
        }
    }

    private func fallbackLocationLabel(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "Lat %.5f, Lon %.5f", coordinate.latitude, coordinate.longitude)
    }

    // MARK: - Actually send
    private func actuallySend() {
        guard let coord = pickedCoordinate else { return }
        guard let token = authViewModel.token else {
            submissionErrorMessage = "You need to be logged in to submit an event."
            return
        }

        guard let email = authViewModel.loggedInEmail ?? (authViewModel.email.isEmpty ? nil : authViewModel.email) else {
            submissionErrorMessage = "We couldn't determine your email address. Please try logging in again."
            return
        }

        let normalizedEmail = email.lowercased()

        let startDateTime = combinedStartDateTime
        let computedEndTime = resolvedEndDateTime
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

    private var combinedStartDateTime: Date {
        merge(date: startDate, time: startTime)
    }

    private var resolvedEndDateTime: Date {
        let sameDayEnd = merge(date: startDate, time: endTime)
        if sameDayEnd <= combinedStartDateTime {
            let calendar = Calendar.current
            return calendar.date(byAdding: .day, value: 1, to: sameDayEnd) ?? sameDayEnd.addingTimeInterval(86_400)
        }
        return sameDayEnd
    }

    private var eventDuration: TimeInterval {
        max(0, resolvedEndDateTime.timeIntervalSince(combinedStartDateTime))
    }

    private var eventTimingSummary: String {
        let startString = AddEventView.startFormatter.string(from: combinedStartDateTime)
        let durationText = formattedDuration(eventDuration)

        if Calendar.current.isDate(resolvedEndDateTime, inSameDayAs: combinedStartDateTime) {
            return "Event starts on \(startString) and lasts \(durationText)."
        } else {
            let endString = AddEventView.endFormatter.string(from: resolvedEndDateTime)
            return "Event starts on \(startString), lasts \(durationText), and ends on \(endString)."
        }
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "less than a minute" }

        let totalMinutes = max(1, Int(round(interval / 60)))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        var parts: [String] = []
        if hours > 0 {
            parts.append(hours == 1 ? "1 hour" : "\(hours) hours")
        }
        if minutes > 0 {
            parts.append(minutes == 1 ? "1 minute" : "\(minutes) minutes")
        }

        if parts.isEmpty {
            return "less than a minute"
        }

        return parts.joined(separator: " and ")
    }

    private static let startFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "MMM d 'at' h:mm a"
        return formatter
    }()

    private static let endFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "MMM d 'at' h:mm a"
        return formatter
    }()
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


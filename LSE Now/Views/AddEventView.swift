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
}

// MARK: - AddEventView
struct AddEventView: View {
    @Environment(\.dismiss) var dismiss

    // Event fields
    @State private var title = ""
    @State private var startDate = Date()
    @State private var startTime = Date()
    @State private var hasEndTime = false
    @State private var endTime = Date()
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

                Toggle("Add End Time", isOn: $hasEndTime)
                if hasEndTime {
                    DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                }

                // Location (no autocomplete)
                TextField("Location", text: $locationQuery)
                    .modifier(ValidationHighlight(isInvalid: invalidFields.contains("location")))
                    .focused($focusedField, equals: "location")

                // Map Pin
                NavigationLink {
                    ConfirmEventSpotView { coordinate in
                        pickedCoordinate = coordinate
                    }
                } label: {
                    HStack {
                        Text("Map Pin")
                        if pickedCoordinate != nil {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                .modifier(ValidationHighlight(isInvalid: invalidFields.contains("mapPin")))

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
        }
    }

    // MARK: - Validation
    private func validateFields() {
        var missing: Set<String> = []
        if title.isEmpty { missing.insert("title") }
        if locationQuery.isEmpty { missing.insert("location") }
        if pickedCoordinate == nil { missing.insert("mapPin") }
        if category.isEmpty { missing.insert("category") }
        if organization.isEmpty { missing.insert("organization") }
        if contact == nil { missing.insert("contact") }
        if description.isEmpty { missing.insert("description") }

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

        let draft = PostDraft(
            title: title,
            startTime: merge(date: startDate, time: startTime),
            endTime: hasEndTime ? merge(date: startDate, time: endTime) : nil,
            location: locationQuery,
            description: description,
            organization: organization,
            category: category,
            contact: contact,
            latitude: coord.latitude,
            longitude: coord.longitude
        )

        submitEvent(draft) { success in
            DispatchQueue.main.async {
                if success { showSubmissionSheet = true }
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

// MARK: - Networking
func submitEvent(_ draft: PostDraft, completion: @escaping (Bool) -> Void) {
    guard let url = URL(string: "https://www.canovari.com/api/events.php") else {
        completion(false); return
    }
    var req = URLRequest(url: url)
    req.httpMethod = "POST"
    req.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let iso = ISO8601DateFormatter()
    let body: [String: Any] = [
        "title": draft.title,
        "startTime": iso.string(from: draft.startTime),
        "endTime": draft.endTime.map { iso.string(from: $0) } as Any,
        "location": draft.location,
        "description": draft.description,
        "organization": draft.organization,
        "category": draft.category,
        "contact": ["type": draft.contact.type, "value": draft.contact.value],
        "latitude": draft.latitude,
        "longitude": draft.longitude
    ]

    req.httpBody = try? JSONSerialization.data(withJSONObject: body)

    URLSession.shared.dataTask(with: req) { _, _, _ in
        completion(true)
    }.resume()
}

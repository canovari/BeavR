import SwiftUI

struct EventContactView: View {
    @Binding var contact: ContactInfo?
    @Environment(\.dismiss) private var dismiss   // 👈 allows closing the page

    @State private var selectedType = "Phone"
    @State private var value = ""

    let types = ["Phone", "WhatsApp", "Instagram", "Facebook", "Email", "Other"]

    var body: some View {
        Form {
            Section(header: Text("Contact Type")) {
                Picker("Type", selection: $selectedType) {
                    ForEach(types, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .pickerStyle(.menu)
            }

            Section(header: Text("Details")) {
                if selectedType == "Phone" || selectedType == "WhatsApp" {
                    TextField("Phone number (+44...)", text: $value)
                        .keyboardType(.phonePad)
                } else if selectedType == "Email" {
                    TextField("Email address", text: $value)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textInputAutocapitalization(.never)
                } else {
                    TextField("Paste link to the account or post", text: $value)
                        .autocapitalization(.none)
                        .textInputAutocapitalization(.never)
                }
            }

        }
        .navigationTitle("Contact")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    contact = ContactInfo(type: selectedType, value: value)
                    dismiss()   // 👈 closes and goes back automatically
                }
            }
        }
        .onAppear {
            if let c = contact {
                selectedType = c.type
                value = c.value
            }
        }
    }
}

import SwiftUI

struct LoginFlowView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    private enum Field {
        case email
        case code
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to BeavR")
                        .font(.title.bold())
                    Text("Sign in with your email to continue.")
                        .foregroundColor(.secondary)
                }

                Group {
                    switch viewModel.step {
                    case .emailEntry:
                        emailEntry
                    case .codeEntry:
                        codeEntry
                    }
                }

                if let info = viewModel.infoMessage {
                    Text(info)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }

                Spacer()

                Text("We'll send you a one-time code to finish signing in.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focusedField = nil } } }
            .onAppear { focusField(for: viewModel.step) }
            .onChange(of: viewModel.step) { step in
                focusField(for: step)
            }
        }
    }

    private var emailEntry: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Email")
                .font(.headline)

            TextField("name@example.com", text: $viewModel.email)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .focused($focusedField, equals: .email)
                .submitLabel(.continue)
                .onSubmit {
                    Task { await viewModel.requestCode() }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)

            Button {
                Task { await viewModel.requestCode() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Send Login Code")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
        }
    }

    private var codeEntry: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Enter Code")
                .font(.headline)

            Text("We sent a 6-digit code to \(viewModel.email)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("123456", text: $viewModel.code)
                .keyboardType(.numberPad)
                .focused($focusedField, equals: .code)
                .textContentType(.oneTimeCode)
                .submitLabel(.done)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .onChange(of: viewModel.code) { newValue in
                    let filtered = newValue.filter { $0.isNumber }
                    let capped = String(filtered.prefix(6))
                    if capped != viewModel.code {
                        viewModel.code = capped
                    }
                }
                .onSubmit {
                    Task { await viewModel.verifyCode() }
                }

            Button {
                Task { await viewModel.verifyCode() }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Verify & Sign In")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)

            HStack {
                Button {
                    Task { await viewModel.requestCode() }
                } label: {
                    if viewModel.resendSecondsRemaining > 0 {
                        Text("Resend in \(viewModel.resendSecondsRemaining)s")
                    } else {
                        Text("Resend code")
                    }
                }
                .disabled(!viewModel.canResendCode)

                Spacer()

                Button("Use a different email") {
                    viewModel.startOver()
                }
            }
            .font(.subheadline)
        }
    }

    private func focusField(for step: AuthViewModel.Step) {
        switch step {
        case .emailEntry:
            focusedField = .email
        case .codeEntry:
            focusedField = .code
        }
    }
}

private extension Character {
    var isNumber: Bool {
        unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
    }
}

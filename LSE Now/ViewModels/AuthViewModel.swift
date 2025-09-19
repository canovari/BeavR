import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    enum Step: Equatable {
        case emailEntry
        case codeEntry
    }

    @Published var step: Step = .emailEntry
    @Published var email: String = ""
    @Published var code: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published private(set) var token: String?

    var isLoggedIn: Bool {
        token != nil
    }

    private let apiService: APIService
    private let tokenStorage: TokenStorage

    init(apiService: APIService = .shared, tokenStorage: TokenStorage = .shared) {
        self.apiService = apiService
        self.tokenStorage = tokenStorage
    }

    func loadExistingSession() {
        token = tokenStorage.loadToken()
    }

    func startOver() {
        email = ""
        code = ""
        step = .emailEntry
        errorMessage = nil
        infoMessage = nil
    }

    func requestCode() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedEmail.isEmpty else {
            errorMessage = "Please enter your LSE email address."
            return
        }

        guard trimmedEmail.hasSuffix("@lse.ac.uk") else {
            errorMessage = "Only @lse.ac.uk email addresses are supported."
            return
        }

        email = trimmedEmail
        errorMessage = nil
        infoMessage = nil
        isLoading = true

        do {
            try await apiService.requestLoginCode(for: trimmedEmail)
            step = .codeEntry
            code = ""
            infoMessage = "We\'ve sent a 6-digit code to \(trimmedEmail)."
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func verifyCode() async {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedCode.count == 6, Int(trimmedCode) != nil else {
            errorMessage = "Enter the 6-digit code from your email."
            return
        }

        errorMessage = nil
        infoMessage = nil
        isLoading = true

        do {
            let token = try await apiService.verifyLoginCode(email: email, code: trimmedCode)
            tokenStorage.save(token: token)
            self.token = token
            code = ""
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

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
    @Published private(set) var loggedInEmail: String?
    @Published private(set) var resendSecondsRemaining: Int = 0

    var isLoggedIn: Bool {
        token != nil
    }

    var canResendCode: Bool {
        !isLoading && resendSecondsRemaining == 0
    }

    private let apiService: APIService
    private let tokenStorage: TokenStorage
    private let pushManager: PushNotificationManager
    private var resendTimer: Timer?

    init(
        apiService: APIService = .shared,
        tokenStorage: TokenStorage = .shared,
        pushManager: PushNotificationManager = .shared
    ) {
        self.apiService = apiService
        self.tokenStorage = tokenStorage
        self.pushManager = pushManager
    }

    func loadExistingSession() {
        token = tokenStorage.loadToken()
        loggedInEmail = tokenStorage.loadEmail()

        if let savedEmail = loggedInEmail {
            email = savedEmail
        }

        if let savedEmail = loggedInEmail, let existingToken = token {
            pushManager.resumeSession(email: savedEmail, authToken: existingToken)
        }
    }

    func startOver() {
        resetResendCooldown()
        email = ""
        code = ""
        step = .emailEntry
        isLoading = false
        errorMessage = nil
        infoMessage = nil
    }

    func requestCode() async {
        if step == .codeEntry, resendSecondsRemaining > 0 {
            return
        }

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
            startResendCooldown()
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
            tokenStorage.save(token: token, email: email)
            self.token = token
            loggedInEmail = email
            code = ""
            resetResendCooldown()
            pushManager.handleSuccessfulLogin(email: email, authToken: token)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func logout() {
        let currentToken = token
        let currentEmail = loggedInEmail

        if let currentToken, let currentEmail {
            pushManager.handleLogout(email: currentEmail, authToken: currentToken)
        }

        tokenStorage.clear()
        token = nil
        loggedInEmail = nil
        startOver()
    }

    deinit {
        resendTimer?.invalidate()
    }

    private func startResendCooldown() {
        resendTimer?.invalidate()
        resendSecondsRemaining = 60

        resendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            if self.resendSecondsRemaining > 0 {
                self.resendSecondsRemaining -= 1
            }

            if self.resendSecondsRemaining == 0 {
                timer.invalidate()
                self.resendTimer = nil
            }
        }
    }

    private func resetResendCooldown() {
        resendTimer?.invalidate()
        resendTimer = nil
        resendSecondsRemaining = 0
    }
}

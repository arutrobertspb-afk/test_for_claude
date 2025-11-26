//
//  AuthenticationService.swift
//  AzmyAI
//
//  Handles Google Sign-In and Apple Sign-In authentication
//

import Foundation
import AuthenticationServices
import CryptoKit

// MARK: - Authentication Provider
enum AuthProvider: String, Codable {
    case google = "google"
    case apple = "apple"
    case none = "none"
}

// MARK: - Authenticated User
struct AuthenticatedUser: Codable {
    var id: String
    var email: String
    var displayName: String
    var provider: AuthProvider
    var profileImageURL: String?
    var googleAccessToken: String?
    var googleRefreshToken: String?
    var appleUserIdentifier: String?
    var tokenExpirationDate: Date?

    var isTokenValid: Bool {
        guard let expiration = tokenExpirationDate else { return false }
        return Date() < expiration
    }
}

// MARK: - Authentication Service
@MainActor
class AuthenticationService: NSObject, ObservableObject {
    static let shared = AuthenticationService()

    @Published var currentUser: AuthenticatedUser?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: AuthError?

    // Google OAuth Configuration
    // You need to replace these with your actual credentials
    private let googleClientID = "185785334554-i8n1ih7d6l763vteof9t8kro9r83rapo.apps.googleusercontent.com"
    private let googleRedirectURI = "com.azmy.ai:/oauth2callback"

    // Apple Sign-In
    private var currentNonce: String?
    private var appleSignInCompletion: ((Result<AuthenticatedUser, AuthError>) -> Void)?

    private let userDefaultsKey = "authenticatedUser"

    override init() {
        super.init()
        loadSavedUser()
    }

    // MARK: - Load Saved User
    private func loadSavedUser() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(AuthenticatedUser.self, from: data) {
            self.currentUser = user
            self.isAuthenticated = true

            // Check if Google token needs refresh
            if user.provider == .google && !user.isTokenValid {
                Task {
                    await refreshGoogleToken()
                }
            }
        }
    }

    // MARK: - Save User
    private func saveUser(_ user: AuthenticatedUser) {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
        self.currentUser = user
        self.isAuthenticated = true
    }

    // MARK: - Sign Out
    func signOut() {
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)

        // Clear Google Calendar tokens
        GoogleCalendarService.shared.clearTokens()
    }

    // MARK: - Google Sign-In
    func signInWithGoogle() async throws -> AuthenticatedUser {
        isLoading = true
        error = nil

        defer { isLoading = false }

        // Generate state for CSRF protection
        let state = UUID().uuidString

        // Build authorization URL
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: googleClientID),
            URLQueryItem(name: "redirect_uri", value: googleRedirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "email profile https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/calendar.events"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authURL = components.url else {
            throw AuthError.invalidConfiguration
        }

        // Open in ASWebAuthenticationSession
        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "com.azmy.ai"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: AuthError.authenticationFailed(error.localizedDescription))
                } else if let url = callbackURL {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: AuthError.cancelled)
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            if !session.start() {
                continuation.resume(throwing: AuthError.sessionStartFailed)
            }
        }

        // Extract authorization code
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            throw AuthError.noAuthorizationCode
        }

        // Exchange code for tokens
        let tokens = try await exchangeCodeForTokens(code: code)

        // Fetch user info
        let userInfo = try await fetchGoogleUserInfo(accessToken: tokens.accessToken)

        let user = AuthenticatedUser(
            id: userInfo.id,
            email: userInfo.email,
            displayName: userInfo.name,
            provider: .google,
            profileImageURL: userInfo.picture,
            googleAccessToken: tokens.accessToken,
            googleRefreshToken: tokens.refreshToken,
            tokenExpirationDate: Date().addingTimeInterval(TimeInterval(tokens.expiresIn))
        )

        saveUser(user)

        // Setup Google Calendar with the access token
        GoogleCalendarService.shared.setAccessToken(tokens.accessToken, refreshToken: tokens.refreshToken)

        return user
    }

    // MARK: - Exchange Code for Tokens
    private func exchangeCodeForTokens(code: String) async throws -> GoogleTokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "code": code,
            "client_id": googleClientID,
            "redirect_uri": googleRedirectURI,
            "grant_type": "authorization_code"
        ]

        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.tokenExchangeFailed
        }

        return try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
    }

    // MARK: - Refresh Google Token
    func refreshGoogleToken() async {
        guard let user = currentUser,
              let refreshToken = user.googleRefreshToken else {
            return
        }

        do {
            var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

            let bodyParams = [
                "refresh_token": refreshToken,
                "client_id": googleClientID,
                "grant_type": "refresh_token"
            ]

            request.httpBody = bodyParams
                .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
                .joined(separator: "&")
                .data(using: .utf8)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return
            }

            let tokens = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)

            var updatedUser = user
            updatedUser.googleAccessToken = tokens.accessToken
            updatedUser.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokens.expiresIn))

            saveUser(updatedUser)
            GoogleCalendarService.shared.setAccessToken(tokens.accessToken, refreshToken: refreshToken)

        } catch {
            print("Failed to refresh token: \(error)")
        }
    }

    // MARK: - Fetch Google User Info
    private func fetchGoogleUserInfo(accessToken: String) async throws -> GoogleUserInfo {
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.userInfoFetchFailed
        }

        return try JSONDecoder().decode(GoogleUserInfo.self, from: data)
    }

    // MARK: - Apple Sign-In
    func signInWithApple() async throws -> AuthenticatedUser {
        isLoading = true
        error = nil

        defer { isLoading = false }

        return try await withCheckedThrowingContinuation { continuation in
            let nonce = randomNonceString()
            currentNonce = nonce

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self

            appleSignInCompletion = { result in
                switch result {
                case .success(let user):
                    continuation.resume(returning: user)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            controller.performRequests()
        }
    }

    // MARK: - Helper Functions
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension AuthenticationService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthenticationService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            appleSignInCompletion?(.failure(.invalidCredential))
            return
        }

        let userIdentifier = appleIDCredential.user
        let email = appleIDCredential.email ?? ""
        let fullName = [
            appleIDCredential.fullName?.givenName,
            appleIDCredential.fullName?.familyName
        ].compactMap { $0 }.joined(separator: " ")

        // Apple only provides name/email on first sign-in
        // Load from saved data if not provided
        var displayName = fullName
        var userEmail = email

        if displayName.isEmpty, let savedUser = currentUser, savedUser.appleUserIdentifier == userIdentifier {
            displayName = savedUser.displayName
        }
        if userEmail.isEmpty, let savedUser = currentUser, savedUser.appleUserIdentifier == userIdentifier {
            userEmail = savedUser.email
        }

        let user = AuthenticatedUser(
            id: userIdentifier,
            email: userEmail,
            displayName: displayName.isEmpty ? "Apple User" : displayName,
            provider: .apple,
            appleUserIdentifier: userIdentifier
        )

        saveUser(user)
        appleSignInCompletion?(.success(user))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                appleSignInCompletion?(.failure(.cancelled))
            case .invalidResponse:
                appleSignInCompletion?(.failure(.invalidResponse))
            case .notHandled:
                appleSignInCompletion?(.failure(.notHandled))
            case .failed:
                appleSignInCompletion?(.failure(.authenticationFailed(error.localizedDescription)))
            case .notInteractive:
                appleSignInCompletion?(.failure(.notInteractive))
            case .unknown:
                appleSignInCompletion?(.failure(.unknown))
            @unknown default:
                appleSignInCompletion?(.failure(.unknown))
            }
        } else {
            appleSignInCompletion?(.failure(.authenticationFailed(error.localizedDescription)))
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthenticationService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case invalidConfiguration
    case authenticationFailed(String)
    case cancelled
    case sessionStartFailed
    case noAuthorizationCode
    case tokenExchangeFailed
    case userInfoFetchFailed
    case invalidCredential
    case invalidResponse
    case notHandled
    case notInteractive
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid authentication configuration"
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .cancelled:
            return "Authentication was cancelled"
        case .sessionStartFailed:
            return "Failed to start authentication session"
        case .noAuthorizationCode:
            return "No authorization code received"
        case .tokenExchangeFailed:
            return "Failed to exchange code for tokens"
        case .userInfoFetchFailed:
            return "Failed to fetch user information"
        case .invalidCredential:
            return "Invalid credential received"
        case .invalidResponse:
            return "Invalid response from authentication provider"
        case .notHandled:
            return "Authentication request not handled"
        case .notInteractive:
            return "Authentication requires user interaction"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

// MARK: - Google API Models
struct GoogleTokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case tokenType = "token_type"
    }
}

struct GoogleUserInfo: Codable {
    let id: String
    let email: String
    let name: String
    let picture: String?
    let verifiedEmail: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case picture
        case verifiedEmail = "verified_email"
    }
}

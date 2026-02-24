import Foundation
import AuthenticationServices

@Observable
@MainActor
final class AuthService {
    static let shared = AuthService()

    private let supabaseURL = "https://login.treesinvienna.eu"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzQxODI0MDAwLCJleHAiOjE4OTk1OTA0MDB9.UsZml_lWmEFwYGPjoGRUgt4lI1Mq_vaA7aWD9G2o9-g"

    var authState: AuthState = .loading
    private(set) var accessToken: String?
    private(set) var refreshToken: String?

    private init() {
        restoreSession()
    }

    func signInWithEmail(email: String, password: String) async {
        authState = .loading

        do {
            let body: [String: Any] = [
                "email": email,
                "password": password
            ]

            let data = try await authRequest(
                endpoint: "/auth/v1/token?grant_type=password",
                body: body
            )

            try handleAuthResponse(data)
        } catch {
            let message = parseAuthError(error)
            authState = .error(message: message)
        }
    }

    func signUpWithEmail(email: String, password: String) async -> Bool {
        authState = .loading

        do {
            let body: [String: Any] = [
                "email": email,
                "password": password
            ]

            let data = try await authRequest(
                endpoint: "/auth/v1/signup",
                body: body
            )

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let id = json["id"] as? String, !id.isEmpty {

                if json["access_token"] as? String != nil {
                    try handleAuthResponse(data)
                } else {

                    authState = .notAuthenticated
                }
                return true
            }

            authState = .notAuthenticated
            return true
        } catch {
            let message = parseAuthError(error)
            authState = .error(message: message)
            return false
        }
    }

    private var appleSignInContinuation: CheckedContinuation<ASAuthorization, Error>?

    func signInWithApple() async {
        authState = .loading

        do {
            let authorization = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
                let provider = ASAuthorizationAppleIDProvider()
                let request = provider.createRequest()
                request.requestedScopes = [.fullName, .email]

                let delegate = AppleSignInDelegate(continuation: continuation)
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = delegate
                controller.presentationContextProvider = OAuthPresentationContext.shared

                objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)

                controller.performRequests()
            }

            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8) else {
                authState = .error(message: "Apple-Anmeldedaten ungültig")
                return
            }

            var body: [String: Any] = [
                "provider": "apple",
                "id_token": identityToken
            ]

            if let fullName = credential.fullName {
                let displayName = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                if !displayName.isEmpty {
                    body["options"] = ["data": ["full_name": displayName]]
                }
            }

            let data = try await authRequest(
                endpoint: "/auth/v1/token?grant_type=id_token",
                body: body
            )

            try handleAuthResponse(data)
        } catch {
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                authState = .notAuthenticated
            } else {
                let message = parseAuthError(error)
                authState = .error(message: message)
            }
        }
    }

    func signInWithGitHub() async {
        let redirectURL = "baumkataster://login-callback"
        let authURL = "\(supabaseURL)/auth/v1/authorize?provider=github&redirect_to=\(redirectURL)"

        guard let url = URL(string: authURL) else {
            authState = .error(message: "Ungültige OAuth-URL")
            return
        }

        do {
            let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
                let session = ASWebAuthenticationSession(
                    url: url,
                    callbackURLScheme: "baumkataster"
                ) { callbackURL, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let callbackURL = callbackURL {
                        continuation.resume(returning: callbackURL)
                    } else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                }
                session.prefersEphemeralWebBrowserSession = false
                session.presentationContextProvider = OAuthPresentationContext.shared
                session.start()
            }

            if let fragment = callbackURL.fragment {
                let params = parseURLFragment(fragment)

                if let accessToken = params["access_token"],
                   let refreshToken = params["refresh_token"] {
                    self.accessToken = accessToken
                    self.refreshToken = refreshToken
                    saveTokens()

                    await fetchUser()
                } else {
                    authState = .error(message: "OAuth-Token nicht erhalten")
                }
            } else {
                authState = .error(message: "OAuth-Callback ungültig")
            }
        } catch {
            if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                authState = .notAuthenticated
            } else {
                authState = .error(message: "GitHub-Anmeldung fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }

    func signOut() {
        accessToken = nil
        refreshToken = nil
        UserDefaults.standard.removeObject(forKey: "supabase_access_token")
        UserDefaults.standard.removeObject(forKey: "supabase_refresh_token")
        authState = .notAuthenticated
    }

    func getCurrentUserId() -> String? {
        authState.userId
    }

    func getCurrentDisplayName() -> String? {
        authState.displayName
    }

    func refreshSession() async {
        guard let refreshToken = refreshToken else {
            authState = .notAuthenticated
            return
        }

        do {
            let body: [String: Any] = [
                "refresh_token": refreshToken
            ]

            let data = try await authRequest(
                endpoint: "/auth/v1/token?grant_type=refresh_token",
                body: body
            )

            try handleAuthResponse(data)
        } catch {

            signOut()
        }
    }

    private func restoreSession() {
        accessToken = UserDefaults.standard.string(forKey: "supabase_access_token")
        refreshToken = UserDefaults.standard.string(forKey: "supabase_refresh_token")

        if accessToken != nil {

            Task {
                await refreshSession()
            }
        } else {
            authState = .notAuthenticated
        }
    }

    private func saveTokens() {
        UserDefaults.standard.set(accessToken, forKey: "supabase_access_token")
        UserDefaults.standard.set(refreshToken, forKey: "supabase_refresh_token")
    }

    private func handleAuthResponse(_ data: Data) throws {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.badServerResponse)
        }

        guard let token = json["access_token"] as? String else {
            if let errorDesc = json["error_description"] as? String {
                throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: errorDesc])
            }
            if let msg = json["msg"] as? String {
                throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw URLError(.userAuthenticationRequired)
        }

        accessToken = token
        refreshToken = json["refresh_token"] as? String ?? refreshToken
        saveTokens()

        if let user = json["user"] as? [String: Any] {
            let userId = user["id"] as? String ?? ""
            let email = user["email"] as? String
            let metadata = user["user_metadata"] as? [String: Any]
            let displayName = metadata?["full_name"] as? String
                ?? metadata?["name"] as? String
                ?? email?.components(separatedBy: "@").first
            let avatarUrl = metadata?["avatar_url"] as? String

            authState = .authenticated(
                userId: userId,
                email: email,
                displayName: displayName,
                avatarUrl: avatarUrl
            )

            Task {
                await ensureUserProfileExists(userId: userId, email: email, displayName: displayName)
            }
        } else {

            Task {
                await fetchUser()
            }
        }
    }

    private func fetchUser() async {
        guard let token = accessToken else {
            authState = .notAuthenticated
            return
        }

        do {
            var request = URLRequest(url: URL(string: "\(supabaseURL)/auth/v1/user")!)
            request.httpMethod = "GET"
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {

                await refreshSession()
                return
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let userId = json["id"] as? String ?? ""
                let email = json["email"] as? String
                let metadata = json["user_metadata"] as? [String: Any]
                let displayName = metadata?["full_name"] as? String
                    ?? metadata?["name"] as? String
                    ?? email?.components(separatedBy: "@").first
                let avatarUrl = metadata?["avatar_url"] as? String

                authState = .authenticated(
                    userId: userId,
                    email: email,
                    displayName: displayName,
                    avatarUrl: avatarUrl
                )

                Task {
                    await ensureUserProfileExists(userId: userId, email: email, displayName: displayName)
                }
            }
        } catch {
            print("AuthService: Failed to fetch user: \(error)")
            authState = .notAuthenticated
        }
    }

    private func ensureUserProfileExists(userId: String, email: String?, displayName: String?) async {
        guard let token = accessToken, !userId.isEmpty else { return }

        let profile: [String: Any] = [
            "id": userId,
            "display_name": displayName ?? (email?.components(separatedBy: "@").first ?? "User"),

            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]

        guard let url = URL(string: "\(supabaseURL)/rest/v1/user_profiles") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: profile)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                print("AuthService: Failed to upsert profile, status: \(httpResponse.statusCode)")
            } else {
                print("AuthService: User profile synced successfully")
            }
        } catch {
            print("AuthService: Failed to sync profile: \(error)")
        }
    }

    private func authRequest(endpoint: String, body: [String: Any]) async throws -> Data {
        guard let url = URL(string: "\(supabaseURL)\(endpoint)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let msg = json["error_description"] as? String
                    ?? json["msg"] as? String
                    ?? json["message"] as? String
                    ?? "Unbekannter Fehler"
                throw NSError(domain: "AuthError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw URLError(.userAuthenticationRequired)
        }

        return data
    }

    private func parseAuthError(_ error: Error) -> String {
        let msg = error.localizedDescription
        if msg.contains("Invalid login credentials") {
            return "E-Mail oder Passwort falsch"
        }
        if msg.contains("Email not confirmed") {
            return "E-Mail noch nicht bestätigt. Prüfe dein Postfach."
        }
        if msg.contains("already registered") || msg.contains("already been registered") {
            return "Diese E-Mail ist bereits registriert"
        }
        if msg.contains("password") {
            return "Passwort zu schwach (min. 6 Zeichen)"
        }
        if msg.contains("network") || msg.contains("offline") {
            return "Netzwerkfehler. Prüfe deine Internetverbindung."
        }
        return msg
    }

    private func parseURLFragment(_ fragment: String) -> [String: String] {
        var params: [String: String] = [:]
        let pairs = fragment.components(separatedBy: "&")
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count == 2 {
                params[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
            }
        }
        return params
    }
}

private class OAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding, ASAuthorizationControllerPresentationContextProviding {
    static let shared = OAuthPresentationContext()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    let continuation: CheckedContinuation<ASAuthorization, Error>
    private var hasResumed = false

    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard !hasResumed else { return }
        hasResumed = true
        continuation.resume(returning: authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard !hasResumed else { return }
        hasResumed = true
        continuation.resume(throwing: error)
    }
}

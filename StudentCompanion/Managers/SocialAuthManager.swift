import Foundation
import SwiftUI
import AuthenticationServices
import Supabase

@MainActor
class SocialAuthManager: NSObject, ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabaseService = SupabaseService.shared
    private var currentNonce: String?

    // MARK: - Google Sign In

    func signInWithGoogle(presentingViewController: UIViewController) async -> Result<Void, AuthError> {
        isLoading = true
        errorMessage = nil

        let result = await supabaseService.signInWithOAuth(provider: .google)
        switch result {
        case .success(let url):
            // Open OAuth URL in Safari for authentication
            await UIApplication.shared.open(url)
            isLoading = false
            // Return success - actual user will be obtained via callback
            return .success(())
        case .failure(let error):
            errorMessage = error.localizedDescription
            isLoading = false
            return .failure(error)
        }
    }

    // MARK: - Apple Sign In (Native)

    func signInWithApple() async -> Result<Void, AuthError> {
        isLoading = true
        errorMessage = nil

        return await withCheckedContinuation { continuation in
            // Generate nonce for security
            let nonce = randomNonceString()
            currentNonce = nonce

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self

            // Store continuation for callback
            self.appleSignInContinuation = continuation

            controller.performRequests()
        }
    }

    // Apple Sign In continuation
    private var appleSignInContinuation: CheckedContinuation<Result<Void, AuthError>, Never>?

    // MARK: - Token Exchange

    private func exchangeAppleTokenWithSupabase(
        identityToken: String,
        authorizationCode: String?,
        nonce: String
    ) async -> Result<Void, AuthError> {
        do {
            // Define response structure
            struct SessionResponse: Codable {
                let access_token: String
                let refresh_token: String
                let expires_in: Int
                let expires_at: Int?
                let token_type: String
                let user: UserResponse
            }

            struct UserResponse: Codable {
                let id: String
                let email: String?
            }

            // Call Edge Function to verify Apple token and get Supabase session
            let requestBody: [String: String] = [
                "idToken": identityToken,
                "nonce": nonce
            ]

            let sessionData: SessionResponse = try await supabaseService.client.functions
                .invoke("apple-sign-in", options: .init(body: requestBody))

            print("✅ Received session from Edge Function")
            print("Access token length:", sessionData.access_token.count)
            print("Refresh token length:", sessionData.refresh_token.count)

            // Decode token to verify format (for debugging)
            let tokenParts = sessionData.access_token.split(separator: ".").map(String.init)
            if tokenParts.count == 3,
               let payloadData = Data(base64Encoded: tokenParts[1].padding(toLength: ((tokenParts[1].count + 3) / 4) * 4, withPad: "=", startingAt: 0)),
               let payloadString = String(data: payloadData, encoding: .utf8) {
                print("📋 Token payload:", payloadString)
            }

            // Set the session in Supabase client
            print("🔄 Calling setSession...")
            do {
                let session = try await supabaseService.client.auth.setSession(
                    accessToken: sessionData.access_token,
                    refreshToken: sessionData.refresh_token
                )

                print("✅ Session set successfully")
                print("User ID:", session.user.id)
                print("User email:", session.user.email ?? "no email")

                // Create default user data if this is first sign in
                await supabaseService.createDefaultUserData(for: session.user)

                isLoading = false
                return .success(())
            } catch let sessionError {
                print("❌ setSession error:", sessionError)
                print("❌ Error details:", String(describing: sessionError))
                throw sessionError
            }
        } catch {
            print("❌ Full error:", error)
            print("❌ Error type:", type(of: error))
            errorMessage = "Failed to authenticate with Apple: \(error.localizedDescription)"
            isLoading = false
            return .failure(.authenticationFailed)
        }
    }

    // MARK: - Nonce Generation

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
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

// MARK: - ASAuthorizationControllerDelegate

extension SocialAuthManager: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            appleSignInContinuation?.resume(returning: .failure(.authenticationFailed))
            appleSignInContinuation = nil
            errorMessage = "Failed to get Apple ID credential"
            isLoading = false
            return
        }

        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            appleSignInContinuation?.resume(returning: .failure(.authenticationFailed))
            appleSignInContinuation = nil
            errorMessage = "Failed to get identity token"
            isLoading = false
            return
        }

        guard let nonce = currentNonce else {
            appleSignInContinuation?.resume(returning: .failure(.authenticationFailed))
            appleSignInContinuation = nil
            errorMessage = "Invalid state: nonce is missing"
            isLoading = false
            return
        }

        let authCode = appleIDCredential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }

        Task {
            let result = await exchangeAppleTokenWithSupabase(
                identityToken: identityToken,
                authorizationCode: authCode,
                nonce: nonce
            )

            appleSignInContinuation?.resume(returning: result)
            appleSignInContinuation = nil
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        let authError = error as? ASAuthorizationError

        if authError?.code == .canceled {
            // User canceled, don't show error
            errorMessage = nil
        } else {
            errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
        }

        appleSignInContinuation?.resume(returning: .failure(.authenticationFailed))
        appleSignInContinuation = nil
        isLoading = false
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension SocialAuthManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            fatalError("No window available")
        }
        return window
    }
}

import CryptoKit

extension SocialAuthManager {
    private struct SHA256 {
        static func hash(data: Data) -> Data {
            let hashed = CryptoKit.SHA256.hash(data: data)
            return Data(hashed)
        }
    }
}

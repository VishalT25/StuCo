import Foundation
import Supabase

// MARK: - ISO8601 Date Formatting

private let iso8601WithFractional: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()

extension Date {
    func iso8601String() -> String {
        iso8601WithFractional.string(from: self)
    }
}

// MARK: - Connection Stats

struct ConnectionStats {
    let isConnected: Bool
    let quality: SupabaseService.ConnectionQuality
    let lastSync: Date?
    let authExpiry: Date?
}

// MARK: - Sync Stats

struct SyncStats {
    let schedulesCount: Int
    let coursesCount: Int
    let assignmentsCount: Int
    let eventsCount: Int
    let categoriesCount: Int

    var totalItems: Int {
        schedulesCount + coursesCount + assignmentsCount + eventsCount + categoriesCount
    }
}

// MARK: - Auth Error

enum AuthError: Error, LocalizedError {
    case invalidEmail
    case weakPassword
    case authenticationFailed
    case registrationFailed
    case emailAlreadyExists
    case emailAlreadyInUse
    case emailNotConfirmed
    case resetPasswordFailed
    case storageError
    case missingConfiguration
    case notAuthenticated
    case accountDeletionFailed
    case rateLimitExceeded

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .weakPassword:
            return "Password must be at least 8 characters with uppercase, lowercase, and numbers"
        case .authenticationFailed:
            return "Authentication failed. Please check your credentials"
        case .registrationFailed:
            return "Registration failed. Please try again"
        case .emailAlreadyExists:
            return "An account with this email already exists. Please sign in instead"
        case .emailAlreadyInUse:
            return "This email is already registered to another account"
        case .emailNotConfirmed:
            return "Please check your email and click the confirmation link before signing in"
        case .resetPasswordFailed:
            return "Failed to send password reset email. Please try again"
        case .storageError:
            return "Failed to store authentication data securely"
        case .missingConfiguration:
            return "Supabase is not configured for this build target. Add SUPABASE_URL and SUPABASE_ANON_KEY to the target's Info.plist or Secrets.plist."
        case .notAuthenticated:
            return "You must be signed in to perform this action"
        case .accountDeletionFailed:
            return "Failed to delete account. Please try again or contact support"
        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment and try again"
        }
    }
}

// MARK: - Sign Up Result

enum SignUpResult {
    case confirmedImmediately(User)
    case needsEmailConfirmation(User)
}

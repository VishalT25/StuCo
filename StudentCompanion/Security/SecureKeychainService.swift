import Foundation
import Security

/// Secure Keychain service for storing sensitive authentication data
/// Implements security best practices for iOS token storage
class SecureKeychainService {
    static let shared = SecureKeychainService()
    
    private let service = "com.studentcompanion.secure"
    private let accessGroup: String? = nil // Set if using app groups
    
    private init() {}
    
    // MARK: - Security Configuration
    private var baseQuery: [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            // Highest security: Only accessible when device is unlocked with passcode
            kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        ]
        
        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        return query
    }
    
    // MARK: - Token Storage Operations
    
    /// Securely store authentication token
    /// - Parameters:
    ///   - token: JWT or session token to store
    ///   - key: Unique identifier for the token
    /// - Returns: Success status
    func storeToken(_ token: String, forKey key: String) -> Bool {
        // Input validation
        guard !token.isEmpty, !key.isEmpty else {
             ("🔒 SecurityError: Empty token or key provided")
            return false
        }
        
        // Convert to data
        guard let tokenData = token.data(using: .utf8) else {
             ("🔒 SecurityError: Failed to convert token to data")
            return false
        }
        
        // Delete existing token first
        _ = deleteToken(forKey: key)
        
        // Create secure query
        var query = baseQuery
        query[kSecAttrAccount as String] = key
        query[kSecValueData as String] = tokenData
        
        // Store in keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
             ("🔒 Token securely stored for key: \(key)")
            return true
        } else {
             ("🔒 SecurityError: Failed to store token. Status: \(status)")
            return false
        }
    }
    
    /// Securely retrieve authentication token
    /// - Parameter key: Unique identifier for the token
    /// - Returns: Decrypted token or nil if not found/error
    func retrieveToken(forKey key: String) -> String? {
        // Input validation
        guard !key.isEmpty else {
             ("🔒 SecurityError: Empty key provided")
            return nil
        }
        
        // Create query
        var query = baseQuery
        query[kSecAttrAccount as String] = key
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        
        // Retrieve from keychain
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            if let data = dataTypeRef as? Data,
               let token = String(data: data, encoding: .utf8) {
                return token
            } else {
                 ("🔒 SecurityError: Failed to decode retrieved token")
                return nil
            }
        } else if status == errSecItemNotFound {
            return nil // Token doesn't exist
        } else {
             ("🔒 SecurityError: Failed to retrieve token. Status: \(status)")
            return nil
        }
    }
    
    /// Securely delete authentication token
    /// - Parameter key: Unique identifier for the token
    /// - Returns: Success status
    func deleteToken(forKey key: String) -> Bool {
        guard !key.isEmpty else { return false }
        
        var query = baseQuery
        query[kSecAttrAccount as String] = key
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Clear all stored tokens (for logout)
    func clearAllTokens() -> Bool {
        let query = baseQuery
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Security Utilities
    
    /// Validate JWT token structure (basic check)
    /// - Parameter token: JWT token to validate
    /// - Returns: True if token has valid JWT structure
    func validateJWTStructure(_ token: String) -> Bool {
        let components = token.split(separator: ".")
        return components.count == 3 // header.payload.signature
    }
    
    /// Check if token is expired (if it's a JWT)
    /// - Parameter token: JWT token to check
    /// - Returns: True if token is expired
    func isTokenExpired(_ token: String) -> Bool {
        guard validateJWTStructure(token) else { return true }
        
        let components = token.split(separator: ".")
        guard components.count == 3 else { return true }
        
        // Decode payload
        let payload = String(components[1])
        guard let payloadData = Data(base64Encoded: payload.padding(toMultiple: 4)) else { return true }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
               let exp = json["exp"] as? TimeInterval {
                return Date().timeIntervalSince1970 >= exp
            }
        } catch {
             ("🔒 SecurityError: Failed to decode JWT payload")
        }
        
        return true // Assume expired if we can't decode
    }
}

// MARK: - Security Extensions

private extension String {
    /// Pad base64 string to multiple of 4 for proper decoding
    func padding(toMultiple: Int) -> String {
        let remainder = count % toMultiple
        return remainder == 0 ? self : self + String(repeating: "=", count: toMultiple - remainder)
    }
}

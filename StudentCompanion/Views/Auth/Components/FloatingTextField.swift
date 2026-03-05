import SwiftUI

struct FloatingTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var showValidation: Bool = true // New parameter to control validation display
    
    @StateObject private var themeManager = ThemeManager()
    @FocusState private var isFocused: Bool
    @State private var hasError: Bool = false
    @State private var shouldShowValidation: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                // Background card with glassmorphism
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemBackground).opacity(0.08))
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        LinearGradient(
                                            colors: isFocused ? [
                                                themeManager.currentTheme.primaryColor.opacity(0.7),
                                                themeManager.currentTheme.secondaryColor.opacity(0.5)
                                            ] : [
                                                Color.white.opacity(0.25),
                                                Color.white.opacity(0.08)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: isFocused ? 1.5 : 0.8
                                    )
                            )
                    )
                    .frame(height: 56)
                
                // Content with proper centering
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        // Floating label - only show when focused or has text
                        if isFocused || !text.isEmpty {
                            Text(title)
                                .font(.forma(.caption, weight: .medium))
                                .foregroundColor(isFocused ? themeManager.currentTheme.primaryColor : .secondary)
                                .scaleEffect(0.85, anchor: .leading)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        // Text input - perfectly centered when no label
                        Group {
                            if isSecure {
                                SecureField(placeholder, text: $text)
                            } else {
                                TextField(placeholder, text: $text)
                                    .keyboardType(keyboardType)
                                    .textInputAutocapitalization(autocapitalization)
                                    .autocorrectionDisabled()
                            }
                        }
                        .font(.forma(.body, weight: .medium))
                        .foregroundColor(.primary)
                        .focused($isFocused)
                        .onChange(of: text) { newValue in
                            if showValidation {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    shouldShowValidation = !newValue.isEmpty
                                    validateInput(newValue)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: .infinity) // Ensures vertical centering
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, (isFocused || !text.isEmpty) ? 8 : 16) // More padding when no label
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: text.isEmpty)
            }
            .scaleEffect(isFocused ? 1.01 : 1.0)
            .shadow(
                color: isFocused ? themeManager.currentTheme.primaryColor.opacity(0.15) : Color.black.opacity(0.05),
                radius: isFocused ? 8 : 3,
                x: 0,
                y: isFocused ? 4 : 1
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
            
            // Validation indicator - only show if validation is enabled
            if showValidation && shouldShowValidation && !text.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: hasError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(hasError ? .red : .green)
                        .font(.caption)
                        .frame(width: 12, height: 12)
                    
                    Text(getValidationMessage())
                        .font(.forma(.caption2))
                        .foregroundColor(hasError ? .red : .green)
                    
                    Spacer()
                }
                .padding(.leading, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.2), value: hasError)
            }
        }
        .onTapGesture {
            isFocused = true
        }
    }
    
    private func validateInput(_ input: String) {
        if title.lowercased().contains("email") {
            hasError = !isValidEmail(input)
        } else if title.lowercased().contains("password") && isSecure {
            hasError = input.count < 8 // Updated to 8 characters
        } else {
            hasError = false
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    private func getValidationMessage() -> String {
        if title.lowercased().contains("email") {
            return hasError ? "Please enter a valid email" : "Email looks good!"
        } else if title.lowercased().contains("password") && isSecure {
            return hasError ? "Password must be at least 8 characters" : "Password strength is good"
        }
        return ""
    }
}
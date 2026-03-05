import SwiftUI

struct AuthTestView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var message = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("🔒 Authentication Test")
                    .font(.title)
                    .fontWeight(.bold)
                
                // Authentication Form
                VStack(spacing: 15) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password (8+ chars, mixed case, numbers, symbols)", text: $password)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Button("Test Sign Up") {
                            testSignUp()
                        }
                        .disabled(isLoading)
                        
                        Button("Test Sign In") {
                            testSignIn()
                        }
                        .disabled(isLoading)
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if !message.isEmpty {
                    ScrollView {
                        Text(message)
                            .foregroundColor(message.contains("Error") ? .red : .green)
                            .padding()
                            .font(.caption)
                    }
                    .frame(maxHeight: 100)
                }
                
                if isLoading {
                    ProgressView()
                }
                
                Text("Authentication system is being reworked")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
            .navigationTitle("Auth Test")
        }
    }
    
    private func testSignUp() {
        isLoading = true
        message = "Authentication system is being reworked. This feature is temporarily unavailable."
        
        // Simulate async operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
        }
    }
    
    private func testSignIn() {
        isLoading = true
        message = "Authentication system is being reworked. This feature is temporarily unavailable."
        
        // Simulate async operation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
        }
    }
}

#Preview {
    AuthTestView()
}
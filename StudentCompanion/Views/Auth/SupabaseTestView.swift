import SwiftUI

struct SupabaseTestView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @StateObject private var courseService = SecureCourseService()
    @State private var email = ""
    @State private var password = ""
    @State private var message = ""
    @State private var isLoading = false
    @State private var courses: [Course] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("🔒 Supabase Security Test")
                    .font(.title)
                    .fontWeight(.bold)
                
                if supabaseService.isAuthenticated {
                    // Authenticated State
                    VStack(spacing: 15) {
                        Text("✅ Authenticated!")
                            .foregroundColor(.green)
                        
                        if let user = supabaseService.currentUser {
                            Text("User: \(user.email ?? "No email")")
                                .font(.caption)
                        }
                        
                        // Test course operations
                        Button("Test Fetch Courses") {
                            testFetchCourses()
                        }
                        
                        Button("Test Create Course") {
                            testCreateCourse()
                        }
                        
                        if !courses.isEmpty {
                            Text("📚 Courses: \(courses.count)")
                                .foregroundColor(.blue)
                        }
                        
                        Button("Sign Out") {
                            Task {
                                await supabaseService.signOut()
                                courses = []
                            }
                        }
                        .foregroundColor(.red)
                    }
                } else {
                    // Authentication Form
                    VStack(spacing: 15) {
                        TextField("Email", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        SecureField("Password (8+ chars, mixed case, numbers, symbols)", text: $password)
                            .textFieldStyle(.roundedBorder)
                        
                        HStack {
                            Button("Sign Up") {
                                testSignUp()
                            }
                            .disabled(isLoading)
                            
                            Button("Sign In") {
                                testSignIn()
                            }
                            .disabled(isLoading)
                        }
                        .buttonStyle(.borderedProminent)
                    }
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
            }
            .padding()
            .navigationTitle("Supabase Test")
        }
    }
    
    private func testSignUp() {
        isLoading = true
        message = ""
        Task {
            let result = await supabaseService.signUp(email: email, password: password)
            await MainActor.run {
                switch result {
                case .success:
                    message = "✅ Sign up successful! Check your email for verification."
                case .failure(let error):
                    message = "❌ Sign Up Error: \(error.localizedDescription)"
                }
                isLoading = false
            }
        }
    }
    
    private func testSignIn() {
        isLoading = true
        message = ""
        Task {
            let result = await supabaseService.signIn(email: email, password: password)
            await MainActor.run {
                switch result {
                case .success:
                    message = "✅ Sign in successful!"
                case .failure(let error):
                    message = "❌ Sign In Error: \(error.localizedDescription)"
                }
                isLoading = false
            }
        }
    }
    
    private func testFetchCourses() {
        isLoading = true
        message = ""
        Task {
            do {
                let fetchedCourses = try await courseService.fetchCourses()
                await MainActor.run {
                    self.courses = fetchedCourses
                    message = "✅ Fetched \(fetchedCourses.count) courses securely"
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    message = "❌ Fetch Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    private func testCreateCourse() {
        isLoading = true
        message = ""
        Task {
            let scheduleManager = ScheduleManager()
            let scheduleId = scheduleManager.activeScheduleID ?? UUID()
            
            let testCourse = Course(
                scheduleId: scheduleId,
                name: "Test Course \(Date().timeIntervalSince1970)",
                iconName: "book.fill",
                colorHex: "007AFF"
            )
            
            do {
                let createdCourse = try await courseService.createCourse(testCourse)
                await MainActor.run {
                    message = "✅ Created course: \(createdCourse.name)"
                    // Refresh courses list
                    testFetchCourses()
                }
            } catch {
                await MainActor.run {
                    message = "❌ Create Error: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    SupabaseTestView()
}
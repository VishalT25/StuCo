import SwiftUI
import Foundation

// MARK: - AI Import Tutorial View
struct AIImportTutorialView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let scheduleID: UUID
    let onImportCompleted: (() -> Void)?
    @State private var currentStep = 0
    @State private var showingImportView = false
    
    init(scheduleID: UUID, onImportCompleted: (() -> Void)? = nil) {
        self.scheduleID = scheduleID
        self.onImportCompleted = onImportCompleted
    }
    
    private let steps = [
        TutorialStep(
            title: "Take a Screenshot",
            description: "Capture a clear image of your class schedule. Make sure all class names, times, and days are visible.",
            icon: "camera.fill",
            detail: "Your schedule can be from any source - student portal, PDF, or even a  ed schedule."
        ),
        TutorialStep(
            title: "Use AI to Parse",
            description: "Copy our special prompt and paste it into any AI assistant (ChatGPT, Claude, etc.) along with your screenshot.",
            icon: "brain.head.profile",
            detail: "The AI will analyze your schedule and convert it to a format our app can understand."
        ),
        TutorialStep(
            title: "Import Your Schedule",
            description: "Copy the AI's response and paste it back into our app. Your classes will be automatically added!",
            icon: "square.and.arrow.down",
            detail: "Just paste the JSON output and we'll handle the rest."
        ),
        TutorialStep(
            title: "Double-Check & Customize",
            description: "AI can make mistakes! Always review your imported schedule for accuracy.",
            icon: "checkmark.shield.fill",
            detail: "Check times, days, and class names. You can always edit individual classes afterward. Advanced users can customize the AI prompt to better fit their schedule format."
        )
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentStep ? themeManager.currentTheme.primaryColor : Color(.systemGray4))
                            .frame(width: 10, height: 10)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .padding(.top, 20)
                
                // Step content
                TabView(selection: $currentStep) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        TutorialStepView(step: steps[index])
                            .environmentObject(themeManager)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep > 0 {
                        Button("Previous") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                            }
                        }
                        .font(.headline)
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeManager.currentTheme.primaryColor.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Button(currentStep == steps.count - 1 ? "Get Started" : "Next") {
                        if currentStep == steps.count - 1 {
                            showingImportView = true
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep += 1
                            }
                        }
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(themeManager.currentTheme.primaryColor)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .navigationTitle("AI Schedule Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingImportView) {
            AIScheduleImportView(scheduleID: scheduleID) {
                // Callback when import is completed
                onImportCompleted?()
            }
            .environmentObject(scheduleManager)
            .environmentObject(themeManager)
        }
    }
}

struct TutorialStep {
    let title: String
    let description: String
    let icon: String
    let detail: String
}

struct TutorialStepView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let step: TutorialStep
    
    var body: some View {
        VStack(spacing: 30) {
            // Icon
            Image(systemName: step.icon)
                .font(.system(size: 80))
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .padding(.top, 40)
            
            VStack(spacing: 16) {
                Text(step.title)
                    .font(.title.bold())
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(step.description)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                
                Text(step.detail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

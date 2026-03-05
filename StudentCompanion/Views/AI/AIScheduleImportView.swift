import SwiftUI

struct AIScheduleImportView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) private var dismiss
    
    let scheduleID: UUID
    let onImportCompleted: (() -> Void)?
    @State private var importText = ""
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var showAuthAlert = false
    @State private var errorMessage = ""
    @State private var importedItemsCount = 0
    @State private var isProcessing = false
    @State private var customPrompt = ""
    @State private var showAdvancedOptions = false
    
    @StateObject private var courseManager = UnifiedCourseManager()

    init(scheduleID: UUID, onImportCompleted: (() -> Void)? = nil) {
        self.scheduleID = scheduleID
        self.onImportCompleted = onImportCompleted
    }
    
    private let defaultAIPrompt = """
You are a schedule parsing assistant. I will provide you with an image of a class schedule. Please extract ALL classes and convert them into JSON format according to the following rules.

IMPORTANT INSTRUCTIONS:
- Output only valid JSON — no text, explanations, or markdown.
- Use 24-hour time format (HH:mm) for start and end. Correct AM/PM mistakes automatically.
- Days must be abbreviated: ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"].
- If a class meets multiple days, include all days in the array.

HANDLING MULTIPLE SESSIONS OF SAME COURSE:
- If a course has multiple lectures/sessions with DIFFERENT durations, create separate items
- Use descriptive titles to distinguish sessions:
  * "Course Name - Lecture" (for standard sessions)
  * "Course Name - Extended Lecture" (for longer sessions)
  * OR append duration: "Course Name (50min)", "Course Name (80min)"
- If sessions have different locations, include in title: "Course Name - Room 204"
- Use the SAME base color for all sessions of the same course
- Create separate items even if it's the same course name

- Colors: Use "blue", "green", "orange", "red", "purple", "gray". If the extracted color is not in this list, default to "gray".
- Reminders: Default to "10m" unless specified otherwise.
- liveActivity should default to true.

Validation rules:
- start must be before end
- Times must be clamped between 00:00–23:59
- At least one day must be present
- Skip any class with missing or invalid times

Required JSON structure:

{
  "version": 1,
  "timezone": "America/New_York",
  "items": [
    {
      "title": "Class Name",
      "days": ["Mon","Wed","Fri"],
      "start": "09:00",
      "end": "10:15",
      "color": "blue",
      "reminder": "10m",
      "liveActivity": true
    }
  ]
}

Extra robustness instructions:
- Merge overlapping sessions only if the title, location, and days match exactly. Otherwise, create separate items.
- If AM/PM is ambiguous, infer based on typical class hours (7:00–22:00).
- Ensure JSON is parseable — do not output trailing commas or invalid structures.

REMEMBER: Output only JSON. NO other text.
"""
    
    private var currentPrompt: String {
        showAdvancedOptions && !customPrompt.isEmpty ? customPrompt : defaultAIPrompt
    }

    private func baseCourseName(from title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: " - ") {
            return String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private func meetingTypeAndLabel(from title: String, baseName: String) -> (MeetingType, String?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = trimmed.range(of: " - ") else {
            return (.lecture, nil)
        }
        let suffix = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        let lc = suffix.lowercased()

        if lc.contains("lab") { return (.lab, suffix) }
        if lc.contains("tutorial") { return (.tutorial, suffix) }
        if lc.contains("seminar") { return (.seminar, suffix) }
        if lc.contains("workshop") { return (.workshop, suffix) }
        if lc.contains("practicum") { return (.practicum, suffix) }
        if lc.contains("recitation") { return (.recitation, suffix) }
        if lc.contains("studio") { return (.studio, suffix) }
        if lc.contains("field") { return (.fieldwork, suffix) }
        if lc.contains("clinic") { return (.clinic, suffix) }
        if lc.contains("lecture") { return (.lecture, suffix) }

        return (.lecture, suffix.isEmpty ? nil : suffix)
    }

    private func weekdayNumbers(from days: [DayOfWeek]) -> [Int] {
        return days.map { $0.rawValue }
    }

    private func groupImportedItemsIntoCourses(_ items: [ScheduleItem], scheduleId: UUID) -> [(Course, [CourseMeeting])] {
        var groups: [String: [ScheduleItem]] = [:]
        for item in items {
            let key = baseCourseName(from: item.title)
            groups[key, default: []].append(item)
        }

        var results: [(Course, [CourseMeeting])] = []

        for (courseName, groupItems) in groups {
            guard let first = groupItems.first else { continue }
            let courseColorHex = first.color.toHex() ?? "007AFF"

            let course = Course(
                scheduleId: scheduleId,
                name: courseName,
                iconName: "book.closed.fill",
                colorHex: courseColorHex,
                creditHours: 3.0,
                courseCode: "",
                section: "",
                instructor: "",
                location: ""
            )

            var meetings: [CourseMeeting] = []
            for item in groupItems {
                let (type, label) = meetingTypeAndLabel(from: item.title, baseName: courseName)
                let meeting = CourseMeeting(
                    courseId: course.id,
                    scheduleId: scheduleId,
                    meetingType: type,
                    meetingLabel: label,
                    startTime: item.startTime,
                    endTime: item.endTime,
                    daysOfWeek: weekdayNumbers(from: item.daysOfWeek),
                    location: item.location,
                    instructor: item.instructor,
                    reminderTime: item.reminderTime,
                    isLiveActivityEnabled: item.isLiveActivityEnabled,
                )
                meetings.append(meeting)
            }

            results.append((course, meetings))
        }

        return results
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Disclaimer
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                            Text("Important Reminder")
                                .font(.headline.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                        
                        Text("AI can make mistakes! Always double-check your imported schedule for accuracy. Verify class times, days, and names before relying on the schedule.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.orange.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    // Step 1: Copy Prompt
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "1.circle.fill")
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                                .font(.title2)
                            Text("Copy the AI Prompt")
                                .font(.headline.weight(.semibold))
                        }
                        
                        Text("Copy this prompt and use it with your AI assistant along with your schedule screenshot:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // AI Warning
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.footnote)
                                .foregroundColor(.orange)
                            Text("AI may be inaccurate. Please double-check all imported information.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(0.1))
                        )

                        // Advanced Options Toggle
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showAdvancedOptions.toggle()
                                if showAdvancedOptions && customPrompt.isEmpty {
                                    customPrompt = defaultAIPrompt
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: showAdvancedOptions ? "chevron.down" : "chevron.right")
                                    .font(.caption)
                                Text("Advanced: Customize Prompt")
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        }
                        
                        VStack(alignment: .trailing, spacing: 12) {
                            if showAdvancedOptions {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("If you know what you're doing, feel free to tune the prompt to your liking!")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    TextEditor(text: $customPrompt)
                                        .font(.system(.caption, design: .monospaced))
                                        .frame(minHeight: 150)
                                        .padding(8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                        )
                                    
                                    Button("Reset to Default") {
                                        customPrompt = defaultAIPrompt
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                            } else {
                                ScrollView {
                                    Text(currentPrompt)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                                .frame(maxHeight: 200)
                            }
                            
                            Button(action: copyPrompt) {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy Prompt")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(themeManager.currentTheme.primaryColor)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    )
                    
                    // Step 2: Paste Result (unchanged)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "2.circle.fill")
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                                .font(.title2)
                            Text("Paste AI Response")
                                .font(.headline.weight(.semibold))
                        }
                        
                        Text("After getting the JSON response from your AI, paste it below:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .trailing, spacing: 12) {
                            TextEditor(text: $importText)
                                .font(.system(.caption, design: .monospaced))
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .frame(minHeight: 150)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                )
                            
                            HStack(spacing: 12) {
                                Button(action: pasteFromClipboard) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.on.clipboard")
                                        Text("Paste")
                                    }
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(themeManager.currentTheme.primaryColor.opacity(0.1))
                                    .cornerRadius(6)
                                }
                                
                                Button(action: clearText) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "trash")
                                        Text("Clear")
                                    }
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(6)
                                }
                                
                                Spacer()
                            }
                            
                            if importText.isEmpty {
                                Text("Paste your JSON here...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 40)
                                    .allowsHitTesting(false)
                                    .offset(y: -120)
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    )
                    
                    // Import Button
                    Button(action: importSchedule) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                            }
                            Text(isProcessing ? "Processing..." : "Import Schedule")
                        }
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing || !supabaseService.isAuthenticated
                                      ? Color.gray
                                      : themeManager.currentTheme.primaryColor)
                        )
                    }
                    .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing || !supabaseService.isAuthenticated)
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Import with AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Import Successful! 🎉", isPresented: $showingSuccessAlert) {
            Button("OK") {
                scheduleManager.setActiveSchedule(scheduleID)
                onImportCompleted?()
                dismiss()
            }
        } message: {
            Text("Successfully imported \(importedItemsCount) class\(importedItemsCount == 1 ? "" : "es") to your schedule!")
        }
        .alert("Import Failed", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Sign In Required", isPresented: $showAuthAlert) {
            Button("OK") { }
        } message: {
            Text("Please sign in to import schedules.")
        }
        .onAppear {
            customPrompt = defaultAIPrompt
            courseManager.setScheduleManager(scheduleManager)
            scheduleManager.setCourseManager(courseManager)
        }
    }
    
    private func copyPrompt() {
        UIPasteboard.general.string = currentPrompt
        
        // Show brief haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func pasteFromClipboard() {
        if let clipboardString = UIPasteboard.general.string {
            importText = clipboardString
        }
        
        // Show brief haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func clearText() {
        importText = ""
        
        // Show brief haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func importSchedule() {
        guard supabaseService.isAuthenticated else {
            showAuthAlert = true
            return
        }
        isProcessing = true
        
        Task {
            do {
                let scheduleItems = try ScheduleImportParser.parseScheduleJSON(importText.trimmingCharacters(in: .whitespacesAndNewlines))
                
                await MainActor.run {
                    isProcessing = true
                }

                let grouped = groupImportedItemsIntoCourses(scheduleItems, scheduleId: scheduleID)
                var createdCount = 0

                for (course, meetings) in grouped {
                    do {
                        try await courseManager.createCourseWithMeetings(course, meetings: meetings)
                        createdCount += 1
                    } catch {
                        // Continue with next course; optionally collect errors
                    }
                }

                await MainActor.run {
                    importedItemsCount = createdCount
                    isProcessing = false
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                    showingErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Preview Helper
struct AIImportPreview: View {
    @StateObject private var scheduleManager = ScheduleManager()
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        AIScheduleImportView(scheduleID: UUID())
            .environmentObject(scheduleManager)
            .environmentObject(themeManager)
            .environmentObject(SupabaseService.shared)
    }
}

#Preview {
    AIImportPreview()
}

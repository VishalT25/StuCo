import SwiftUI

struct ModernAddMeetingSheet: View {
    let courseName: String
    let courseColor: Color
    let scheduleType: ScheduleType
    let isRotatingSchedule: Bool
    let onSave: (CourseMeeting) -> Void

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedDays: Set<Int>
    @State private var location: String
    @State private var instructor: String

    @State private var selectedRotationDay: Int?
    @State private var rotationLabel: String

    @State private var meetingType: MeetingType = .lecture
    @State private var meetingLabel: String = ""
    @State private var startTime: Date = Date()
    @State private var endTime: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var reminderTime: ReminderTime = .fifteenMinutes
    @State private var isLiveActivityEnabled = true
    @State private var animationOffset: CGFloat = 0
    @State private var showContent: Bool

    private let days = Array(1...7)

    init(courseName: String, courseColor: Color, scheduleType: ScheduleType, isRotatingSchedule: Bool, onSave: @escaping (CourseMeeting) -> Void) {
        self.courseName = courseName
        self.courseColor = courseColor
        self.scheduleType = scheduleType
        self.isRotatingSchedule = isRotatingSchedule
        self.onSave = onSave

        _selectedDays = State(initialValue: Set([]))
        _location = State(initialValue: "")
        _instructor = State(initialValue: "")
        _selectedRotationDay = State(initialValue: nil)
        _rotationLabel = State(initialValue: "")
        _showContent = State(initialValue: false)
    }

    private var canSave: Bool {
        guard startTime < endTime else { return false }

        if isRotatingSchedule {
            return selectedRotationDay != nil
        } else {
            return !selectedDays.isEmpty
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                spectacularBackground

                ScrollView {
                    LazyVStack(spacing: 24) {
                        heroSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : -30)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.075), value: showContent)

                        VStack(spacing: 20) {
                            meetingTypeSection
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 50)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: showContent)

                            timeSection
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 50)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.225), value: showContent)

                            if isRotatingSchedule {
                                rotationDaySection
                                    .opacity(showContent ? 1 : 0)
                                    .offset(y: showContent ? 0 : 50)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: showContent)
                            } else {
                                daysSection
                                    .opacity(showContent ? 1 : 0)
                                    .offset(y: showContent ? 0 : 50)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: showContent)
                            }

                            detailsSection
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 50)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.375), value: showContent)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 100)
                    }
                    .padding(.top, 20)
                }
                .scrollBounceBehavior(.basedOnSize)

                floatingActionButton
            }
        }
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.secondary)
            }
        }
        .onAppear {
            startAnimations()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.225) {
                showContent = true
            }
        }
    }

    private var spectacularBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    courseColor.opacity(colorScheme == .dark ? 0.15 : 0.05),
                    courseColor.opacity(colorScheme == .dark ? 0.08 : 0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                courseColor.opacity(0.1 - Double(index) * 0.015),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40 + CGFloat(index * 10)
                        )
                    )
                    .frame(width: 80 + CGFloat(index * 20), height: 80 + CGFloat(index * 20))
                    .offset(
                        x: sin(animationOffset * 0.01 + Double(index)) * 50,
                        y: cos(animationOffset * 0.008 + Double(index)) * 30
                    )
                    .opacity(0.3)
                    // PERF FIX: Removed blur effect
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 9) {
                Text("Add Meeting")
                    .font(.forma(.largeTitle, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                courseColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                HStack(spacing: 8) {
                    Text("for")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)

                    Text(courseName)
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(courseColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(courseColor.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(courseColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                }

                Text("Schedule when this course meets with all the important details.")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    courseColor.opacity(0.3),
                                    courseColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: courseColor.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0.15),
                    // PERF FIX: Reduced shadow
                    radius: 6,
                    x: 0,
                    y: 3
                )
        )
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private var meetingTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Meeting Type")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            meetingTypeGrid

            customLabelField
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var meetingTypeGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
            ForEach(MeetingType.allCases, id: \.self) { type in
                meetingTypeButton(for: type)
            }
        }
    }

    private func meetingTypeButton(for type: MeetingType) -> some View {
        Button(action: { meetingType = type }) {
            HStack(spacing: 12) {
                Image(systemName: type.iconName)
                    .font(.forma(.title3))
                    .foregroundColor(meetingType == type ? .white : type.color)

                Text(type.displayName)
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(meetingType == type ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(meetingTypeButtonBackground(for: type))
        }
        .buttonStyle(.plain)
    }

    private func meetingTypeButtonBackground(for type: MeetingType) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(meetingType == type
                  ? AnyShapeStyle(type.color)
                  : AnyShapeStyle(Color(.systemBackground).opacity(0.9)))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        meetingType == type ? type.color.opacity(0.3) : Color.secondary.opacity(0.2),
                        lineWidth: meetingType == type ? 2 : 1
                    )
            )
            .shadow(
                color: meetingType == type ? type.color.opacity(0.3) : .clear,
                radius: meetingType == type ? 6 : 0,
                x: 0,
                y: meetingType == type ? 3 : 0
            )
    }

    private var customLabelField: some View {
        TextField("Optional custom name", text: $meetingLabel)
            .font(.forma(.body, weight: .medium))
            .foregroundColor(.primary)
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            )
    }

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Time")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Start")
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.secondary)

                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                                )
                        )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("End")
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.secondary)

                    DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var rotationDaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rotation Day")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                Button(action: {
                    selectedRotationDay = 1
                    rotationLabel = "Day 1"
                }) {
                    VStack(spacing: 8) {
                        Text("Day 1")
                            .font(.forma(.headline, weight: .semibold))
                            .foregroundColor(selectedRotationDay == 1 ? .white : .primary)
                        Text("Odd dates")
                            .font(.forma(.caption))
                            .foregroundColor(selectedRotationDay == 1 ? .white.opacity(0.8) : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedRotationDay == 1 ? AnyShapeStyle(courseColor) : AnyShapeStyle(Color(.systemBackground).opacity(0.9)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedRotationDay == 1 ? courseColor.opacity(0.3) : courseColor.opacity(0.2),
                                        lineWidth: selectedRotationDay == 1 ? 2 : 1
                                    )
                            )
                            .shadow(
                                color: selectedRotationDay == 1 ? courseColor.opacity(0.3) : .clear,
                                radius: selectedRotationDay == 1 ? 6 : 0,
                                x: 0,
                                y: selectedRotationDay == 1 ? 3 : 0
                            )
                    )
                }
                .buttonStyle(.plain)

                Button(action: {
                    selectedRotationDay = 2
                    rotationLabel = "Day 2"
                }) {
                    VStack(spacing: 8) {
                        Text("Day 2")
                            .font(.forma(.headline, weight: .semibold))
                            .foregroundColor(selectedRotationDay == 2 ? .white : .primary)
                        Text("Even dates")
                            .font(.forma(.caption))
                            .foregroundColor(selectedRotationDay == 2 ? .white.opacity(0.8) : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedRotationDay == 2 ? AnyShapeStyle(courseColor) : AnyShapeStyle(Color(.systemBackground).opacity(0.9)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        selectedRotationDay == 2 ? courseColor.opacity(0.3) : courseColor.opacity(0.2),
                                        lineWidth: selectedRotationDay == 2 ? 2 : 1
                                    )
                            )
                            .shadow(
                                color: selectedRotationDay == 2 ? courseColor.opacity(0.3) : .clear,
                                radius: selectedRotationDay == 2 ? 6 : 0,
                                x: 0,
                                y: selectedRotationDay == 2 ? 3 : 0
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var daysSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Days of Week")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(days, id: \.self) { day in
                    Button(action: {
                        if selectedDays.contains(day) {
                            selectedDays.remove(day)
                        } else {
                            selectedDays.insert(day)
                        }
                    }) {
                        Text(String(Calendar.current.shortWeekdaySymbols[(day - 1) % 7]))
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(selectedDays.contains(day) ? .white : .secondary)
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedDays.contains(day) ? AnyShapeStyle(courseColor) : AnyShapeStyle(Color(.systemBackground).opacity(0.9)))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                selectedDays.contains(day) ? courseColor.opacity(0.3) : Color.secondary.opacity(0.2),
                                                lineWidth: selectedDays.contains(day) ? 2 : 1
                                            )
                                    )
                                    .shadow(
                                        color: selectedDays.contains(day) ? courseColor.opacity(0.3) : .clear,
                                        radius: selectedDays.contains(day) ? 6 : 0,
                                        x: 0,
                                        y: selectedDays.contains(day) ? 3 : 0
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Additional Details")
                    .font(.forma(.title2, weight: .bold))

                Spacer()

                Text("Optional")
                    .font(.forma(.caption))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                            .overlay(
                                Capsule()
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    )
            }

            VStack(spacing: 12) {
                TextField("Location", text: $location)
                    .font(.forma(.body, weight: .medium))
                    .foregroundColor(.primary)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    )

                TextField("Instructor", text: $instructor)
                    .font(.forma(.body, weight: .medium))
                    .foregroundColor(.primary)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var floatingActionButton: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                Button(action: saveMeeting) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2.bold())
                            .foregroundColor(.white)

                        Text("Save Meeting")
                            .font(.forma(.headline, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: canSave ? [courseColor, courseColor.opacity(0.8)] :
                                               [.secondary.opacity(0.6), .secondary.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            if canSave {
                                Capsule()
                                    .fill(
                                        AngularGradient(
                                            colors: [
                                                Color.clear,
                                                Color.white.opacity(0.3),
                                                Color.clear,
                                                Color.clear
                                            ],
                                            center: .center,
                                            angle: .degrees(animationOffset * 0.5)
                                        )
                                    )
                            }
                        }
                        .shadow(
                            color: canSave ? courseColor.opacity(0.4) : .clear,
                            radius: 6, // PERF FIX: Reduced
                            x: 0,
                            y: 8
                        )
                    )
                }
                .disabled(!canSave)
                .buttonStyle(.plain)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: canSave)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 32)
        }
    }

    // Removed continuous animations for performance - they were causing text input lag
    private func startAnimations() {
        // No continuous animations - keeps text input smooth
    }

    private func saveMeeting() {
        // Generate a stable meeting ID that will persist through the save process
        let meetingId = UUID()
        let meeting: CourseMeeting

        if isRotatingSchedule {
            // FIXED: Use a nil-safe placeholder for courseId - will be set properly when course is saved
            // The courseId will be assigned in updateExistingCourse() or createNewCourse()
            meeting = CourseMeeting(
                id: meetingId,
                userId: SupabaseService.shared.currentUser?.id,
                courseId: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, // Placeholder, will be replaced
                scheduleId: nil, // Will be set when course is saved
                meetingType: meetingType,
                meetingLabel: meetingLabel.isEmpty ? nil : meetingLabel,
                isRotating: true,
                rotationLabel: rotationLabel,
                rotationPattern: nil,
                rotationIndex: selectedRotationDay,
                startTime: startTime,
                endTime: endTime,
                daysOfWeek: [], // Empty for rotating schedules
                location: location,
                instructor: instructor,
                reminderTime: .fifteenMinutes,
                isLiveActivityEnabled: true,
            )
        } else {
            meeting = CourseMeeting(
                id: meetingId,
                userId: SupabaseService.shared.currentUser?.id,
                courseId: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, // Placeholder, will be replaced
                scheduleId: nil, // Will be set when course is saved
                meetingType: meetingType,
                meetingLabel: meetingLabel.isEmpty ? nil : meetingLabel,
                isRotating: false,
                rotationLabel: nil,
                rotationPattern: nil,
                rotationIndex: nil,
                startTime: startTime,
                endTime: endTime,
                daysOfWeek: Array(selectedDays),
                location: location,
                instructor: instructor,
                reminderTime: .fifteenMinutes,
                isLiveActivityEnabled: true,
            )
        }

        onSave(meeting)
        dismiss()
    }
}

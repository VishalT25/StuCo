import SwiftUI

struct MeetingEditorSheet: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var draft: ScheduleItem
    let scheduleType: ScheduleType
    let rotationAssignment: (UUID) -> Int
    let updateRotationAssignment: (UUID, Int) -> Void
    let onSave: (ScheduleItem) -> Void
    let onCancel: () -> Void

    @State private var animationOffset: CGFloat = 0
    @State private var showContent = false

    // Computed properties for editing days
    @State private var selectedDays: Set<DayOfWeek>
    @State private var selectedRotationDay: Int

    private var courseColor: Color {
        draft.color
    }

    init(
        initial: ScheduleItem,
        scheduleType: ScheduleType,
        rotationAssignment: @escaping (UUID) -> Int,
        updateRotationAssignment: @escaping (UUID, Int) -> Void,
        onSave: @escaping (ScheduleItem) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: initial)
        self.scheduleType = scheduleType
        self.rotationAssignment = rotationAssignment
        self.updateRotationAssignment = updateRotationAssignment
        self.onSave = onSave
        self.onCancel = onCancel

        _selectedDays = State(initialValue: Set(initial.daysOfWeek))
        _selectedRotationDay = State(initialValue: rotationAssignment(initial.id))
    }

    private var canSave: Bool {
        guard draft.startTime < draft.endTime else { return false }

        if scheduleType == .rotating {
            return selectedRotationDay >= 1 && selectedRotationDay <= 2
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
                            meetingTitleSection
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 50)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: showContent)

                            timeSection
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 50)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.225), value: showContent)

                            if scheduleType == .rotating {
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
                }
                .scrollBounceBehavior(.basedOnSize)

                floatingActionButton
            }
        }
        .navigationBarHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    onCancel()
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
                    .blur(radius: CGFloat(index * 2))
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 9) {
                Text("Edit Meeting")
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

                Text("Update the meeting details and schedule.")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
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
                    radius: 20,
                    x: 0,
                    y: 10
                )
        )
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private var meetingTitleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Meeting Details")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Meeting title", text: $draft.title)
                .font(.forma(.body, weight: .medium))
                .foregroundColor(.primary)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    draft.title.isEmpty ? Color.secondary.opacity(0.3) : courseColor.opacity(0.6),
                                    lineWidth: draft.title.isEmpty ? 1 : 2
                                )
                        )
                )
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(courseColor.opacity(0.2), lineWidth: 1)
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

                    DatePicker("", selection: $draft.startTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
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

                    DatePicker("", selection: $draft.endTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
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
                .fill(.regularMaterial)
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
                    updateRotationAssignment(draft.id, 1)
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
                            .fill(selectedRotationDay == 1 ? AnyShapeStyle(courseColor) : AnyShapeStyle(.ultraThinMaterial))
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
                    updateRotationAssignment(draft.id, 2)
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
                            .fill(selectedRotationDay == 2 ? AnyShapeStyle(courseColor) : AnyShapeStyle(.ultraThinMaterial))
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
                .fill(.regularMaterial)
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
                ForEach(DayOfWeek.allCases, id: \.self) { day in
                    Button(action: {
                        if selectedDays.contains(day) {
                            selectedDays.remove(day)
                        } else {
                            selectedDays.insert(day)
                        }
                        draft.daysOfWeek = Array(selectedDays).sorted { $0.rawValue < $1.rawValue }
                    }) {
                        Text(day.abbreviation)
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(selectedDays.contains(day) ? .white : .primary)
                            .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedDays.contains(day) ? AnyShapeStyle(courseColor) : AnyShapeStyle(.ultraThinMaterial))
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
                .fill(.regularMaterial)
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
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    )
            }

            VStack(spacing: 12) {
                TextField("Location", text: $draft.location)
                    .font(.forma(.body, weight: .medium))
                    .foregroundColor(.primary)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    )

                TextField("Instructor", text: $draft.instructor)
                    .font(.forma(.body, weight: .medium))
                    .foregroundColor(.primary)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
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
                .fill(.regularMaterial)
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

                        Text("Save Changes")
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
                            radius: 16,
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
        onSave(draft)
        dismiss()
    }
}

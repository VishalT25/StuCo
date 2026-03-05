import SwiftUI

struct EventEditView: View {
    let event: Event
    let isNew: Bool
    
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var title: String
    @State private var date: Date
    @State private var categoryId: UUID?
    @State private var reminderTime: ReminderTime
    @State private var syncToApple: Bool
    @State private var syncToGoogle: Bool
    @State private var isCompleted: Bool
    @State private var showDeleteAlert = false
    
    private var currentCategory: Category? {
        guard let categoryId = categoryId else { return nil }
        return viewModel.categories.first { $0.id == categoryId }
    }
    
    private var primaryColor: Color {
        currentCategory?.color ?? themeManager.currentTheme.primaryColor
    }
    
    init(event: Event, isNew: Bool = false) {
        self.event = event
        self.isNew = isNew
        
        _title = State(initialValue: event.title)
        _date = State(initialValue: event.date)
        _categoryId = State(initialValue: event.categoryId)
        _reminderTime = State(initialValue: event.reminderTime)
        _syncToApple = State(initialValue: event.syncToAppleCalendar)
        _syncToGoogle = State(initialValue: event.syncToGoogleCalendar)
        _isCompleted = State(initialValue: event.isCompleted)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Spectacular animated background
                spectacularBackground
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 21) {
                        // Hero header section
                        heroSection
                            .padding(.top, 30)
                        
                        // Reminder details form
                        reminderFormSection
                        
                        // Settings section
                        settingsSection
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
                
                // Floating action buttons
                floatingActionButtons
            }
        }
        .navigationBarHidden(true)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
        .alert("Delete Reminder", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteEvent(event)
                dismiss()
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .navigationTitle("Edit Event")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveEvent()
                    dismiss()
                }
                .disabled(title.isEmpty)
                .foregroundColor(title.isEmpty ? .gray : .blue)
            }
        }
    }
    
    // MARK: - Spectacular Background
    private var spectacularBackground: some View {
        ZStack {
            // Base gradient background
            LinearGradient(
                colors: [
                    primaryColor.opacity(colorScheme == .dark ? 0.15 : 0.05),
                    primaryColor.opacity(colorScheme == .dark ? 0.08 : 0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated floating shapes
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                primaryColor.opacity(0.1 - Double(index) * 0.015),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40 + CGFloat(index * 10)
                        )
                    )
                    .frame(width: 80 + CGFloat(index * 20), height: 80 + CGFloat(index * 20))
                    .offset(
                        x: sin(Double(index) * 0.5) * 50,
                        y: cos(Double(index) * 0.3) * 30
                    )
                    .opacity(0.3)
                    // PERF FIX: Removed blur
            }
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 9) {
                Text(isNew ? "New Reminder" : "Edit Reminder")
                    .font(.forma(.largeTitle, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                primaryColor,
                                primaryColor.opacity(0.7)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text(isNew ? "Never miss an important task or deadline" : "Update your reminder details")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    primaryColor.opacity(0.3),
                                    primaryColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: primaryColor.opacity(colorScheme == .dark ? 0.3 : 0.15),
                    radius: 6, // PERF FIX
                    x: 0,
                    y: 10
                )
        )
    }
    
    // MARK: - Reminder Form Section
    private var reminderFormSection: some View {
        VStack(spacing: 24) {
            Text("Reminder Details")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 20) {
                // Title Field
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.forma(.subheadline))
                            .foregroundColor(primaryColor)
                            .frame(width: 20)
                        Text("Title")
                            .font(.forma(.subheadline, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    TextField("Reminder title", text: $title)
                        .font(.forma(.body, weight: .medium))
                        .foregroundColor(.primary)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                
                // Date & Time Picker
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.forma(.subheadline))
                            .foregroundColor(primaryColor)
                            .frame(width: 20)
                        Text("Date & Time")
                            .font(.forma(.subheadline, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        DatePicker("Select date and time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(primaryColor)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                // Category Picker
                if !viewModel.categories.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "tag")
                                .font(.forma(.subheadline))
                                .foregroundColor(primaryColor)
                                .frame(width: 20)
                            Text("Category")
                                .font(.forma(.subheadline, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Picker("Category", selection: $categoryId) {
                                Text("No Category")
                                    .tag(nil as UUID?)
                                ForEach(viewModel.categories) { category in
                                    HStack {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(category.color)
                                            .frame(width: 12, height: 12)
                                        Text(category.name)
                                            .font(.forma(.body))
                                    }
                                    .tag(category.id as UUID?)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(primaryColor)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                
                // Status Toggle (for existing events)
                if !isNew {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.forma(.subheadline))
                                .foregroundColor(isCompleted ? .green : primaryColor)
                                .frame(width: 20)
                            Text("Status")
                                .font(.forma(.subheadline, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        
                        Toggle(isOn: $isCompleted) {
                            Text("Mark as completed")
                                .font(.forma(.body))
                                .foregroundColor(.primary)
                        }
                        .tint(primaryColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Settings")
                    .font(.forma(.title2, weight: .bold))
                
                Spacer()
                
                Text("Optional")
                    .font(.forma(.caption))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                            .overlay(
                                Capsule()
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            
            VStack(spacing: 16) {
                // Notification Setting
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill")
                            .font(.forma(.subheadline))
                            .foregroundColor(primaryColor)
                            .frame(width: 20)
                        Text("Notification")
                            .font(.forma(.subheadline, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Picker("Notification", selection: $reminderTime) {
                            ForEach(ReminderTime.allCases, id: \.self) { rt in
                                Text(rt.displayName)
                                    .font(.forma(.body))
                                    .tag(rt)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(primaryColor)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                // Calendar Sync Toggles
                Toggle(isOn: $syncToApple) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.forma(.subheadline))
                            .foregroundColor(primaryColor)
                            .frame(width: 20)
                        Text("Sync to Apple Calendar")
                            .font(.forma(.subheadline, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
                .tint(primaryColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                        )
                )
                
                Toggle(isOn: $syncToGoogle) {
                    HStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.forma(.subheadline))
                            .foregroundColor(primaryColor)
                            .frame(width: 20)
                        Text("Sync to Google Calendar")
                            .font(.forma(.subheadline, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
                .tint(primaryColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Floating Action Buttons
    private var floatingActionButtons: some View {
        VStack {
            Spacer()
            
            HStack {
                // Delete Button (only for existing events)
                if !isNew {
                    Button(action: {
                        showDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.red, .red.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    
                                    Circle()
                                        .fill(
                                            AngularGradient(
                                                colors: [
                                                    Color.clear,
                                                    Color.white.opacity(0.3),
                                                    Color.clear,
                                                    Color.clear
                                                ],
                                                center: .center,
                                                angle: .degrees(45)
                                            )
                                        )
                                }
                                .shadow(color: .red.opacity(0.4), radius: 6, x: 0, y: 4)
                                .shadow(color: .red.opacity(0.2), radius: 8, x: 0, y: 4)
                            )
                    }
                    .buttonStyle(EventsBounceButtonStyle())
                }
                
                Spacer()
                
                // Save Button with enhanced styling
                Button(action: saveEvent) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Text(isNew ? "Add Reminder" : "Save Changes")
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
                                        colors: [primaryColor, primaryColor.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
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
                                        angle: .degrees(180)
                                    )
                                )
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        .shadow(
                            color: primaryColor.opacity(0.4),
                            radius: 6, // PERF FIX
                            x: 0,
                            y: 8
                        )
                        .shadow(
                            color: primaryColor.opacity(0.2),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                    )
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(EventsBounceButtonStyle())
                .scaleEffect(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.95 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: title.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    private func saveEvent() {
        let updatedEvent = Event(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            categoryId: categoryId,
            reminderTime: reminderTime,
            isCompleted: isCompleted,
            externalIdentifier: event.externalIdentifier,
            sourceName: event.sourceName,
            syncToAppleCalendar: syncToApple,
            syncToGoogleCalendar: syncToGoogle
        )
        
        // Preserve the original event ID if not new
        if !isNew {
            var eventToSave = updatedEvent
            eventToSave.id = event.id
            eventToSave.appleCalendarIdentifier = event.appleCalendarIdentifier
            eventToSave.googleCalendarIdentifier = event.googleCalendarIdentifier
            viewModel.updateEvent(eventToSave)
        } else {
            viewModel.addEvent(updatedEvent)
        }
        
        dismiss()
    }
}
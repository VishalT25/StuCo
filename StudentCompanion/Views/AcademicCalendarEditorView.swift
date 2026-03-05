import SwiftUI

struct AcademicCalendarEditorView: View {
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var academicCalendar: AcademicCalendar?
    @State private var showingAddBreak = false
    @State private var breakToEdit: AcademicBreak?
    @State private var showingDeleteAlert = false
    @State private var breakToDelete: AcademicBreak?
    
    // Animation states
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    @State private var bounceAnimation: Double = 0
    @State private var showContent = false
    
    // Performance optimization
    @State private var isViewActive = true
    @State private var shouldRenderAnimations = true

    private var sortedBreaks: [AcademicBreak] {
        academicCalendar?.breaks.sorted { $0.startDate < $1.startDate } ?? []
    }
    
    private var currentTheme: AppTheme {
        themeManager.currentTheme
    }

    var body: some View {
        ZStack {
            if isViewActive {
                // Spectacular animated background
                spectacularBackground
                
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // Hero header section
                            heroSection
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : -30)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.075), value: showContent)
                            
                            // Content section
                            if sortedBreaks.isEmpty {
                                emptyStateView
                                    .opacity(showContent ? 1 : 0)
                                    .offset(y: showContent ? 0 : 50)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: showContent)
                            } else {
                                breaksListView
                                    .opacity(showContent ? 1 : 0)
                                    .offset(y: showContent ? 0 : 50)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: showContent)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 120)
                    }
                }
                
                // Floating action button
                floatingActionButton
            } else {
                // Placeholder view when inactive
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
            }
        }
        .navigationTitle("Manage Breaks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { 
                    dismiss() 
                }
            }
        }
        .sheet(isPresented: $showingAddBreak) {
            CreateBreakView(calendar: Binding(
                get: { academicCalendar ?? AcademicCalendar.sampleCalendar },
                set: { academicCalendar = $0 }
            ))
            .environmentObject(themeManager)
        }
        .sheet(item: $breakToEdit) { academicBreak in
            EditBreakView(
                calendar: Binding(
                    get: { academicCalendar ?? AcademicCalendar.sampleCalendar },
                    set: { academicCalendar = $0 }
                ),
                academicBreak: academicBreak
            )
            .environmentObject(themeManager)
        }
        .alert("Delete Break", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                breakToDelete = nil
            }
            Button("Delete", role: .destructive) {
                deleteBreak()
            }
        } message: {
            if let break_ = breakToDelete {
                Text("Are you sure you want to delete '\(break_.name)'? This cannot be undone.")
            }
        }
        .onAppear {
            isViewActive = true
            shouldRenderAnimations = true
            startAnimations()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.225) {
                showContent = true
            }
        }
        .onDisappear {
            stopAnimations()
            shouldRenderAnimations = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isViewActive = false
            }
        }
        .onChange(of: isViewActive) { _, newValue in
            if newValue {
                shouldRenderAnimations = true
                startAnimations()
            } else {
                shouldRenderAnimations = false
                stopAnimations()
            }
        }
    }
    
    // MARK: - Spectacular Background
    private var spectacularBackground: some View {
        ZStack {
            // Base gradient background
            LinearGradient(
                colors: [
                    currentTheme.primaryColor.opacity(colorScheme == .dark ? 0.15 : 0.05),
                    currentTheme.primaryColor.opacity(colorScheme == .dark ? 0.08 : 0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated floating shapes - only render if active
            if shouldRenderAnimations {
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    currentTheme.primaryColor.opacity(0.1 - Double(index) * 0.015),
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
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 9) {
                Text("Breaks & Holidays")
                    .font(.forma(.largeTitle, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                currentTheme.primaryColor,
                                currentTheme.secondaryColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                if let calendar = academicCalendar {
                    HStack(spacing: 8) {
                        Text("for")
                            .font(.forma(.subheadline))
                            .foregroundColor(.secondary)
                        
                        Text(calendar.name)
                            .font(.forma(.subheadline, weight: .medium))
                            .foregroundColor(currentTheme.primaryColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(currentTheme.primaryColor.opacity(0.1))
                                    .overlay(
                                        Capsule()
                                            .stroke(currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                }
                
                Text("Manage academic breaks and holidays to ensure accurate scheduling throughout the year.")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
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
                                    currentTheme.primaryColor.opacity(0.3),
                                    currentTheme.primaryColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: currentTheme.primaryColor.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0.15),
                    radius: 20,
                    x: 0,
                    y: 10
                )
        )
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 32) {
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    currentTheme.primaryColor.opacity(0.1 - Double(index) * 0.025),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 70 + CGFloat(index * 25)
                            )
                        )
                        .frame(width: 140 + CGFloat(index * 50), height: 140 + CGFloat(index * 50))
                        .scaleEffect(pulseAnimation + Double(index) * 0.06)
                }
                
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    currentTheme.primaryColor,
                                    currentTheme.secondaryColor
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                        .overlay(
                            Circle()
                                .fill(
                                    AngularGradient(
                                        colors: [
                                            Color.clear,
                                            Color.white.opacity(0.5),
                                            Color.clear,
                                            Color.clear
                                        ],
                                        center: .center,
                                        angle: .degrees(animationOffset * 0.6)
                                    )
                                )
                        )
                        .shadow(
                            color: currentTheme.primaryColor.opacity(0.4),
                            radius: 20, x: 0, y: 10
                        )
                    
                    Image(systemName: "calendar.badge.minus")
                        .font(.forma(.title, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            
            VStack(spacing: 16) {
                Text("No Breaks Added")
                    .font(.forma(.title2, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("Add breaks and holidays to help manage your schedule more effectively throughout the academic year.")
                    .font(.forma(.body))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            }
            
            Button(action: { showingAddBreak = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.forma(.title3, weight: .bold))
                    
                    Text("Add First Break")
                        .font(.forma(.headline, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    ZStack {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        currentTheme.primaryColor,
                                        currentTheme.secondaryColor.opacity(0.8)
                                    ],
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
                                    angle: .degrees(animationOffset * 0.5)
                                )
                            )
                    }
                    .shadow(
                        color: currentTheme.primaryColor.opacity(0.4),
                        radius: 16, x: 0, y: 8
                    )
                )
            }
            .buttonStyle(BounceButtonStyle())
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Breaks List View
    private var breaksListView: some View {
        VStack(spacing: 20) {
            Text("Configured Breaks")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVStack(spacing: 16) {
                ForEach(sortedBreaks, id: \.id) { academicBreak in
                    ModernBreakCard(
                        academicBreak: academicBreak,
                        onEdit: {
                            breakToEdit = academicBreak
                        },
                        onDelete: {
                            breakToDelete = academicBreak
                            showingDeleteAlert = true
                        }
                    )
                    .environmentObject(themeManager)
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
                        .stroke(currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button(action: {
                    showingAddBreak = true
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        
                        Text("Add Break")
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
                                        colors: [currentTheme.primaryColor, currentTheme.primaryColor.opacity(0.8)],
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
                                        angle: .degrees(animationOffset * 0.5)
                                    )
                                )
                        }
                        .shadow(
                            color: currentTheme.primaryColor.opacity(0.4),
                            radius: 16,
                            x: 0,
                            y: 8
                        )
                        .scaleEffect(bounceAnimation * 0.1 + 0.9)
                    )
                }
                .buttonStyle(BounceButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Helper Methods
    private func startAnimations() {
        guard shouldRenderAnimations else { return }
        
        withAnimation(.linear(duration: 22.5).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
        
        withAnimation(.easeInOut(duration: 2.25).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.1
        }
    }
    
    private func stopAnimations() {
        withAnimation(.linear(duration: 0)) {
            animationOffset = 0
        }
        
        withAnimation(.linear(duration: 0)) {
            pulseAnimation = 1.0
        }
        shouldRenderAnimations = false
    }
    
    private func deleteBreak() {
        guard let breakToDelete = breakToDelete else { return }
        academicCalendar?.breaks.removeAll { $0.id == breakToDelete.id }
        if let updated = academicCalendar {
            academicCalendarManager.updateCalendar(updated)
        }
        self.breakToDelete = nil
    }
}

// MARK: - Modern Break Card
struct ModernBreakCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    let academicBreak: AcademicBreak
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var currentTheme: AppTheme {
        themeManager.currentTheme
    }
    
    private var durationText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if Calendar.current.isDate(academicBreak.startDate, inSameDayAs: academicBreak.endDate) {
            return formatter.string(from: academicBreak.startDate)
        } else {
            return "\(formatter.string(from: academicBreak.startDate)) - \(formatter.string(from: academicBreak.endDate))"
        }
    }
    
    private var daysCount: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: academicBreak.startDate)
        let end = calendar.startOfDay(for: academicBreak.endDate)
        return (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Break type icon
            ZStack {
                Circle()
                    .fill(academicBreak.type.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(academicBreak.type.color.opacity(0.3), lineWidth: 1)
                    )
                
                Image(systemName: academicBreak.type.icon)
                    .font(.forma(.title3, weight: .bold))
                    .foregroundColor(academicBreak.type.color)
            }
            
            // Break details
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(academicBreak.name)
                        .font(.forma(.headline, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(academicBreak.type.displayName)
                        .font(.forma(.caption2, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(academicBreak.type.color.opacity(0.15))
                        )
                        .foregroundColor(academicBreak.type.color)
                }
                
                Text(durationText)
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    if daysCount > 1 {
                        Label("\(daysCount) days", systemImage: "clock")
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                    }
                    
                    if !academicBreak.description.isEmpty {
                        Label("Note", systemImage: "note.text")
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                    }
                }
                .labelStyle(.iconOnly)
                
                if !academicBreak.description.isEmpty {
                    Text(academicBreak.description)
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
            
            // Action buttons
            VStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(currentTheme.primaryColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(SpringButtonStyle())
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(SpringButtonStyle())
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(academicBreak.type.color.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(
            color: academicBreak.type.color.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
    }
}

// Removed the old AddEditAcademicBreakView since we're using CreateBreakView and EditBreakView

#Preview {
    AcademicCalendarEditorView(academicCalendar: .constant(AcademicCalendar.sampleCalendar))
        .environmentObject(ThemeManager())
        .environmentObject(AcademicCalendarManager())
}
import SwiftUI

struct BreaksManagerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var calendar: AcademicCalendar
    @State private var showingCreateBreak = false
    @State private var editingBreak: AcademicBreak?
    @State private var showingDeleteAlert = false
    @State private var breakToDelete: AcademicBreak?
    
    private var sortedBreaks: [AcademicBreak] {
        calendar.breaks.sorted { $0.startDate < $1.startDate }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                navigationHeader
                
                if sortedBreaks.isEmpty {
                    emptyStateView
                } else {
                    breaksListView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingCreateBreak) {
            CreateBreakView(calendar: $calendar)
                .environmentObject(themeManager)
        }
        .sheet(item: $editingBreak) { break_ in
            EditBreakView(calendar: $calendar, academicBreak: break_)
                .environmentObject(themeManager)
        }
        .alert("Delete Break", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                breakToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let breakToDelete = breakToDelete {
                    deleteBreak(breakToDelete)
                }
            }
        } message: {
            if let breakToDelete = breakToDelete {
                Text("Are you sure you want to delete '\(breakToDelete.name)'? This action cannot be undone.")
            }
        }
    }
    
    private var navigationHeader: some View {
        HStack {
            Button("Done") {
                // Save changes when done
                academicCalendarManager.updateCalendar(calendar)
                dismiss()
            }
            .font(.forma(.callout, weight: .semibold))
            .foregroundColor(themeManager.currentTheme.primaryColor)
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Breaks & Holidays")
                    .font(.forma(.headline, weight: .bold))
                    .foregroundColor(.primary)
                
                Text(calendar.name)
                    .font(.forma(.caption))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                showingCreateBreak = true
            } label: {
                Image(systemName: "plus")
                    .font(.forma(.callout, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .background(
            .regularMaterial,
            in: Rectangle()
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 0.5)
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.minus")
                        .font(.forma(.largeTitle, weight: .light))
                        .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.6))
                    
                    VStack(spacing: 8) {
                        Text("No Breaks Added")
                            .font(.forma(.title2, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Add breaks and holidays to help manage your academic schedule throughout the year.")
                            .font(.forma(.body))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                
                Button {
                    showingCreateBreak = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.forma(.title3, weight: .bold))
                        
                        Text("Add First Break")
                            .font(.forma(.headline, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor,
                                        themeManager.currentTheme.secondaryColor
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(
                                color: themeManager.currentTheme.primaryColor.opacity(0.4),
                                radius: 16, x: 0, y: 8
                            )
                    )
                }
                .buttonStyle(EventsBounceButtonStyle())
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    private var breaksListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(sortedBreaks, id: \.id) { academicBreak in
                    BreakCardView(
                        academicBreak: academicBreak,
                        onEdit: {
                            editingBreak = academicBreak
                        },
                        onDelete: {
                            breakToDelete = academicBreak
                            showingDeleteAlert = true
                        }
                    )
                    .environmentObject(themeManager)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }
    
    private func deleteBreak(_ breakToDelete: AcademicBreak) {
        calendar.breaks.removeAll { $0.id == breakToDelete.id }
        self.breakToDelete = nil
    }
}

struct BreakCardView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    
    let academicBreak: AcademicBreak
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    private var daysCount: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: academicBreak.startDate)
        let end = calendar.startOfDay(for: academicBreak.endDate)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0 + 1
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: academicBreak.type.icon)
                    .font(.forma(.title3, weight: .semibold))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(academicBreak.name)
                        .font(.forma(.subheadline, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(academicBreak.type.displayName)
                        .font(.forma(.caption2, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.currentTheme.primaryColor.opacity(0.15))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .clipShape(Capsule())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if Calendar.current.isDate(academicBreak.startDate, inSameDayAs: academicBreak.endDate) {
                        Text(dateFormatter.string(from: academicBreak.startDate))
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(dateFormatter.string(from: academicBreak.startDate)) - \(dateFormatter.string(from: academicBreak.endDate))")
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                        
                        if daysCount > 1 {
                            Text("\(daysCount) days")
                                .font(.forma(.caption2, weight: .medium))
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                        }
                    }
                }
                
                if !academicBreak.description.isEmpty {
                    Text(academicBreak.description)
                        .font(.forma(.caption2))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            // Actions
            VStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.forma(.caption, weight: .semibold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.forma(.caption, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.red.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.05),
                    radius: 8, x: 0, y: 4
                )
        )
        .adaptiveCardDarkModeHue(
            using: themeManager.currentTheme,
            intensity: colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0,
            cornerRadius: 16
        )
    }
}
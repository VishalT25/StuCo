import SwiftUI

struct DaySelectionGrid: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedDays: Set<DayOfWeek>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Repeat On")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(DayOfWeek.allCases, id: \.self) { day in
                    DayToggleButton(
                        day: day,
                        isSelected: selectedDays.contains(day),
                        color: themeManager.currentTheme.primaryColor
                    ) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                            if selectedDays.contains(day) {
                                selectedDays.remove(day)
                            } else {
                                selectedDays.insert(day)
                            }
                        }
                    }
                }
            }
            
            // Quick select buttons
            HStack(spacing: 12) {
                QuickSelectButton(title: "Weekdays", color: themeManager.currentTheme.secondaryColor) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDays = [.monday, .tuesday, .wednesday, .thursday, .friday]
                    }
                }
                
                QuickSelectButton(title: "Weekend", color: themeManager.currentTheme.secondaryColor) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDays = [.saturday, .sunday]
                    }
                }
                
                Spacer()
                
                Button("Clear") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDays.removeAll()
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
            }
        }
    }
}
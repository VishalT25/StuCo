import SwiftUI

struct CategoryRow: View {
    let category: Category
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(category.color)
                .frame(width: 28, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(.systemBackground), lineWidth: 2)
                )
            
            Text(category.name)
                .font(.forma(.subheadline, weight: .medium))
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct EnhancedEventRow: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    let event: Event
    var isPast: Bool = false

    // Check if event is overdue (past date and not completed)
    private var isOverdue: Bool {
        return event.date < Date() && !event.isCompleted
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: event.date))")
                    .font(.forma(.title3, weight: .bold))
                    .foregroundColor(isOverdue ? .red : (isPast || event.isCompleted ? .secondary : themeManager.currentTheme.primaryColor))
                Text(monthShort(from: event.date))
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(isOverdue ? .red.opacity(0.8) : .secondary)
            }
            .frame(width: 45)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.title)
                        .font(.forma(.headline, weight: .semibold))
                        .foregroundColor(isOverdue ? .red : (isPast || event.isCompleted ? .secondary : .primary))
                        .strikethrough(event.isCompleted)
                    Spacer()
                }

                HStack(spacing: 8) {
                    Label(timeString(from: event.date), systemImage: "clock")
                        .font(.forma(.caption, weight: .medium))
                        .foregroundColor(isOverdue ? .red.opacity(0.8) : .secondary)
                    
                    Spacer()
                    
                    Text(event.category(from: viewModel.categories).name)
                        .font(.forma(.caption, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(event.category(from: viewModel.categories).color.opacity(0.2))
                        .foregroundColor(event.category(from: viewModel.categories).color)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(isPast || event.isCompleted ? 0.7 : 1.0)
    }
    
    private var backgroundColor: Color {
        if isOverdue {
            return Color.red.opacity(0.15)
        } else if isPast || event.isCompleted {
            return Color(.systemGray6)
        } else {
            return themeManager.currentTheme.primaryColor.opacity(0.1)
        }
    }
    
    private func monthShort(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Button Styles
struct EventsBounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Category Selection Card
struct CategorySelectionCard: View {
    let category: Category
    let isSelected: Bool
    let onTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(category.color)
                    .frame(width: 32, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: category.color.opacity(0.3), radius: 4, x: 0, y: 2)
                
                Text(category.name)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? AnyShapeStyle(category.color.opacity(colorScheme == .dark ? 0.2 : 0.1)) : AnyShapeStyle(Color(.systemBackground).opacity(0.9)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? category.color.opacity(0.5) : Color.secondary.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isSelected ? category.color.opacity(0.2) : .clear,
                        radius: isSelected ? 8 : 0,
                        x: 0,
                        y: isSelected ? 4 : 0
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}
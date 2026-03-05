import SwiftUI

struct CustomColorPicker: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var recentColorsManager = RecentColorsManager.shared
    @Binding var selectedColor: Color
    @State private var customColor: Color

    init(selectedColor: Binding<Color>) {
        self._selectedColor = selectedColor
        self._customColor = State(initialValue: selectedColor.wrappedValue)
    }

    private var currentTheme: AppTheme {
        themeManager.currentTheme
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Color picker
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Select Color")
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)

                        ColorPicker("Choose a color", selection: $customColor, supportsOpacity: false)
                            .font(.forma(.body, weight: .medium))
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    // Recent colors
                    if !recentColorsManager.recentColors.isEmpty {
                        recentColorsSection
                            .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Custom Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        selectedColor = customColor
                        recentColorsManager.addColor(customColor)
                        dismiss()
                    }
                    .font(.forma(.body, weight: .semibold))
                    .foregroundColor(currentTheme.primaryColor)
                }
            }
        }
    }

    private var recentColorsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "clock")
                    .font(.forma(.subheadline))
                    .foregroundColor(currentTheme.primaryColor)

                Text("Recently Used")
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                ForEach(recentColorsManager.recentColors, id: \.self) { color in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            customColor = color
                        }
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle()
                                    .stroke(.white, lineWidth: customColor == color ? 3 : 0)
                            )
                            .overlay(
                                Circle()
                                    .stroke(color.opacity(0.3), lineWidth: 2)
                            )
                            .scaleEffect(customColor == color ? 1.15 : 1.0)
                            .shadow(
                                color: customColor == color ? color.opacity(0.4) : color.opacity(0.2),
                                radius: customColor == color ? 8 : 4,
                                x: 0,
                                y: customColor == color ? 4 : 2
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

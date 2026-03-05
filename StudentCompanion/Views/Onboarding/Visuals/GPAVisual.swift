import SwiftUI

struct GPAVisual: View {
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
                .frame(height: 20)

            // GPA Display
            VStack(spacing: 10) {
                Text("Current GPA")
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))

                Text("3.85")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(theme.primaryColor)

                Text("Semester Average: 3.92")
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.primaryColor.opacity(0.15),
                                theme.primaryColor.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )

            // Course grades
            VStack(alignment: .leading, spacing: 6) {
                Text("Your Courses")
                    .font(.forma(.caption, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))

                courseGradeRow(name: "CS 101", grade: "A", percentage: 95, color: .green)
                courseGradeRow(name: "Math 201", grade: "A-", percentage: 92, color: .blue)
                courseGradeRow(name: "Physics 150", grade: "B+", percentage: 87, color: .orange)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .frame(height: 300)
        .padding(.horizontal, 40)
    }

    private func courseGradeRow(name: String, grade: String, percentage: Int, color: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.forma(.caption, weight: .semibold))
                    .foregroundColor(.white)
                Text("\(percentage)%")
                    .font(.forma(.caption2, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Text(grade)
                .font(.forma(.body, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(color.opacity(0.2))
                )
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.05))
        )
    }
}

#Preview {
    GPAVisual(theme: AppTheme.forest)
        .preferredColorScheme(.dark)
        .background(Color.black)
}

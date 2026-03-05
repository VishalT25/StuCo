import SwiftUI

struct ReminderPickerRow: View {
    @Binding var reminderTime: ReminderTime
    @State private var showingPicker = false
    
    var body: some View {
        Button(action: { showingPicker = true }) {
            HStack {
                Text("Reminder")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(reminderTime.displayName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingPicker) {
            CustomReminderPickerView(selectedReminder: $reminderTime)
        }
    }
}
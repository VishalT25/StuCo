import SwiftUI

struct CustomReminderPickerView: View {
    @Binding var selectedReminder: ReminderTime
    @Environment(\.dismiss) private var dismiss
    
    @State private var customValue: String = "15"
    @State private var selectedUnit: TimeUnit = .minutes
    @State private var useCustom: Bool = false
    
    enum TimeUnit: String, CaseIterable {
        case minutes = "Minutes"
        case hours = "Hours"
        case days = "Days"
        case weeks = "Weeks"
        
        var shortName: String {
            switch self {
            case .minutes: return "min"
            case .hours: return "hr"
            case .days: return "day"
            case .weeks: return "wk"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Common presets section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Select")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(commonPresets, id: \.id) { preset in
                            Button(action: {
                                selectedReminder = preset
                                useCustom = false
                            }) {
                                VStack(spacing: 4) {
                                    Text(preset.shortDisplayName)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text(preset.displayName)
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                                .foregroundColor(selectedReminder == preset && !useCustom ? .white : .primary)
                                .frame(maxWidth: .infinity, minHeight: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedReminder == preset && !useCustom ? Color.blue : Color(.systemGray6))
                                )
                            }
                        }
                    }
                }
                
                Divider()
                
                // Custom time section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Custom Time")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Toggle("", isOn: $useCustom)
                            .labelsHidden()
                    }
                    
                    if useCustom {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                TextField("Value", text: $customValue)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .keyboardType(.numberPad)
                                    .frame(width: 80)
                                
                                Picker("Unit", selection: $selectedUnit) {
                                    ForEach(TimeUnit.allCases, id: \.self) { unit in
                                        Text(unit.rawValue).tag(unit)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity)
                            }
                            
                            // Preview of custom time
                            if let value = Int(customValue), value > 0 {
                                if let customReminder = createCustomReminder(value: value, unit: selectedUnit) {
                                    Text("Preview: \(customReminder.displayName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal)
                                } else {
                                    Text("Invalid time value")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
                
                // Apply button
                Button(action: applySelection) {
                    Text("Set Reminder")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .disabled(useCustom && (customValue.isEmpty || Int(customValue) == nil || Int(customValue)! <= 0))
            }
            .padding()
            .navigationTitle("Reminder Time")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            updateFromCurrentSelection()
        }
    }
    
    // MARK: - Helper Properties and Methods
    
    private var commonPresets: [ReminderTime] {
        return [
            .none,
            .fiveMinutes,
            .fifteenMinutes,
            .thirtyMinutes,
            .oneHour,
            .oneDay
        ]
    }
    
    private func createCustomReminder(value: Int, unit: TimeUnit) -> ReminderTime? {
        let totalMinutes: Int
        
        switch unit {
        case .minutes:
            totalMinutes = value
        case .hours:
            totalMinutes = value * 60
        case .days:
            totalMinutes = value * 1440
        case .weeks:
            totalMinutes = value * 10080
        }
        
        // Use the fromMinutes factory method
        return ReminderTime.fromMinutes(totalMinutes)
    }
    
    private func applySelection() {
        if useCustom {
            if let value = Int(customValue), value > 0 {
                if let customReminder = createCustomReminder(value: value, unit: selectedUnit) {
                    selectedReminder = customReminder
                }
            }
        }
        // If not using custom, selectedReminder is already set by preset buttons
        dismiss()
    }
    
    private func updateFromCurrentSelection() {
        // Check if current selection matches any preset
        let matchesPreset = commonPresets.contains(selectedReminder)
        
        if !matchesPreset && selectedReminder != .none {
            useCustom = true
            
            // Extract value from total minutes
            let totalMinutes = selectedReminder.totalMinutes
            
            // Determine the best unit to display
            if totalMinutes % 10080 == 0 && totalMinutes >= 10080 {
                // Display in weeks
                customValue = String(totalMinutes / 10080)
                selectedUnit = .weeks
            } else if totalMinutes % 1440 == 0 && totalMinutes >= 1440 {
                // Display in days
                customValue = String(totalMinutes / 1440)
                selectedUnit = .days
            } else if totalMinutes % 60 == 0 && totalMinutes >= 60 {
                // Display in hours
                customValue = String(totalMinutes / 60)
                selectedUnit = .hours
            } else {
                // Display in minutes
                customValue = String(totalMinutes)
                selectedUnit = .minutes
            }
        }
    }
}

// MARK: - Preview
struct CustomReminderPickerView_Previews: PreviewProvider {
    static var previews: some View {
        CustomReminderPickerView(selectedReminder: .constant(.fifteenMinutes))
    }
}

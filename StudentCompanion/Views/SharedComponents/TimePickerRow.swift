import SwiftUI

struct TimePickerRow: View {
    let title: String
    @Binding var time: Date
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }
}
import SwiftUI

struct AcademicCalendarImportView: View {
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @Environment(\.dismiss) private var dismiss
    @State private var jsonText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    var onImported: ((AcademicCalendar) -> Void)? = nil

    @StateObject private var supabaseService = SupabaseService.shared

    init(onImported: ((AcademicCalendar) -> Void)? = nil) {
        self.onImported = onImported
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Paste your academic calendar JSON below.")
                    .font(.headline)
                
                TextEditor(text: $jsonText)
                    .frame(height: 300)
                    .border(Color.gray, width: 1)
                
                Button(action: importCalendar) {
                    if isProcessing {
                        ProgressView()
                    } else {
                        Text("Import Calendar")
                    }
                }
                .disabled(jsonText.isEmpty || isProcessing)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Import Academic Calendar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Import Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func importCalendar() {
        guard supabaseService.isAuthenticated else {
            errorMessage = "Please sign in to import an academic calendar."
            showError = true
            return
        }
        isProcessing = true
        Task {
            do {
                var calendar = try AcademicCalendarImporter.import(from: jsonText)
                
                if calendar.startDate == Date(timeIntervalSince1970: 0) {
                    calendar.startDate = Date()
                }
                if calendar.endDate == Date(timeIntervalSince1970: 0) {
                    calendar.endDate = Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()
                }

                await MainActor.run {
                    academicCalendarManager.addCalendar(calendar)
                    onImported?(calendar)
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isProcessing = false
                }
            }
        }
    }
}

class AcademicCalendarImporter {
    enum ImportError: Error, LocalizedError {
        case invalidJSON
        case unsupportedVersion
        case invalidTimeFormat
        
        var errorDescription: String? {
            switch self {
            case .invalidJSON: "The provided text is not valid JSON."
            case .unsupportedVersion: "The JSON version is not supported."
            case .invalidTimeFormat: "The date format in the JSON is invalid."
            }
        }
    }
    
    static func `import`(from jsonString: String) throws -> AcademicCalendar {
        guard let data = jsonString.data(using: .utf8) else {
            throw ImportError.invalidJSON
        }
        
        let importData = try JSONDecoder().decode(AcademicCalendarImportData.self, from: data)
        
        guard importData.version == 1 else {
            throw ImportError.unsupportedVersion
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let breaks = try importData.breaks.map {
            guard let startDate = dateFormatter.date(from: $0.start),
                  let endDate = dateFormatter.date(from: $0.end) else {
                throw ImportError.invalidTimeFormat
            }
            
            let breakType = BreakType(rawValue: $0.type) ?? .custom
            return AcademicBreak(name: $0.name, type: breakType, startDate: startDate, endDate: endDate)
        }
        
        var calendar = AcademicCalendar(
            name: importData.name,
            academicYear: importData.academicYear,
            termType: .semester, // Default value
            startDate: Date(timeIntervalSince1970: 0), // Placeholder, will be set in view
            endDate: Date(timeIntervalSince1970: 0)   // Placeholder, will be set in view
        )
        
        calendar.breaks = breaks
        return calendar
    }
}

struct AcademicCalendarImportData: Codable {
    let version: Int
    let name: String
    let academicYear: String
    let breaks: [BreakImportData]
    
    struct BreakImportData: Codable {
        let name: String
        let type: String
        let start: String
        let end: String
    }
}
import SwiftUI
import Combine

class CourseSelectionManager: ObservableObject {
    @Published var showPopup = false
    @Published var originalInput = ""
    @Published var suggestedAlias = ""
    @Published var availableCourses: [Course] = []
    
    private var onSelectionCallback: ((Course) -> Void)?
    private var onDismissCallback: (() -> Void)?
    
    func requestCourseSelection(
        originalInput: String,
        suggestedAlias: String,
        availableCourses: [Course],
        onSelection: @escaping (Course) -> Void,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.originalInput = originalInput
        self.suggestedAlias = suggestedAlias
        self.availableCourses = availableCourses
        self.onSelectionCallback = onSelection
        self.onDismissCallback = onDismiss
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showPopup = true
        }
    }
    
    func selectCourse(_ course: Course) {
        onSelectionCallback?(course)
        dismissPopup()
    }
    
    func dismissPopup() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showPopup = false
        }
        
        // Reset state after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.originalInput = ""
            self.suggestedAlias = ""
            self.availableCourses = []
            self.onSelectionCallback = nil
            self.onDismissCallback?()
            self.onDismissCallback = nil
        }
    }
}
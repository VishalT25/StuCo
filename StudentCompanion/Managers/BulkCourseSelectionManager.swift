import SwiftUI

// MARK: - Bulk Course Selection Manager
class BulkCourseSelectionManager: ObservableObject {
    @Published var isSelecting = false
    @Published var selectionContext: CourseSelectionContext = .none
    @Published var selectedCourseIDs: Set<UUID> = []
    @Published var selectedAssignmentIDs: Set<UUID> = []

    enum CourseSelectionContext: Equatable {
        case none
        case courses
        case assignments(courseID: UUID)
    }

    func startSelection(_ context: CourseSelectionContext, initialID: UUID? = nil) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            selectionContext = context
            isSelecting = true

            clearAllSelections()

            if let id = initialID {
                switch context {
                case .courses:
                    selectedCourseIDs.insert(id)
                case .assignments:
                    selectedAssignmentIDs.insert(id)
                case .none:
                    break
                }
            }
        }
    }

    func endSelection() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            selectionContext = .none
            isSelecting = false
            clearAllSelections()
        }
    }

    func toggleSelection(_ id: UUID) {
        switch selectionContext {
        case .courses:
            if selectedCourseIDs.contains(id) {
                selectedCourseIDs.remove(id)
            } else {
                selectedCourseIDs.insert(id)
            }
        case .assignments:
            if selectedAssignmentIDs.contains(id) {
                selectedAssignmentIDs.remove(id)
            } else {
                selectedAssignmentIDs.insert(id)
            }
        case .none:
            break
        }
    }

    func selectAll<T: Identifiable>(items: [T]) where T.ID == UUID {
        let allIDs = Set(items.map { $0.id })
        switch selectionContext {
        case .courses:
            selectedCourseIDs = allIDs
        case .assignments:
            selectedAssignmentIDs = allIDs
        case .none:
            break
        }
    }

    func deselectAll() {
        switch selectionContext {
        case .courses:
            selectedCourseIDs.removeAll()
        case .assignments:
            selectedAssignmentIDs.removeAll()
        case .none:
            break
        }
    }

    private func clearAllSelections() {
        selectedCourseIDs.removeAll()
        selectedAssignmentIDs.removeAll()
    }

    func selectedCount() -> Int {
        switch selectionContext {
        case .courses:
            return selectedCourseIDs.count
        case .assignments:
            return selectedAssignmentIDs.count
        case .none:
            return 0
        }
    }

    func isSelected(_ id: UUID) -> Bool {
        switch selectionContext {
        case .courses:
            return selectedCourseIDs.contains(id)
        case .assignments:
            return selectedAssignmentIDs.contains(id)
        case .none:
            return false
        }
    }
}

import SwiftUI
import Combine

// MARK: - Bulk Selection Manager
class BulkSelectionManager: ObservableObject {
    @Published var isSelecting = false
    @Published var selectionContext: SelectionContext = .none
    @Published var selectedEventIDs: Set<UUID> = []
    @Published var selectedCategoryIDs: Set<UUID> = []
    @Published var selectedScheduleItemIDs: Set<UUID> = []
    
    enum SelectionContext {
        case none
        case events
        case categories
        case scheduleItems
    }
    
    func startSelection(_ context: SelectionContext, initialID: UUID? = nil) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            selectionContext = context
            isSelecting = true
            
            clearAllSelections()
            
            if let id = initialID {
                switch context {
                case .events:
                    selectedEventIDs.insert(id)
                case .categories:
                    selectedCategoryIDs.insert(id)
                case .scheduleItems:
                    selectedScheduleItemIDs.insert(id)
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
        case .events:
            if selectedEventIDs.contains(id) {
                selectedEventIDs.remove(id)
            } else {
                selectedEventIDs.insert(id)
            }
        case .categories:
            if selectedCategoryIDs.contains(id) {
                selectedCategoryIDs.remove(id)
            } else {
                selectedCategoryIDs.insert(id)
            }
        case .scheduleItems:
            if selectedScheduleItemIDs.contains(id) {
                selectedScheduleItemIDs.remove(id)
            } else {
                selectedScheduleItemIDs.insert(id)
            }
        case .none:
            break
        }
    }
    
    func selectAll<T: Identifiable>(items: [T]) where T.ID == UUID {
        let allIDs = Set(items.map { $0.id })
        switch selectionContext {
        case .events:
            selectedEventIDs = allIDs
        case .categories:
            selectedCategoryIDs = allIDs
        case .scheduleItems:
            selectedScheduleItemIDs = allIDs
        case .none:
            break
        }
    }
    
    func deselectAll() {
        switch selectionContext {
        case .events:
            selectedEventIDs.removeAll()
        case .categories:
            selectedCategoryIDs.removeAll()
        case .scheduleItems:
            selectedScheduleItemIDs.removeAll()
        case .none:
            break
        }
    }
    
    private func clearAllSelections() {
        selectedEventIDs.removeAll()
        selectedCategoryIDs.removeAll()
        selectedScheduleItemIDs.removeAll()
    }
    
    func selectedCount() -> Int {
        switch selectionContext {
        case .events:
            return selectedEventIDs.count
        case .categories:
            return selectedCategoryIDs.count
        case .scheduleItems:
            return selectedScheduleItemIDs.count
        case .none:
            return 0
        }
    }
    
    func isSelected(_ id: UUID) -> Bool {
        switch selectionContext {
        case .events:
            return selectedEventIDs.contains(id)
        case .categories:
            return selectedCategoryIDs.contains(id)
        case .scheduleItems:
            return selectedScheduleItemIDs.contains(id)
        case .none:
            return false
        }
    }
}
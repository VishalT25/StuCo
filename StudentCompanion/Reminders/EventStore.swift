//
//  EventStore.swift
//  StudentCompanion
//
//  Created by Vishal Thamaraimanalan on 2025-06-27.
//

///  EventStore.swift  (create a new file)
import Foundation

struct EventStore {
    @MainActor static func setGoogleId(_ id: String, forLocalId localId: UUID,
                            in viewModel: EventViewModel) {
        if let event = viewModel.events.first(where: { $0.id == localId }) {
            var updatedEvent = event
            updatedEvent.googleCalendarIdentifier = id
            updatedEvent.externalIdentifier = id   // keep them identical
            
            // Use the proper update method instead of direct assignment
            viewModel.updateEvent(updatedEvent)
        }
    }
}
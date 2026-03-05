import Foundation
import SwiftUI
import Combine

/// Coordinates offline-first functionality across the app
/// Manages sync queue, network monitoring, and offline state
@MainActor
class OfflineManager: ObservableObject {
    static let shared = OfflineManager()

    // MARK: - Published State
    @Published private(set) var isOffline = false
    @Published private(set) var pendingOperationsCount = 0
    @Published private(set) var lastSuccessfulSync: Date?
    @Published private(set) var isSyncing = false
    @Published private(set) var syncStatus: SyncStatus = .ready

    // MARK: - Dependencies
    private let networkMonitor = NetworkMonitor.shared
    private let syncQueue = SyncQueue()
    private let realtimeSyncManager = RealtimeSyncManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Sync Status
    enum SyncStatus {
        case ready
        case syncing
        case error(String)

        var displayName: String {
            switch self {
            case .ready: return "Ready"
            case .syncing: return "Syncing..."
            case .error(let message): return "Error: \(message)"
            }
        }
    }

    private init() {
        setupNetworkObservers()
        setupSyncQueueObservers()
        print("📴 OfflineManager: Initialized")
    }

    // MARK: - Network Observers

    private func setupNetworkObservers() {
        // Observe network connectivity changes
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (isConnected: Bool) in
                guard let self = self else { return }

                let wasOffline = self.isOffline
                self.isOffline = !isConnected

                if wasOffline && !self.isOffline {
                    // Just came back online
                    print("📴 OfflineManager: ✅ Back online - triggering sync")
                    Task {
                        await self.syncWhenOnline()
                    }
                } else if !wasOffline && self.isOffline {
                    // Just went offline
                    print("📴 OfflineManager: ⚠️ Went offline - queuing operations")
                }
            }
            .store(in: &cancellables)
    }

    private func setupSyncQueueObservers() {
        // Observe sync queue changes
        syncQueue.$queuedOperations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (operations: [SyncOperation]) in
                self?.pendingOperationsCount = operations.count
            }
            .store(in: &cancellables)

        syncQueue.$isProcessing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (isProcessing: Bool) in
                self?.isSyncing = isProcessing
            }
            .store(in: &cancellables)
    }

    // MARK: - Sync Operations

    /// Trigger sync when coming back online
    func syncWhenOnline() async {
        guard !isOffline else {
            print("📴 OfflineManager: Cannot sync while offline")
            return
        }

        print("📴 OfflineManager: Coming back online - syncing data...")
        syncStatus = .syncing
        isSyncing = true

        // Process the sync queue if there are pending operations
        if pendingOperationsCount > 0 {
            print("📴 OfflineManager: Processing \(pendingOperationsCount) pending operations...")
            await syncQueue.processQueue()
        }

        // Always refresh data from server to ensure consistency
        print("📴 OfflineManager: Refreshing all data from server...")
        await realtimeSyncManager.refreshAllData()

        isSyncing = false
        syncStatus = .ready
        lastSuccessfulSync = Date()

        print("📴 OfflineManager: Sync completed - posting refresh notification")

        // Post notification that all managers should refresh their data
        await MainActor.run {
            NotificationCenter.default.post(name: .offlineSyncCompleted, object: nil)
            NotificationCenter.default.post(name: .init("RefreshAllData"), object: nil)
        }

        // Small delay to ensure all data is loaded
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Post final refresh notification
        await MainActor.run {
            NotificationCenter.default.post(name: .init("DataRefreshCompleted"), object: nil)
        }
    }

    /// Force sync now (if online)
    func forceSyncNow() async {
        guard !isOffline else {
            print("📴 OfflineManager: Cannot force sync while offline")
            return
        }

        await syncWhenOnline()
    }

    /// Clear all pending operations (use with caution)
    func clearPendingOperations() {
        syncQueue.clearQueue()
        print("📴 OfflineManager: Cleared all pending operations")
    }

    // MARK: - Status Info

    func getOfflineStatus() -> OfflineStatus {
        return OfflineStatus(
            isOffline: isOffline,
            pendingOperationsCount: pendingOperationsCount,
            lastSuccessfulSync: lastSuccessfulSync,
            isSyncing: isSyncing,
            isConnected: networkMonitor.isConnected
        )
    }

    /// Get detailed queue information
    func getQueueInfo() -> QueueInfo {
        return syncQueue.queueInfo
    }

    /// Get sync statistics
    func getSyncStatistics() -> QueueStatistics {
        return syncQueue.queueStatistics
    }
}

// MARK: - Supporting Types

struct OfflineStatus {
    let isOffline: Bool
    let pendingOperationsCount: Int
    let lastSuccessfulSync: Date?
    let isSyncing: Bool
    let isConnected: Bool

    var statusMessage: String {
        if isOffline {
            if pendingOperationsCount > 0 {
                return "Offline - \(pendingOperationsCount) changes pending"
            } else {
                return "Offline - Working locally"
            }
        } else {
            if isSyncing {
                return "Syncing \(pendingOperationsCount) changes..."
            } else if pendingOperationsCount > 0 {
                return "Online - \(pendingOperationsCount) changes queued"
            } else {
                return "Online - All synced"
            }
        }
    }

    var statusColor: String {
        if isOffline {
            return "orange"
        } else if isSyncing {
            return "blue"
        } else if pendingOperationsCount > 0 {
            return "yellow"
        } else {
            return "green"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let offlineSyncCompleted = Notification.Name("OfflineSyncCompleted")
}

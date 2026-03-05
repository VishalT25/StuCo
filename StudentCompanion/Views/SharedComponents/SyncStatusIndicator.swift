import SwiftUI

struct RealtimeSyncStatusIndicator: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var realtimeSyncManager: RealtimeSyncManager
    
    @State private var showDetails = false
    
    var body: some View {
        Button(action: { showDetails.toggle() }) {
            HStack(spacing: 4) {
                statusIcon
                
                if realtimeSyncManager.pendingSyncCount > 0 {
                    Text("\(realtimeSyncManager.pendingSyncCount)")
                        .font(.forma(.caption2, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(.red)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetails) {
            SyncStatusDetailView()
                .environmentObject(themeManager)
                .environmentObject(realtimeSyncManager)
                .presentationDetents([.medium])
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch realtimeSyncManager.syncStatus {
        case .idle:
            Image(systemName: "cloud")
                .foregroundColor(.secondary)
                
        case .initializing:
            Image(systemName: "cloud")
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .symbolEffect(.pulse)
                
        case .syncing:
            Image(systemName: "cloud.bolt")
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .symbolEffect(.pulse)
                
        case .ready:
            if realtimeSyncManager.isConnected {
                Image(systemName: "cloud.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "cloud.slash")
                    .foregroundColor(.orange)
            }
            
        case .disconnected:
            Image(systemName: "cloud.slash")
                .foregroundColor(.red)
                
        case .error:
            Image(systemName: "cloud.bolt.rain")
                .foregroundColor(.red)
                
        default:
            Image(systemName: "cloud")
                .foregroundColor(.secondary)
        }
    }
}

struct SyncStatusDetailView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var realtimeSyncManager: RealtimeSyncManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Status Overview
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: statusIcon)
                            .font(.forma(.title2))
                            .foregroundColor(statusColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sync Status")
                                .font(.forma(.headline, weight: .semibold))
                            
                            Text(realtimeSyncManager.syncStatus.displayName)
                                .font(.forma(.subheadline))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    if let lastSync = realtimeSyncManager.lastSyncTime {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                            
                            Text("Last sync: \(lastSync.formatted(.relative(presentation: .numeric)))")
                                .font(.forma(.caption))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeManager.currentTheme.tertiaryColor.opacity(0.3))
                )
                
                // Connection Status
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Real-time Connection")
                            .font(.forma(.subheadline, weight: .medium))
                        
                        Spacer()
                        
                        connectionIndicator
                    }
                    
                    if realtimeSyncManager.pendingSyncCount > 0 {
                        HStack {
                            Text("Pending Operations")
                                .font(.forma(.subheadline, weight: .medium))
                            
                            Spacer()
                            
                            Text("\(realtimeSyncManager.pendingSyncCount)")
                                .font(.forma(.subheadline, weight: .bold))
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGroupedBackground))
                )
                
                // Actions
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await realtimeSyncManager.refreshAllData()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Data")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                        )
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                    .disabled(isSyncing)
                    
                    if !realtimeSyncManager.isConnected {
                        Button(action: {
                            Task {
                                await realtimeSyncManager.initialize()
                            }
                        }) {
                            HStack {
                                Image(systemName: "wifi")
                                Text("Reconnect")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.orange.opacity(0.1))
                            )
                            .foregroundColor(.orange)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Debug Snapshot")
                        .font(.forma(.subheadline, weight: .semibold))
                    debugRow("academic_calendars")
                    debugRow("assignments")
                    debugRow("courses")
                    debugRow("events")
                    debugRow("categories")
                    debugRow("schedules")
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGroupedBackground))
                )
                
                Spacer()
            }
            .padding(20)
            .navigationTitle("Sync Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                }
            }
        }
    }
    
    private var isSyncing: Bool {
        switch realtimeSyncManager.syncStatus {
        case .syncing:
            return true
        default:
            return false
        }
    }
    
    private var statusIcon: String {
        switch realtimeSyncManager.syncStatus {
        case .idle: return "cloud"
        case .initializing: return "cloud"
        case .syncing: return "cloud.bolt"
        case .ready: return realtimeSyncManager.isConnected ? "cloud.fill" : "cloud.slash"
        case .disconnected: return "cloud.slash"
        case .error: return "cloud.bolt.rain"
        default: return "cloud"
        }
    }
    
    private var statusColor: Color {
        switch realtimeSyncManager.syncStatus {
        case .ready where realtimeSyncManager.isConnected: return .green
        case .ready: return .orange
        case .syncing, .initializing: return themeManager.currentTheme.primaryColor
        case .error, .disconnected: return .red
        case .idle: return .secondary
        default: return .secondary
        }
    }
    
    @ViewBuilder
    private var connectionIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(realtimeSyncManager.isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            
            Text(realtimeSyncManager.isConnected ? "Connected" : "Disconnected")
                .font(.forma(.caption, weight: .medium))
                .foregroundColor(realtimeSyncManager.isConnected ? .green : .red)
        }
    }
    
    @ViewBuilder
    private func debugRow(_ table: String) -> some View {
        let stats = realtimeSyncManager.syncStatistics
        let changes = stats.changesReceived[table, default: 0]
        let ok = stats.syncSuccesses[table, default: 0]
        let errs = stats.syncErrors[table, default: 0]
        HStack {
            Text(table)
                .font(.forma(.caption, weight: .medium))
            Spacer()
            Text("changes: \(changes)")
                .font(.forma(.caption))
                .foregroundColor(.secondary)
            Text("ok: \(ok)")
                .font(.forma(.caption))
                .foregroundColor(.green)
            Text("err: \(errs)")
                .font(.forma(.caption))
                .foregroundColor(.red)
        }
    }
}

#Preview {
    let themeManager = ThemeManager()
    return RealtimeSyncStatusIndicator()
        .environmentObject(themeManager)
        .environmentObject(RealtimeSyncManager.shared)
}
import SwiftUI

/// Banner that shows offline status at bottom of screen
/// Automatically appears when offline
struct OfflineStatusBanner: View {
    @StateObject private var offlineManager = OfflineManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if shouldShowBanner {
                bannerContent
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: shouldShowBanner)
            }
        }
    }

    private var shouldShowBanner: Bool {
        offlineManager.isOffline || offlineManager.isSyncing
    }

    private var bannerContent: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            // Status message
            Text(statusMessage)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)

            Spacer()

            // Progress indicator when syncing
            if offlineManager.isSyncing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.9)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(bannerBackground)
        .shadow(color: Color.black.opacity(0.15), radius: 10, y: -2)
    }

    // MARK: - Status Helpers

    private var statusIcon: some View {
        Group {
            if offlineManager.isOffline {
                Image(systemName: "wifi.slash")
            } else if offlineManager.isSyncing {
                Image(systemName: "arrow.triangle.2.circlepath")
            } else {
                Image(systemName: "checkmark.circle")
            }
        }
    }

    private var statusMessage: String {
        if offlineManager.isOffline {
            return "App is offline, some features may not be available"
        } else if offlineManager.isSyncing {
            return "Reconnecting and syncing changes..."
        } else {
            return "Back online"
        }
    }

    private var statusColor: Color {
        if offlineManager.isOffline {
            return Color.orange
        } else {
            return Color.blue
        }
    }

    private var bannerBackground: some View {
        statusColor
    }
}

// MARK: - Preview

#Preview {
    VStack {
        OfflineStatusBanner()
        Spacer()
    }
}

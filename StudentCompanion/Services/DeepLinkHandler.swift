import Foundation
import SwiftUI

@MainActor
final class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()

    @Published var pendingScheduleImport: String?
    @Published var showImportSheet = false

    private init() {}

    func handleURL(_ url: URL) {
        print("📎 Deep link received: \(url.absoluteString)")

        guard url.scheme == "stuco" else {
            print("⚠️ Invalid scheme: \(url.scheme ?? "nil")")
            return
        }

        if url.host == "schedule",
           let shareId = url.pathComponents.dropFirst().first {
            print("✅ Schedule share ID: \(shareId)")
            pendingScheduleImport = shareId
            showImportSheet = true
        }
    }

    func clearPendingImport() {
        pendingScheduleImport = nil
        showImportSheet = false
    }
}

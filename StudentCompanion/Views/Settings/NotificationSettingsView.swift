import SwiftUI

struct NotificationSettingsView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @State private var pendingNotificationsCount = 0
    
    var body: some View {
        NavigationView {
            List {
                Section("Notification Status") {
                    HStack {
                        Text("Status")
                            .font(.forma(.body))
                        Spacer()
                        Text(notificationManager.authorizationStatusText)
                            .font(.forma(.body, weight: .medium))
                            .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                    }
                    
                    if !notificationManager.isAuthorized {
                        Button("Enable Notifications") {
                            notificationManager.openNotificationSettings()
                        }
                        .font(.forma(.body))
                        .foregroundColor(.blue)
                    }
                }
                
                Section("Notification Settings") {
                    HStack {
                        Text("Notifications Enabled")
                            .font(.forma(.body))
                        Spacer()
                        Text(notificationManager.isAuthorized ? "Yes" : "No")
                            .font(.forma(.body, weight: .medium))
                            .foregroundColor(notificationManager.isAuthorized ? .green : .red)
                    }
                    
                    if notificationManager.isAuthorized {
                        HStack {
                            Text("Pending Notifications")
                                .font(.forma(.body))
                            Spacer()
                            Text("\(pendingNotificationsCount)")
                                .font(.forma(.body, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Refresh Pending Count") {
                            Task {
                                pendingNotificationsCount = await notificationManager.getPendingNotificationsCount()
                            }
                        }
                        .font(.forma(.body))
                        
                        Button("Clear All Notifications") {
                            notificationManager.cancelAllNotifications()
                            pendingNotificationsCount = 0
                        }
                        .font(.forma(.body))
                        .foregroundColor(.red)
                    }
                }
                
                Section("Debug") {
                    Button("Check Authorization Status") {
                        notificationManager.checkAuthorizationStatus()
                    }
                    .font(.forma(.body))
                    
                    Button("Request Authorization") {
                        Task {
                            await notificationManager.requestAuthorization()
                        }
                    }
                    .font(.forma(.body))
                }
            }
            .navigationTitle("Notifications")
            .onAppear {
                notificationManager.checkAuthorizationStatus()
                Task {
                    pendingNotificationsCount = await notificationManager.getPendingNotificationsCount()
                }
            }
        }
    }
}
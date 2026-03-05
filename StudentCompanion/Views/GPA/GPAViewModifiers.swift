import SwiftUI

// MARK: - GPAView Modifier Extensions
extension View {
    @ViewBuilder
    func applyBaseModifiers(
        showingAddCourseSheet: Binding<Bool>,
        showConflictResolution: Binding<Bool>,
        showingSemesterDetail: Binding<Bool>,
        showingYearDetail: Binding<Bool>,
        showingScheduleManager: Binding<Bool>,
        courseManager: UnifiedCourseManager,
        themeManager: ThemeManager,
        scheduleManager: ScheduleManager,
        orphanedData: (courses: [Course], scheduleItems: [ScheduleItem]),
        semesterAverage: Double?,
        semesterGPA: Double?,
        activeScheduleCourses: [Course],
        usePercentageGrades: Bool,
        selectedYearScheduleIDs: Binding<Set<UUID>>,
        onResolution: @escaping (OrphanResolutionAction) -> Void
    ) -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sheet(isPresented: showingAddCourseSheet) {
                EnhancedAddCourseWithMeetingsView()
                    .environmentObject(themeManager)
                    .environmentObject(scheduleManager)
                    .environmentObject(courseManager)
            }
            .sheet(isPresented: showConflictResolution) {
                DataConflictResolutionView(
                    orphanedData: OrphanedDataResult(
                        orphanedCourses: orphanedData.courses,
                        orphanedScheduleItems: orphanedData.scheduleItems.map { scheduleItem in
                            ScheduleItemWithScheduleID(
                                scheduleItem: scheduleItem,
                                scheduleId: UUID(),
                                scheduleName: "Unknown Schedule"
                            )
                        }
                    ),
                    onResolution: onResolution
                )
                .environmentObject(themeManager)
                .environmentObject(courseManager)
                .environmentObject(scheduleManager)
            }
            .sheet(isPresented: showingSemesterDetail) {
                SemesterDetailView(
                    semesterAverage: semesterAverage,
                    semesterGPA: semesterGPA,
                    courses: activeScheduleCourses,
                    usePercentageGrades: usePercentageGrades,
                    themeManager: themeManager,
                    activeSchedule: scheduleManager.activeSchedule
                )
            }
            .sheet(isPresented: showingYearDetail) {
                YearDetailView(
                    allSchedules: Array(scheduleManager.scheduleCollections),
                    allCourses: courseManager.courses,
                    selectedScheduleIDs: selectedYearScheduleIDs,
                    usePercentageGrades: usePercentageGrades,
                    themeManager: themeManager
                )
            }
            .sheet(isPresented: showingScheduleManager) {
                ScheduleManagerView()
                    .environmentObject(scheduleManager)
                    .environmentObject(themeManager)
            }
    }

    @ViewBuilder
    func applyLifecycleModifiers(
        courseManager: UnifiedCourseManager,
        scheduleManager: ScheduleManager,
        selectedYearScheduleIDs: Set<UUID>,
        onAppear: @escaping () -> Void,
        onRefresh: @escaping () async -> Void,
        onYearSelectionChange: @escaping () -> Void,
        onScheduleCollectionsChange: @escaping () -> Void
    ) -> some View {
        self
            .onAppear {
                onAppear()
            }
            .refreshable {
                await onRefresh()
            }
            .onChange(of: selectedYearScheduleIDs) { oldValue, newValue in
                onYearSelectionChange()
            }
            .onChange(of: scheduleManager.scheduleCollections.map { $0.id }) {
                onScheduleCollectionsChange()
            }
    }

    @ViewBuilder
    func applyAlertModifiers(
        showDeleteCourseAlert: Binding<Bool>,
        showBulkDeleteAlert: Binding<Bool>,
        bulkSelectionManager: BulkCourseSelectionManager,
        deleteAlert: some View,
        bulkDeleteAlert: some View
    ) -> some View {
        self
            .alert("Delete Course?", isPresented: showDeleteCourseAlert) {
                deleteAlert
            } message: {
                Text("This will remove the course and its assignments.")
            }
            .alert("Delete Selected Courses?", isPresented: showBulkDeleteAlert) {
                bulkDeleteAlert
            } message: {
                Text("This will permanently delete \(bulkSelectionManager.selectedCount()) course(s) and all their assignments.")
            }
    }
}

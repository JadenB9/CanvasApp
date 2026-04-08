import SwiftUI
import EventKit

struct TodoListView: View {
    @ObservedObject var viewModel: CourseViewModel
    @StateObject private var calendarManager = CalendarManager()
    @StateObject private var settings = TodoSettings()
    @State private var showingSettings = false
    @State private var isLoadingAssignments = false

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("To-Do List")
                            .font(.largeTitle.bold())
                        Text("\(upcomingCount) upcoming • \(completedCount) completed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))

                if isLoadingAssignments && allAssignments.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading assignments...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                        // Due Soon Section
                        if !dueSoonAssignments.isEmpty {
                            TodoSection(
                                title: "Due Soon",
                                icon: "clock.fill",
                                color: .red,
                                assignments: dueSoonAssignments,
                                courses: viewModel.courses,
                                calendarManager: calendarManager,
                                settings: settings
                            )
                        }

                        // This Week Section
                        if !thisWeekAssignments.isEmpty {
                            TodoSection(
                                title: "This Week",
                                icon: "calendar",
                                color: .orange,
                                assignments: thisWeekAssignments,
                                courses: viewModel.courses,
                                calendarManager: calendarManager,
                                settings: settings
                            )
                        }

                        // Later Section
                        if !laterAssignments.isEmpty {
                            TodoSection(
                                title: "Later",
                                icon: "calendar.badge.clock",
                                color: .blue,
                                assignments: laterAssignments,
                                courses: viewModel.courses,
                                calendarManager: calendarManager,
                                settings: settings
                            )
                        }

                        // Recently Completed Section
                        if settings.showCompleted && !recentlyCompletedAssignments.isEmpty {
                            TodoSection(
                                title: "Recently Completed",
                                icon: "checkmark.circle.fill",
                                color: .green,
                                assignments: recentlyCompletedAssignments,
                                courses: viewModel.courses,
                                calendarManager: calendarManager,
                                settings: settings,
                                isCompleted: true
                            )
                        }

                        // Bottom padding for tab bar
                        Color.clear
                            .frame(height: 100)
                        }
                        .padding()
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            TodoSettingsView(settings: settings)
        }
        .task {
            // Load assignments for all courses when todo list is shown
            isLoadingAssignments = true
            await viewModel.loadAllAssignments()
            isLoadingAssignments = false
        }
    }

    // MARK: - Computed Properties

    private var allAssignments: [(assignment: Assignment, courseId: Int, courseName: String)] {
        var result: [(Assignment, Int, String)] = []
        for (courseId, assignments) in viewModel.assignments {
            if let course = viewModel.courses.first(where: { $0.id == courseId }) {
                for assignment in assignments {
                    result.append((assignment, courseId, course.name ?? "Unknown"))
                }
            }
        }
        return result
    }

    private var dueSoonAssignments: [(Assignment, Int, String)] {
        let now = Date()
        let next24Hours = Calendar.current.date(byAdding: .hour, value: 24, to: now)!

        return allAssignments.filter { item in
            guard let dueAt = item.assignment.dueAt else { return false }
            let isUpcoming = dueAt > now && dueAt <= next24Hours
            let isNotCompleted = item.assignment.submission?.score == nil
            return isUpcoming && isNotCompleted && !isHidden(item.assignment)
        }.sorted { $0.assignment.dueAt! < $1.assignment.dueAt! }
    }

    private var thisWeekAssignments: [(Assignment, Int, String)] {
        let now = Date()
        let next24Hours = Calendar.current.date(byAdding: .hour, value: 24, to: now)!
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: now)!

        return allAssignments.filter { item in
            guard let dueAt = item.assignment.dueAt else { return false }
            let isThisWeek = dueAt > next24Hours && dueAt <= endOfWeek
            let isNotCompleted = item.assignment.submission?.score == nil
            return isThisWeek && isNotCompleted && !isHidden(item.assignment)
        }.sorted { $0.assignment.dueAt! < $1.assignment.dueAt! }
    }

    private var laterAssignments: [(Assignment, Int, String)] {
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date())!

        return allAssignments.filter { item in
            guard let dueAt = item.assignment.dueAt else { return false }
            let isLater = dueAt > endOfWeek
            let isNotCompleted = item.assignment.submission?.score == nil
            return isLater && isNotCompleted && !isHidden(item.assignment)
        }.sorted { $0.assignment.dueAt! < $1.assignment.dueAt! }
    }

    private var recentlyCompletedAssignments: [(Assignment, Int, String)] {
        let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date())!

        return allAssignments.filter { item in
            let isCompleted = item.assignment.submission?.score != nil
            let isRecent = (item.assignment.submission?.submittedAt ?? Date.distantPast) > twoWeeksAgo
            return isCompleted && isRecent && !isHidden(item.assignment)
        }.sorted { ($0.assignment.submission?.submittedAt ?? Date.distantPast) > ($1.assignment.submission?.submittedAt ?? Date.distantPast) }
    }

    private var upcomingCount: Int {
        dueSoonAssignments.count + thisWeekAssignments.count + laterAssignments.count
    }

    private var completedCount: Int {
        recentlyCompletedAssignments.count
    }

    private func isHidden(_ assignment: Assignment) -> Bool {
        if !settings.showMissing && (assignment.submission?.missing ?? false) {
            return true
        }
        if !settings.showLate && (assignment.submission?.late ?? false) {
            return true
        }
        return false
    }
}

// MARK: - Todo Section
struct TodoSection: View {
    let title: String
    let icon: String
    let color: Color
    let assignments: [(Assignment, Int, String)]
    let courses: [Course]
    let calendarManager: CalendarManager
    let settings: TodoSettings
    var isCompleted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.title3.bold())
                Spacer()
                Text("\(assignments.count)")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color)
                    .cornerRadius(10)
            }

            ForEach(assignments, id: \.0.id) { item in
                TodoCard(
                    assignment: item.0,
                    courseName: item.2,
                    calendarManager: calendarManager,
                    isCompleted: isCompleted
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Todo Card
struct TodoCard: View {
    let assignment: Assignment
    let courseName: String
    let calendarManager: CalendarManager
    let isCompleted: Bool

    @State private var isAddingToCalendar = false
    @State private var showingCalendarSuccess = false
    @State private var showingPermissionAlert = false
    @State private var alertMessage = ""

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Status Icon
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(isCompleted ? .green : .gray)
                .opacity(isCompleted ? 0.5 : 1)

            VStack(alignment: .leading, spacing: 6) {
                // Assignment Name
                Text(assignment.name)
                    .font(.headline)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                    .strikethrough(isCompleted)

                // Course Name and Bonus Badge
                HStack(spacing: 6) {
                    Text(courseName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)

                    if assignment.omitFromFinalGrade == true {
                        Text("BONUS")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple)
                            .cornerRadius(4)
                    }
                }

                // Due Date
                if let dueAt = assignment.dueAt {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(dueAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)

                        if !isCompleted {
                            let timeUntil = dueAt.timeIntervalSinceNow
                            if timeUntil < 0 {
                                Text("• Overdue")
                                    .font(.caption.bold())
                                    .foregroundColor(.red)
                            } else if timeUntil < 3600 * 24 {
                                Text("• \(timeUntilString(dueAt))")
                                    .font(.caption.bold())
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .foregroundColor(.secondary)
                }

                // Points
                if let points = assignment.pointsPossible {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("\(Int(points)) points")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Add to Calendar Button
            if !isCompleted, let dueAt = assignment.dueAt {
                Button {
                    addToCalendar()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: showingCalendarSuccess ? "checkmark.circle.fill" : "calendar.badge.plus")
                            .font(.title3)
                            .foregroundColor(showingCalendarSuccess ? .green : .blue)
                        Text(showingCalendarSuccess ? "Added" : "Add")
                            .font(.caption2)
                            .foregroundColor(showingCalendarSuccess ? .green : .blue)
                    }
                    .frame(width: 60)
                    .padding(.vertical, 8)
                    .background(showingCalendarSuccess ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                .disabled(isAddingToCalendar || showingCalendarSuccess)
            }
        }
        .padding()
        .background(isCompleted ? Color.gray.opacity(0.05) : Color(UIColor.tertiarySystemGroupedBackground))
        .cornerRadius(12)
        .opacity(isCompleted ? 0.6 : 1)
        .alert("Calendar Permission", isPresented: $showingPermissionAlert) {
            Button("Open Settings", role: .none) {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    private func addToCalendar() {
        isAddingToCalendar = true

        Task {
            let result = await calendarManager.addAssignmentToCalendar(assignment: assignment, courseName: courseName)

            await MainActor.run {
                isAddingToCalendar = false

                switch result {
                case .success:
                    showingCalendarSuccess = true
                    // Reset after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showingCalendarSuccess = false
                    }

                case .permissionDenied:
                    alertMessage = "Calendar access is required to add reminders. Please enable it in Settings."
                    showingPermissionAlert = true

                case .failed(let error):
                    alertMessage = "Failed to add event: \(error)"
                    showingPermissionAlert = true
                }
            }
        }
    }

    private func timeUntilString(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        let hours = Int(interval / 3600)

        if hours < 1 {
            let minutes = Int(interval / 60)
            return "\(minutes) min left"
        } else if hours < 24 {
            return "\(hours)h left"
        } else {
            let days = Int(interval / (3600 * 24))
            return "\(days)d left"
        }
    }
}

// MARK: - Todo Settings
class TodoSettings: ObservableObject {
    @Published var showCompleted: Bool = true
    @Published var showMissing: Bool = true
    @Published var showLate: Bool = true
    @Published var daysAhead: Int = 30
    @Published var completedDaysBack: Int = 14
}

// MARK: - Settings View
struct TodoSettingsView: View {
    @ObservedObject var settings: TodoSettings
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Display Options") {
                    Toggle("Show Completed Assignments", isOn: $settings.showCompleted)
                    Toggle("Show Missing Assignments", isOn: $settings.showMissing)
                    Toggle("Show Late Assignments", isOn: $settings.showLate)
                }

                Section("Time Range") {
                    Stepper("Show \(settings.daysAhead) days ahead", value: $settings.daysAhead, in: 7...90, step: 7)

                    if settings.showCompleted {
                        Stepper("Show completed from last \(settings.completedDaysBack) days", value: $settings.completedDaysBack, in: 7...30, step: 7)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Calendar Integration")
                        Spacer()
                        Text("Enabled")
                            .foregroundColor(.green)
                    }
                    Text("Tap 'Add' on any assignment to add it to your Apple Calendar with a reminder.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("To-Do Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Calendar Result
enum CalendarResult {
    case success
    case permissionDenied
    case failed(String)
}

// MARK: - Calendar Manager
@MainActor
class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            print("📅 Calendar permission: \(granted ? "granted" : "denied")")
            return granted
        } catch {
            print("❌ Calendar access error: \(error)")
            return false
        }
    }

    func addAssignmentToCalendar(assignment: Assignment, courseName: String) async -> CalendarResult {
        // Check current status
        let currentStatus = EKEventStore.authorizationStatus(for: .event)
        print("📅 Current authorization status: \(currentStatus.rawValue)")

        // Request access if needed
        if currentStatus != .fullAccess {
            print("📅 Requesting calendar access...")
            let granted = await requestAccess()
            if !granted {
                print("❌ Calendar access denied by user")
                return .permissionDenied
            }
        }

        guard let dueDate = assignment.dueAt else {
            print("❌ No due date for assignment")
            return .failed("No due date available")
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = "\(courseName): \(assignment.name)"
        event.startDate = dueDate
        event.endDate = dueDate.addingTimeInterval(3600) // 1 hour duration
        event.calendar = eventStore.defaultCalendarForNewEvents

        // Add notes with assignment details
        var notes = "Canvas Assignment\n"
        if let points = assignment.pointsPossible {
            notes += "Points: \(Int(points))\n"
        }
        notes += "Course: \(courseName)"
        event.notes = notes

        // Add alarms
        let alarm1Day = EKAlarm(relativeOffset: -86400) // 24 hours before
        let alarm1Hour = EKAlarm(relativeOffset: -3600) // 1 hour before
        event.addAlarm(alarm1Day)
        event.addAlarm(alarm1Hour)

        do {
            try eventStore.save(event, span: .thisEvent)
            print("✅ Added '\(assignment.name)' to calendar")
            return .success
        } catch {
            print("❌ Failed to save event: \(error.localizedDescription)")
            return .failed(error.localizedDescription)
        }
    }
}

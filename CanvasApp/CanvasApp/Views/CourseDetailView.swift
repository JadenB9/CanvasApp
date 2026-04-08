import SwiftUI

struct CourseDetailView: View {
    let course: Course
    @ObservedObject var viewModel: CourseViewModel
    @StateObject private var preferences = CoursePreferences()
    @StateObject private var calculator = GradeCalculator()
    @State private var showingWhatIf = false
    @State private var sortOrder: SortOrder = .newestFirst
    @State private var showingGoalGrade = false
    @State private var goalGradeText = ""

    enum SortOrder: String, CaseIterable {
        case newestFirst = "Newest First"
        case oldestFirst = "Oldest First"
        case uncompletedFirst = "Uncompleted First"
    }

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Grade Summary
                    if let enrollment = course.enrollments?.first(where: { $0.type.lowercased() == "student" }) {
                        VStack(spacing: 16) {
                            // Current Progress Display
                            VStack(spacing: 8) {
                                Text("Current Progress")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    let displayScore = calculator.calculatedScore ?? enrollment.computedCurrentScore
                                    if let score = displayScore {
                                        Text(String(format: "%.1f%%", score))
                                            .font(.system(size: 48, weight: .bold))
                                            .foregroundColor(calculator.calculatedScore != nil ? .orange : gradeColor(for: score))
                                    }

                                    Text("•")
                                        .font(.title)
                                        .foregroundColor(.secondary)

                                    Text(enrollment.formattedGrade)
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(calculator.calculatedScore != nil ? .orange : (enrollment.computedCurrentScore.map { gradeColor(for: $0) } ?? .primary))
                                }

                                // Debug: Show both values if different (even without what-if active)
                                if let calculated = calculator.calculatedScore,
                                   let apiScore = enrollment.computedCurrentScore,
                                   calculator.whatIfScores.isEmpty,
                                   abs(calculated - apiScore) > 0.1 {
                                    VStack(spacing: 4) {
                                        Text("⚠️ Calculation differs from Canvas")
                                            .font(.caption2.bold())
                                            .foregroundColor(.red)
                                        HStack(spacing: 12) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Canvas")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text(String(format: "%.2f%%", apiScore))
                                                    .font(.caption.bold())
                                                    .foregroundColor(.green)
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Our Calc")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                                Text(String(format: "%.2f%%", calculated))
                                                    .font(.caption.bold())
                                                    .foregroundColor(.orange)
                                            }
                                        }
                                        .padding(6)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(6)
                                    }
                                }

                                if !calculator.whatIfScores.isEmpty {
                                    Text("What-If Mode Active")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(16)

                            // What-If Toggle
                            Toggle(isOn: $showingWhatIf) {
                                HStack {
                                    Image(systemName: showingWhatIf ? "lightbulb.fill" : "lightbulb")
                                        .foregroundColor(showingWhatIf ? .orange : .blue)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("What-If Calculator")
                                            .font(.headline)
                                        Text(showingWhatIf ? "Edit scores below to test scenarios" : "Enable to test grade scenarios")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .tint(.orange)
                            .padding()
                            .background(showingWhatIf ? Color.orange.opacity(0.1) : Color.blue.opacity(0.05))
                            .cornerRadius(12)
                            .onChange(of: showingWhatIf) { _, newValue in
                                if !newValue {
                                    calculator.resetWhatIfScores()
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }

                    // Sorting Picker
                    if let assignments = viewModel.assignments[course.id], !assignments.isEmpty {
                        Picker("Sort By", selection: $sortOrder) {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                    }

                    // Goal Grade Button (only when What-If is enabled)
                    if showingWhatIf {
                        Button {
                            showingGoalGrade = true
                        } label: {
                            HStack {
                                Image(systemName: "target")
                                    .font(.title3)
                                Text("Calculate Needed Grades for Goal")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .sheet(isPresented: $showingGoalGrade) {
                            GoalGradeSheet(
                                calculator: calculator,
                                assignments: viewModel.assignments[course.id] ?? [],
                                groups: viewModel.assignmentGroups[course.id] ?? [],
                                useWeights: course.applyAssignmentGroupWeights ?? false
                            )
                        }
                    }

                    // Assignments List
                    if viewModel.getAssignmentLoadingState(for: course.id) {
                        ProgressView("Loading assignments...")
                            .padding()
                    } else if let assignments = viewModel.assignments[course.id], !assignments.isEmpty {
                        LazyVStack(spacing: 12) {
                            ForEach(sortedAssignments(assignments)) { assignment in
                                AssignmentCardWithWhatIf(
                                    assignment: assignment,
                                    calculator: calculator,
                                    showingWhatIf: showingWhatIf
                                )
                            }
                        }
                        .padding()
                    } else {
                        ContentUnavailableView(
                            "No Assignments",
                            systemImage: "doc.text",
                            description: Text("There are no assignments for this course yet.")
                        )
                    }
                }
            }
        }
        .navigationTitle(preferences.customNames[course.id] ?? course.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.refreshCourseData(courseId: course.id)
            if let assignments = viewModel.assignments[course.id] {
                let groups = viewModel.assignmentGroups[course.id] ?? []
                let useWeights = course.applyAssignmentGroupWeights ?? false
                calculator.initializeWithAssignments(assignments, groups: groups, useWeights: useWeights)
            }
        }
        .refreshable {
            await viewModel.refreshCourseData(courseId: course.id)
            if let assignments = viewModel.assignments[course.id] {
                let groups = viewModel.assignmentGroups[course.id] ?? []
                let useWeights = course.applyAssignmentGroupWeights ?? false
                calculator.initializeWithAssignments(assignments, groups: groups, useWeights: useWeights)
            }
        }
    }

    private func gradeColor(for score: Double) -> Color {
        switch score {
        case 90...: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        case 60..<70: return .yellow
        default: return .red
        }
    }

    private func sortedAssignments(_ assignments: [Assignment]) -> [Assignment] {
        switch sortOrder {
        case .newestFirst:
            return assignments.sorted {
                if let date1 = $0.dueAt, let date2 = $1.dueAt {
                    return date1 > date2
                }
                return $0.dueAt != nil
            }
        case .oldestFirst:
            return assignments.sorted {
                if let date1 = $0.dueAt, let date2 = $1.dueAt {
                    return date1 < date2
                }
                return $0.dueAt == nil
            }
        case .uncompletedFirst:
            return assignments.sorted { assignment1, assignment2 in
                let completed1 = assignment1.submission?.score != nil
                let completed2 = assignment2.submission?.score != nil

                if completed1 != completed2 {
                    return !completed1
                }

                // If both have same completion status, sort by due date (newest first)
                if let date1 = assignment1.dueAt, let date2 = assignment2.dueAt {
                    return date1 > date2
                }
                return assignment1.dueAt != nil
            }
        }
    }

    class CoursePreferences: ObservableObject {
        @Published private(set) var customNames: [Int: String] = [:]
        @PersistentDictionary("courseCustomNames") private var storedNames: [Int: String]

        init() {
            customNames = storedNames
        }

        func setCustomName(_ name: String?, for courseId: Int) {
            if let name = name, !name.isEmpty {
                storedNames[courseId] = name
            } else {
                storedNames.removeValue(forKey: courseId)
            }
            customNames = storedNames
        }
    }

    @propertyWrapper
    struct PersistentDictionary<T: Codable> {
        private let key: String
        private let defaultValue: [Int: T]

        init(_ key: String, defaultValue: [Int: T] = [:]) {
            self.key = key
            self.defaultValue = defaultValue
        }

        var wrappedValue: [Int: T] {
            get {
                guard let data = UserDefaults.standard.data(forKey: key),
                      let dict = try? JSONDecoder().decode([Int: T].self, from: data) else {
                    return defaultValue
                }
                return dict
            }
            set {
                guard let data = try? JSONEncoder().encode(newValue) else { return }
                UserDefaults.standard.set(data, forKey: key)
            }
        }
    }
}

// MARK: - Assignment Card with inline What-If
struct AssignmentCardWithWhatIf: View {
    let assignment: Assignment
    @ObservedObject var calculator: GradeCalculator
    let showingWhatIf: Bool
    @State private var whatIfText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                Text(assignment.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                StatusBadgeCompact(assignment: assignment)
            }

            // Score Display or Input
            HStack(spacing: 12) {
                let displayScore = calculator.whatIfScores[assignment.id] ?? assignment.submission?.score
                let isWhatIf = calculator.whatIfScores[assignment.id] != nil

                // Show score or input field
                if showingWhatIf {
                    // What-If Input Mode
                    HStack(spacing: 8) {
                        TextField("Score", text: $whatIfText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .focused($isFocused)
                            .onChange(of: whatIfText) { _, newValue in
                                if let score = Double(newValue) {
                                    calculator.setWhatIfScore(for: assignment.id, score: score)
                                } else if newValue.isEmpty {
                                    calculator.setWhatIfScore(for: assignment.id, score: nil)
                                }
                            }

                        Text("/ \(formatPoints(assignment.pointsPossible ?? assignment.submission?.score ?? 100))")
                            .foregroundColor(.secondary)

                        if showingWhatIf && isWhatIf {
                            Button {
                                // Revert to original grade or remove from calculation
                                if let originalScore = assignment.submission?.score {
                                    // Had original grade - revert to it
                                    calculator.setWhatIfScore(for: assignment.id, score: originalScore)
                                    whatIfText = formatPoints(originalScore)
                                } else {
                                    // No original grade - remove from calculation
                                    calculator.setWhatIfScore(for: assignment.id, score: nil)
                                    whatIfText = ""
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Reset")
                                        .font(.caption2)
                                }
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.orange.opacity(0.15))
                                .cornerRadius(6)
                            }
                        }
                    }
                } else {
                    // Normal Display Mode
                    if let score = displayScore {
                        // ALWAYS show actual score, don't use score as denominator
                        if let points = assignment.pointsPossible {
                            HStack(spacing: 6) {
                                Text(formatPoints(score))
                                    .font(.title3.bold())
                                    .foregroundColor(scoreColor(score: score, possible: points))

                                Text("/")
                                    .foregroundColor(.secondary)

                                Text(formatPoints(points))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                // Percentage
                                let percentage = (score / points) * 100
                                Text(String(format: "%.0f%%", percentage))
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(percentageColor(percentage))
                                    .cornerRadius(8)
                            }
                        } else {
                            // Has score but no points possible - just show score
                            HStack(spacing: 6) {
                                Text(formatPoints(score))
                                    .font(.title3.bold())
                                    .foregroundColor(.green)

                                Text("points")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        // No score yet
                        if let points = assignment.pointsPossible {
                            HStack(spacing: 6) {
                                Text("—")
                                    .font(.title3.bold())
                                    .foregroundColor(.secondary)

                                Text("/ \(formatPoints(points))")
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack(spacing: 6) {
                                Text("Not graded")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .italic()
                            }
                        }
                    }
                }

                Spacer()
            }

            // Due date
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.caption)
                if let dueAt = assignment.dueAt {
                    Text(dueAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                } else {
                    Text("No due date")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .onAppear {
            if let whatIfScore = calculator.whatIfScores[assignment.id] {
                whatIfText = formatPoints(whatIfScore)
            } else if let score = assignment.submission?.score {
                whatIfText = formatPoints(score)
            }
        }
    }

    private func formatPoints(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func scoreColor(score: Double, possible: Double) -> Color {
        if score == 0 { return .red }
        let percentage = (score / possible) * 100
        return percentageColor(percentage)
    }

    private func percentageColor(_ percentage: Double) -> Color {
        switch percentage {
        case 90...: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        case 60..<70: return .yellow
        default: return .red
        }
    }
}

// MARK: - Goal Grade Sheet
struct GoalGradeSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var calculator: GradeCalculator
    let assignments: [Assignment]
    let groups: [AssignmentGroup]
    let useWeights: Bool

    @State private var goalGradeText = ""
    @State private var calculationResult: GoalGradeResult?
    @State private var showingResult = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter Your Goal Grade")
                        .font(.headline)

                    HStack {
                        TextField("e.g., 95", text: $goalGradeText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .font(.title2)

                        Text("%")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }

                    Text("The calculator will determine what you need on remaining assignments to achieve this grade.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)

                Button {
                    calculateNeededGrades()
                } label: {
                    Text("Calculate Needed Grades")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(goalGradeText.isEmpty)

                if showingResult, let result = calculationResult {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if result.isPossible {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.title)
                                        Text("Goal is Achievable!")
                                            .font(.title2.bold())
                                    }

                                    Text("To achieve a \(String(format: "%.1f%%", result.goalGrade)), you need the following scores on uncompleted assignments:")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)

                                ForEach(result.neededScores, id: \.assignmentId) { needed in
                                    if let assignment = assignments.first(where: { $0.id == needed.assignmentId }) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(assignment.name)
                                                .font(.headline)

                                            HStack {
                                                Text("Need:")
                                                    .foregroundColor(.secondary)
                                                Text(String(format: "%.1f", needed.neededScore))
                                                    .font(.title3.bold())
                                                    .foregroundColor(.green)
                                                Text("/ \(String(format: "%.0f", needed.maxPoints))")
                                                    .foregroundColor(.secondary)
                                                Text("(\(String(format: "%.1f%%", (needed.neededScore / needed.maxPoints) * 100)))")
                                                    .font(.caption.bold())
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 3)
                                                    .background(Color.green)
                                                    .cornerRadius(8)
                                            }

                                            Button {
                                                calculator.setWhatIfScore(for: assignment.id, score: needed.neededScore)
                                                dismiss()
                                            } label: {
                                                Text("Apply This Score")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                        .padding()
                                        .background(Color(UIColor.secondarySystemGroupedBackground))
                                        .cornerRadius(12)
                                    }
                                }

                                Button {
                                    applyAllScores(result.neededScores)
                                } label: {
                                    Text("Apply All Scores")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.title)
                                        Text("Goal Not Achievable")
                                            .font(.title2.bold())
                                    }

                                    Text(result.message)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

                                    if result.maxPossibleGrade > 0 {
                                        Text("Maximum possible grade: \(String(format: "%.1f%%", result.maxPossibleGrade))")
                                            .font(.headline)
                                            .foregroundColor(.orange)
                                    }
                                }
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Goal Grade Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func calculateNeededGrades() {
        guard let goalGrade = Double(goalGradeText) else { return }

        calculationResult = calculator.calculateNeededGrades(
            goalGrade: goalGrade,
            assignments: assignments,
            groups: groups,
            useWeights: useWeights
        )
        showingResult = true
    }

    private func applyAllScores(_ scores: [NeededScore]) {
        for score in scores {
            calculator.setWhatIfScore(for: score.assignmentId, score: score.neededScore)
        }
        dismiss()
    }
}


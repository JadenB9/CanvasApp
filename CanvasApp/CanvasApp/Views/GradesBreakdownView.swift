import SwiftUI

struct GradesBreakdownView: View {
    let course: Course
    @ObservedObject var viewModel: CourseViewModel
    @StateObject private var calculator = GradeCalculator()
    @State private var showingWhatIf = false
    @State private var selectedAssignment: Assignment?
    @State private var showingAssignmentDetail = false

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            List {
                // Current Grade Summary with What-If Toggle
                Section {
                    if let enrollment = course.enrollments?.first(where: { $0.type.lowercased() == "student" }) {
                        VStack(spacing: 16) {
                            // What-If Mode Toggle - Prominent placement
                            Toggle(isOn: $showingWhatIf) {
                                HStack {
                                    Image(systemName: showingWhatIf ? "lightbulb.fill" : "lightbulb")
                                        .foregroundColor(showingWhatIf ? .orange : .blue)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("What-If Calculator")
                                            .font(.headline)
                                        Text(showingWhatIf ? "Tap assignments to test scores" : "Test how scores affect your grade")
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

                            // Grade Display
                            GradeSummaryCard(
                                currentScore: calculator.calculatedScore ?? enrollment.computedCurrentScore,
                                currentGrade: enrollment.displayGrade,
                                finalScore: enrollment.computedFinalScore,
                                finalGrade: enrollment.computedFinalGrade,
                                isWhatIfActive: !calculator.whatIfScores.isEmpty
                            )
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                // Statistics Summary
                if let assignments = viewModel.assignments[course.id] {
                    Section {
                        StatisticsView(assignments: assignments, calculator: calculator)
                    } header: {
                        Text("Overview")
                            .font(.headline)
                    }
                }

                // Assignment Groups
                if let groups = viewModel.assignmentGroups[course.id],
                   let assignments = viewModel.assignments[course.id] {

                    ForEach(groups) { group in
                        let groupAssignments = assignments.filter { $0.assignmentGroupId == group.id }
                        if !groupAssignments.isEmpty {
                            AssignmentGroupSection(
                                group: group,
                                assignments: groupAssignments,
                                calculator: calculator,
                                showingWhatIf: showingWhatIf,
                                onAssignmentTap: { assignment in
                                    selectedAssignment = assignment
                                    showingAssignmentDetail = true
                                }
                            )
                        }
                    }

                    // Assignments without a group
                    let ungroupedAssignments = assignments.filter { $0.assignmentGroupId == nil }
                    if !ungroupedAssignments.isEmpty {
                        AssignmentGroupSection(
                            group: nil,
                            assignments: ungroupedAssignments,
                            calculator: calculator,
                            showingWhatIf: showingWhatIf,
                            onAssignmentTap: { assignment in
                                selectedAssignment = assignment
                                showingAssignmentDetail = true
                            }
                        )
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Grade Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedAssignment) { assignment in
            AssignmentDetailSheet(
                assignment: assignment,
                calculator: calculator,
                showingWhatIf: showingWhatIf
            )
        }
        .task {
            if let assignments = viewModel.assignments[course.id] {
                calculator.initializeWithAssignments(assignments)
            }
        }
    }
}

// MARK: - Statistics View
struct StatisticsView: View {
    let assignments: [Assignment]
    @ObservedObject var calculator: GradeCalculator

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                StatPill(
                    title: "Total",
                    value: "\(assignments.count)",
                    color: .blue
                )
                StatPill(
                    title: "Graded",
                    value: "\(gradedCount)",
                    color: .green
                )
                StatPill(
                    title: "Pending",
                    value: "\(pendingGradeCount)",
                    color: .orange
                )
                StatPill(
                    title: "Missing",
                    value: "\(missingCount)",
                    color: .red
                )
            }

            HStack(spacing: 16) {
                StatPill(
                    title: "Zeros",
                    value: "\(zeroScoreCount)",
                    color: .purple
                )
                StatPill(
                    title: "Late",
                    value: "\(lateCount)",
                    color: .yellow
                )
                StatPill(
                    title: "Excused",
                    value: "\(excusedCount)",
                    color: .gray
                )
                StatPill(
                    title: "Not Done",
                    value: "\(notSubmittedCount)",
                    color: .secondary
                )
            }
        }
        .padding(.vertical, 8)
    }

    private var gradedCount: Int {
        assignments.filter { $0.isGraded && !$0.isExcused }.count
    }

    private var pendingGradeCount: Int {
        assignments.filter { $0.needsGrading }.count
    }

    private var missingCount: Int {
        assignments.filter { $0.isMissing }.count
    }

    private var zeroScoreCount: Int {
        assignments.filter { $0.hasZeroScore }.count
    }

    private var lateCount: Int {
        assignments.filter { $0.isLate }.count
    }

    private var excusedCount: Int {
        assignments.filter { $0.isExcused }.count
    }

    private var notSubmittedCount: Int {
        assignments.filter { !$0.isSubmitted && !$0.isMissing && !$0.isExcused }.count
    }
}

struct StatPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Grade Summary Card
struct GradeSummaryCard: View {
    let currentScore: Double?
    let currentGrade: String?
    let finalScore: Double?
    let finalGrade: String?
    let isWhatIfActive: Bool

    var body: some View {
        VStack(spacing: 16) {
            if isWhatIfActive {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Showing hypothetical grades")
                        .font(.caption.bold())
                        .foregroundColor(.orange)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            HStack(spacing: 30) {
                GradePill(
                    title: "Current Grade",
                    score: currentScore,
                    grade: currentGrade,
                    isWhatIf: isWhatIfActive
                )

                if let finalScore = finalScore {
                    GradePill(
                        title: "Final Grade",
                        score: finalScore,
                        grade: finalGrade,
                        isWhatIf: false
                    )
                }
            }
            .padding()

            if isWhatIfActive {
                Text("These scores are hypothetical and not saved")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct GradePill: View {
    let title: String
    let score: Double?
    let grade: String?
    let isWhatIf: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            if let score = score {
                Text(String(format: "%.2f%%", score))
                    .font(.title2.bold())
                    .foregroundColor(isWhatIf ? .orange : gradeColor(for: score))
            } else {
                Text("N/A")
                    .font(.title2.bold())
                    .foregroundColor(.secondary)
            }

            if let grade = grade, !grade.isEmpty {
                Text(grade)
                    .font(.subheadline)
                    .foregroundColor(isWhatIf ? .orange : .secondary)
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
}

// MARK: - Assignment Group Section
struct AssignmentGroupSection: View {
    let group: AssignmentGroup?
    let assignments: [Assignment]
    @ObservedObject var calculator: GradeCalculator
    let showingWhatIf: Bool
    let onAssignmentTap: (Assignment) -> Void

    var body: some View {
        Section {
            ForEach(assignments) { assignment in
                Button {
                    onAssignmentTap(assignment)
                } label: {
                    ComprehensiveAssignmentRow(
                        assignment: assignment,
                        calculator: calculator,
                        showingWhatIf: showingWhatIf
                    )
                }
                .buttonStyle(.plain)
            }
        } header: {
            HStack {
                Text(group?.name ?? "Other Assignments")
                    .font(.headline)
                Spacer()
                if let weight = group?.groupWeight {
                    Text("\(Int(weight))%")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                }
            }
        }
    }
}

// MARK: - Comprehensive Assignment Row
struct ComprehensiveAssignmentRow: View {
    let assignment: Assignment
    @ObservedObject var calculator: GradeCalculator
    let showingWhatIf: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    // Assignment name
                    Text(assignment.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    // Status badges
                    HStack(spacing: 6) {
                        StatusBadgeView(assignment: assignment)

                        if assignment.omitFromFinalGrade == true {
                            Text("BONUS")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple)
                                .cornerRadius(4)
                        }

                        if let submission = assignment.submission {
                            if submission.hasDeductions {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }

                            if submission.gradeMatchesCurrentSubmission == false {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                        }
                    }

                    // Due date
                    if let dueAt = assignment.dueAt {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(dueAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }

                    // Additional details if available
                    if let submission = assignment.submission,
                       let details = submission.detailedStatusDescription {
                        Text(details)
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.top, 2)
                    }
                }

                Spacer()

                // Score display
                VStack(alignment: .trailing, spacing: 4) {
                    let displayScore = calculator.whatIfScores[assignment.id] ?? assignment.submission?.score
                    let isWhatIf = calculator.whatIfScores[assignment.id] != nil

                    if let score = displayScore, let possible = assignment.pointsPossible {
                        // Score fraction
                        HStack(spacing: 2) {
                            Text(String(format: "%.1f", score))
                                .font(.subheadline.bold())
                                .foregroundColor(scoreColor(score: score, possible: possible, isWhatIf: isWhatIf))
                            Text("/")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", possible))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Percentage
                        if let percentage = calculatePercentage(score: score, possible: possible) {
                            Text("\(String(format: "%.1f%%", percentage))")
                                .font(.caption.weight(.medium))
                                .foregroundColor(isWhatIf ? .orange : percentageColor(percentage))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background((isWhatIf ? Color.orange : percentageColor(percentage)).opacity(0.15))
                                .cornerRadius(6)
                        }

                        // Points deducted indicator
                        if let deductions = assignment.submission?.pointsDeducted, deductions > 0 {
                            Text("-\(String(format: "%.1f", deductions)) pts")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    } else if let possible = assignment.pointsPossible {
                        HStack(spacing: 2) {
                            Text("—")
                                .font(.subheadline)
                            Text("/")
                                .font(.caption)
                            Text(String(format: "%.1f", possible))
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)

                        Text("Not Graded")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .italic()
                    }

                    // What-if indicator
                    if showingWhatIf {
                        Image(systemName: isWhatIf ? "lightbulb.fill" : "lightbulb")
                            .foregroundColor(isWhatIf ? .orange : .gray.opacity(0.3))
                            .font(.caption)
                            .padding(.top, 2)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func calculatePercentage(score: Double, possible: Double) -> Double? {
        guard possible > 0 else { return nil }
        return (score / possible) * 100
    }

    private func scoreColor(score: Double, possible: Double, isWhatIf: Bool) -> Color {
        if isWhatIf { return .orange }
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

// MARK: - Status Badge View
struct StatusBadgeView: View {
    let assignment: Assignment

    var body: some View {
        HStack(spacing: 4) {
            if assignment.isExcused {
                StatusBadge(text: "Excused", color: .purple, icon: "checkmark.circle.fill")
            } else if assignment.isMissing {
                StatusBadge(text: "Missing", color: .red, icon: "exclamationmark.circle.fill")
            } else if assignment.hasZeroScore {
                StatusBadge(text: "Zero", color: .red, icon: "0.circle.fill")
            } else if assignment.needsGrading {
                StatusBadge(text: "Pending", color: .orange, icon: "clock.fill")
            } else if assignment.isLate {
                StatusBadge(text: "Late", color: .yellow, icon: "clock.badge.exclamationmark.fill")
            } else if assignment.isGraded {
                StatusBadge(text: "Graded", color: .green, icon: "checkmark.circle.fill")
            } else if assignment.isSubmitted {
                StatusBadge(text: "Submitted", color: .blue, icon: "paperplane.fill")
            } else {
                StatusBadge(text: "Not Done", color: .secondary, icon: "circle")
            }
        }
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color
    let icon: String?

    init(text: String, color: Color, icon: String? = nil) {
        self.text = text
        self.color = color
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 3) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .cornerRadius(6)
    }
}

// MARK: - Assignment Detail Sheet
struct AssignmentDetailSheet: View {
    let assignment: Assignment
    @ObservedObject var calculator: GradeCalculator
    let showingWhatIf: Bool
    @Environment(\.dismiss) var dismiss
    @State private var whatIfScoreText: String = ""
    @State private var showingAlert = false

    var body: some View {
        NavigationStack {
            List {
                // Assignment Info
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(assignment.name)
                            .font(.title3.bold())

                        if let description = assignment.description, !description.isEmpty {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Assignment")
                }

                // Current Score Section
                Section {
                    if let submission = assignment.submission {
                        if let score = submission.score, let possible = assignment.pointsPossible {
                            DetailRow(title: "Current Score", value: "\(String(format: "%.2f", score)) / \(String(format: "%.2f", possible))")

                            if let percentage = calculatePercentage(score: score, possible: possible) {
                                DetailRow(title: "Percentage", value: String(format: "%.2f%%", percentage))
                            }

                            if let grade = submission.grade {
                                DetailRow(title: "Letter Grade", value: grade)
                            }

                            if let deductions = submission.pointsDeducted, deductions > 0 {
                                DetailRow(title: "Points Deducted", value: String(format: "%.2f", deductions))
                                    .foregroundColor(.red)
                            }
                        } else {
                            Text("No score recorded")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("No submission")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Grading")
                }

                // Status Section
                Section {
                    DetailRow(title: "Status", value: assignment.submission?.statusDescription ?? "Not Submitted")

                    if let submission = assignment.submission {
                        if let submittedAt = submission.submittedAt {
                            DetailRow(title: "Submitted", value: submittedAt.formatted(date: .long, time: .shortened))
                        }

                        if let gradedAt = submission.gradedAt {
                            DetailRow(title: "Graded", value: gradedAt.formatted(date: .long, time: .shortened))
                        }

                        if let seconds = submission.secondsLate, seconds > 0 {
                            let hours = seconds / 3600
                            let days = hours / 24
                            let timeString = days > 0 ? "\(days) days late" : "\(hours) hours late"
                            DetailRow(title: "Late By", value: timeString)
                        }

                        if submission.gradeMatchesCurrentSubmission == false {
                            Text("Resubmitted - Needs regrading")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }

                        if submission.redoRequest == true {
                            Text("Redo requested by instructor")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("Submission Details")
                }

                // Due Date Section
                Section {
                    if let dueAt = assignment.dueAt {
                        DetailRow(title: "Due Date", value: dueAt.formatted(date: .long, time: .shortened))
                    } else {
                        Text("No due date")
                            .foregroundColor(.secondary)
                    }

                    if let unlockAt = assignment.unlockAt {
                        DetailRow(title: "Available From", value: unlockAt.formatted(date: .long, time: .shortened))
                    }

                    if let lockAt = assignment.lockAt {
                        DetailRow(title: "Lock Date", value: lockAt.formatted(date: .long, time: .shortened))
                    }
                } header: {
                    Text("Dates")
                }

                // Assignment Settings
                Section {
                    if let possible = assignment.pointsPossible {
                        DetailRow(title: "Points Possible", value: String(format: "%.0f", possible))
                    }

                    if let gradingType = assignment.gradingType {
                        DetailRow(title: "Grading Type", value: gradingType.replacingOccurrences(of: "_", with: " ").capitalized)
                    }

                    if let attempts = assignment.allowedAttempts {
                        let attemptsText = attempts == -1 ? "Unlimited" : "\(attempts)"
                        DetailRow(title: "Allowed Attempts", value: attemptsText)
                    }

                    if let attempt = assignment.submission?.attempt {
                        DetailRow(title: "Current Attempt", value: "\(attempt)")
                    }
                } header: {
                    Text("Assignment Settings")
                }

                // What-If Calculator Section
                if showingWhatIf {
                    Section {
                        if let possible = assignment.pointsPossible {
                            HStack {
                                TextField("Enter score", text: $whatIfScoreText)
                                    .keyboardType(.decimalPad)

                                Text("/ \(String(format: "%.1f", possible))")
                                    .foregroundColor(.secondary)
                            }

                            if let score = Double(whatIfScoreText), possible > 0 {
                                let percentage = (score / possible) * 100
                                HStack {
                                    Text("Would be:")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(String(format: "%.1f%%", percentage))
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                }
                            }

                            Button {
                                if let score = Double(whatIfScoreText) {
                                    if score <= possible {
                                        calculator.setWhatIfScore(for: assignment.id, score: score)
                                        dismiss()
                                    } else {
                                        showingAlert = true
                                    }
                                } else if whatIfScoreText.isEmpty {
                                    calculator.setWhatIfScore(for: assignment.id, score: nil)
                                    dismiss()
                                }
                            } label: {
                                Text("Apply What-If Score")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)

                            if calculator.whatIfScores[assignment.id] != nil {
                                Button(role: .destructive) {
                                    calculator.setWhatIfScore(for: assignment.id, score: nil)
                                    dismiss()
                                } label: {
                                    Text("Clear What-If Score")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.orange)
                            Text("What-If Calculator")
                        }
                    } footer: {
                        Text("Enter a hypothetical score to see how it would affect your overall grade")
                    }
                }
            }
            .navigationTitle("Assignment Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Invalid Score", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text("Score cannot exceed the maximum points possible")
            }
        }
        .onAppear {
            if let whatIfScore = calculator.whatIfScores[assignment.id] {
                whatIfScoreText = String(format: "%.2f", whatIfScore)
            } else if let score = assignment.submission?.score {
                whatIfScoreText = String(format: "%.2f", score)
            }
        }
    }

    private func calculatePercentage(score: Double, possible: Double) -> Double? {
        guard possible > 0 else { return nil }
        return (score / possible) * 100
    }
}


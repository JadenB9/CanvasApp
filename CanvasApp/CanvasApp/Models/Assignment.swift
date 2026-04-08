import Foundation

struct Assignment: Codable, Identifiable {
    // Core Fields
    let id: Int
    let name: String
    let dueAt: Date?
    let lockAt: Date?
    let unlockAt: Date?
    let pointsPossible: Double?
    let description: String?
    let assignmentGroupId: Int?
    let position: Int?
    let courseId: Int?

    // Grading Fields
    let gradingType: String?
    let submissionTypes: [String]?

    // Status Fields
    let published: Bool?
    let lockedForUser: Bool?
    let hasSubmittedSubmissions: Bool?
    let omitFromFinalGrade: Bool?

    // Attempts & Policies
    let allowedAttempts: Int?

    // Submission
    let submission: Submission?

    enum CodingKeys: String, CodingKey {
        case id, name, description, submission, position
        case dueAt = "due_at"
        case lockAt = "lock_at"
        case unlockAt = "unlock_at"
        case pointsPossible = "points_possible"
        case assignmentGroupId = "assignment_group_id"
        case courseId = "course_id"
        case gradingType = "grading_type"
        case submissionTypes = "submission_types"
        case published
        case lockedForUser = "locked_for_user"
        case hasSubmittedSubmissions = "has_submitted_submissions"
        case omitFromFinalGrade = "omit_from_final_grade"
        case allowedAttempts = "allowed_attempts"
    }
}

struct Submission: Codable {
    // Core Fields
    let id: Int?
    let assignmentId: Int?
    let userId: Int?

    // Submission Content
    let submissionType: String?
    let submittedAt: Date?
    let attempt: Int?
    let body: String?
    let url: String?

    // Grading Information
    let score: Double?
    let grade: String?
    let enteredScore: Double?
    let enteredGrade: String?
    let gradeMatchesCurrentSubmission: Bool?
    let graderId: Int?
    let gradedAt: Date?

    // Status & Policy Fields
    let workflowState: String?
    let late: Bool?
    let latePolicyStatus: String?
    let missing: Bool?
    let excused: Bool?
    let assignmentVisible: Bool?

    // Deduction & Time Fields
    let pointsDeducted: Double?
    let secondsLate: Int?
    let extraAttempts: Int?

    // Posted Status
    let postedAt: Date?
    let redoRequest: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case assignmentId = "assignment_id"
        case userId = "user_id"
        case submissionType = "submission_type"
        case submittedAt = "submitted_at"
        case attempt
        case body, url
        case score, grade
        case enteredScore = "entered_score"
        case enteredGrade = "entered_grade"
        case gradeMatchesCurrentSubmission = "grade_matches_current_submission"
        case graderId = "grader_id"
        case gradedAt = "graded_at"
        case workflowState = "workflow_state"
        case late
        case latePolicyStatus = "late_policy_status"
        case missing, excused
        case assignmentVisible = "assignment_visible"
        case pointsDeducted = "points_deducted"
        case secondsLate = "seconds_late"
        case extraAttempts = "extra_attempts"
        case postedAt = "posted_at"
        case redoRequest = "redo_request"
    }
}

extension Assignment {
    var formattedDueDate: String {
        guard let dueAt = dueAt else { return "No due date" }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: dueAt)
    }

    var isGraded: Bool {
        submission?.score != nil
    }

    var isSubmitted: Bool {
        submission?.submittedAt != nil
    }

    var isMissing: Bool {
        submission?.missing ?? false
    }

    var isLate: Bool {
        submission?.late ?? false
    }

    var isExcused: Bool {
        submission?.excused ?? false
    }

    var isLocked: Bool {
        lockedForUser ?? false
    }

    var isPublished: Bool {
        published ?? true
    }

    var percentageScore: Double? {
        guard let score = submission?.score,
              let possible = pointsPossible,
              possible > 0 else { return nil }
        return (score / possible) * 100
    }

    var submissionStatus: SubmissionStatus {
        if isExcused {
            return .excused
        } else if isMissing {
            return .missing
        } else if let submission = submission {
            if submission.score != nil {
                return .graded
            } else if submission.submittedAt != nil {
                return .submitted
            } else {
                return .notSubmitted
            }
        } else {
            return .notSubmitted
        }
    }

    var needsGrading: Bool {
        guard let submission = submission else { return false }
        return submission.submittedAt != nil && submission.score == nil && !isExcused
    }

    var hasZeroScore: Bool {
        guard let score = submission?.score else { return false }
        return score == 0.0
    }

    enum SubmissionStatus {
        case notSubmitted
        case submitted
        case graded
        case missing
        case excused
    }
}

extension Submission {
    var displayScore: String {
        if let grade = grade {
            return grade
        } else if let score = score {
            return String(format: "%.2f", score)
        }
        return "—"
    }

    var isGraded: Bool {
        score != nil || grade != nil
    }

    var isUngraded: Bool {
        submittedAt != nil && !isGraded && !(excused ?? false)
    }

    var hasDeductions: Bool {
        guard let deductions = pointsDeducted else { return false }
        return deductions > 0
    }

    var statusDescription: String {
        if excused == true {
            return "Excused"
        } else if missing == true {
            return "Missing"
        } else if late == true {
            return "Late"
        } else if isUngraded {
            return "Pending Grade"
        } else if isGraded {
            return "Graded"
        } else if submittedAt != nil {
            return "Submitted"
        } else {
            return "Not Submitted"
        }
    }

    var detailedStatusDescription: String? {
        var details: [String] = []

        if let status = latePolicyStatus, status != "none" {
            details.append("Late Policy: \(status.capitalized)")
        }

        if let deductions = pointsDeducted, deductions > 0 {
            details.append("Deducted: \(String(format: "%.1f", deductions)) pts")
        }

        if let seconds = secondsLate, seconds > 0 {
            let hours = seconds / 3600
            if hours > 24 {
                details.append("\(hours / 24) days late")
            } else if hours > 0 {
                details.append("\(hours) hours late")
            }
        }

        if gradeMatchesCurrentSubmission == false {
            details.append("Resubmitted - needs regrading")
        }

        if redoRequest == true {
            details.append("Redo requested")
        }

        return details.isEmpty ? nil : details.joined(separator: " • ")
    }
}

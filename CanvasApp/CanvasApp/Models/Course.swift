import SwiftUI
import Foundation

struct Course: Codable, Identifiable {
    let id: Int
    let name: String?
    let courseCode: String?
    let workflowState: String?
    let enrollments: [Enrollment]?
    let applyAssignmentGroupWeights: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, enrollments
        case courseCode = "course_code"
        case workflowState = "workflow_state"
        case applyAssignmentGroupWeights = "apply_assignment_group_weights"
    }

    var displayName: String {
        if let code = courseCode, let name = name {
            return "\(code) - \(name)"
        }
        return name ?? courseCode ?? "Untitled Course"
    }

    var currentGrade: String? {
        activeEnrollment?.computedCurrentGrade
    }

    var currentScore: Double? {
        activeEnrollment?.computedCurrentScore
    }

    private var activeEnrollment: Enrollment? {
        enrollments?.first { enrollment in
            enrollment.type.lowercased() == "student" &&
            enrollment.enrollmentState?.lowercased() == "active"
        }
    }
}

// MARK: - Enrollment Model
extension Course {
    struct Enrollment: Codable {
        // Core enrollment data
        let type: String
        let role: String
        let enrollmentState: String?

        // Grade information
        let computedCurrentGrade: String?
        let computedCurrentScore: Double?
        let computedFinalGrade: String?

        // Additional grade details
        let computedCurrentLetterGrade: String?
        let computedFinalScore: Double?

        enum CodingKeys: String, CodingKey {
            case type, role
            case enrollmentState = "enrollment_state"
            case computedCurrentGrade = "computed_current_grade"
            case computedCurrentScore = "computed_current_score"
            case computedFinalGrade = "computed_final_grade"
            case computedCurrentLetterGrade = "computed_current_letter_grade"
            case computedFinalScore = "computed_final_score"
        }

        // Modern computed properties
        var isStudent: Bool {
            type.lowercased() == "student"
        }

        var numericScore: Double? {
            computedCurrentScore
        }

        // Auto-generate letter grade if not provided by API
        var displayGrade: String? {
            if let grade = computedCurrentGrade {
                return grade
            } else if let score = computedCurrentScore {
                return letterGradeFromScore(score)
            }
            return nil
        }

        private func letterGradeFromScore(_ score: Double) -> String {
            switch score {
            case 97...100: return "A+"
            case 93..<97: return "A"
            case 90..<93: return "A-"
            case 87..<90: return "B+"
            case 83..<87: return "B"
            case 80..<83: return "B-"
            case 77..<80: return "C+"
            case 73..<77: return "C"
            case 70..<73: return "C-"
            case 67..<70: return "D+"
            case 63..<67: return "D"
            case 60..<63: return "D-"
            default: return "F"
            }
        }
    }
}

// MARK: - Modern Extensions
extension Course {
    var isActive: Bool {
        workflowState?.lowercased() == "available"
    }
    
    var hasGrades: Bool {
        currentGrade != nil || currentScore != nil
    }
}

extension Course.Enrollment {
    var formattedGrade: String {
        if let grade = displayGrade {
            return grade
        } else if let score = numericScore {
            return String(format: "%.1f%%", score)
        }
        return "No Grade"
    }
}

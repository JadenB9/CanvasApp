import SwiftUI

@MainActor
class CourseViewModel: ObservableObject {
    @Published var courses: [Course] = []
    @Published var assignments: [Int: [Assignment]] = [:]
    @Published var assignmentGroups: [Int: [AssignmentGroup]] = [:]
    @Published var grades: [Int: CourseGrades] = [:]
    @Published var courseLoadingStates: [Int: Bool] = [:]
    @Published var assignmentLoadingStates: [Int: Bool] = [:]
    @Published var errorMessage: String?

    private let apiClient: CanvasAPIClient
    private var courseDataTasks: [Int: Task<Void, Never>] = [:]

    init(apiClient: CanvasAPIClient) {
        self.apiClient = apiClient
    }
    
    func loadCourses() async {
        do {
            courses = try await apiClient.fetchCourses()
        } catch {
            handleError(error)
        }
    }
    
    private func handleError(_ error: Error) {
        if let apiError = error as? APIError {
            switch apiError {
            case .serverError(let code, _) where code == 403:
                errorMessage = "Access denied for some courses. This is normal for old/archived courses."
            case .serverError(let code, _) where code == 404:
                errorMessage = "Some courses not found. They may have been deleted or archived."
            default:
                errorMessage = error.localizedDescription
            }
        } else {
            errorMessage = error.localizedDescription
        }
    }
    
    func refreshCourseData(courseId: Int) async {
        courseLoadingStates[courseId] = true
        assignmentLoadingStates[courseId] = true

        do {
            async let assignmentsTask = apiClient.fetchAssignments(courseId: courseId)
            async let gradesTask = apiClient.fetchGrades(courseId: courseId)
            async let groupsTask = apiClient.fetchAssignmentGroups(courseId: courseId)

            let (assignments, grades, groups) = try await (assignmentsTask, gradesTask, groupsTask)

            await MainActor.run {
                self.assignments[courseId] = assignments.sorted {
                    if let date1 = $0.dueAt, let date2 = $1.dueAt {
                        return date1 > date2
                    }
                    return $0.dueAt != nil
                }
                self.grades[courseId] = grades
                self.assignmentGroups[courseId] = groups.sorted { $0.position < $1.position }
            }
        } catch {
            print("Error loading details for course \(courseId): \(error)")
        }

        await MainActor.run {
            courseLoadingStates[courseId] = false
            assignmentLoadingStates[courseId] = false
        }
    }
    
    func getCourseLoadingState(for courseId: Int) -> Bool {
        courseLoadingStates[courseId] ?? false
    }
    
    func getAssignmentLoadingState(for courseId: Int) -> Bool {
        assignmentLoadingStates[courseId] ?? false
    }

    func loadAllAssignments() async {
        // Get current semester courses
        let currentCourses = getCurrentSemesterCourses()

        // Load assignments for courses that haven't been loaded yet
        await withTaskGroup(of: Void.self) { group in
            for course in currentCourses {
                // Only load if we don't already have assignments for this course
                if assignments[course.id] == nil {
                    group.addTask {
                        await self.refreshCourseData(courseId: course.id)
                    }
                }
            }
        }
    }

    private func getCurrentSemesterCourses() -> [Course] {
        let currentDate = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: currentDate)
        let year = calendar.component(.year, from: currentDate)

        let currentSemesterCode: String
        if month >= 1 && month <= 5 {
            currentSemesterCode = "\(year)SP"
        } else if month >= 6 && month <= 8 {
            currentSemesterCode = "\(year)SU"
        } else {
            currentSemesterCode = "\(year)FA"
        }

        return courses.filter { course in
            guard let enrollments = course.enrollments else { return false }

            return enrollments.contains { enrollment in
                let meetsStudentCriteria = enrollment.type.lowercased() == "student"
                let isCurrentBySemester = course.name?.contains(currentSemesterCode) ?? false
                let isCurrentByDate = isCurrentSemesterCourseCheck(courseName: course.name ?? "", month: month, year: year)

                return meetsStudentCriteria && (isCurrentBySemester || isCurrentByDate)
            }
        }
    }

    private func isCurrentSemesterCourseCheck(courseName: String, month: Int, year: Int) -> Bool {
        let semesterName: String
        if month >= 9 && month <= 12 {
            semesterName = "Fall Semester \(year)"
        } else if month >= 1 && month <= 5 {
            semesterName = "Spring Semester \(year)"
        } else {
            semesterName = "Summer Semester \(year)"
        }

        return courseName.contains(semesterName)
    }
}

import Foundation

// MARK: - Course Array Extensions
import Foundation

// MARK: - Course Array Extensions
extension Array where Element == Course {
    var activeCourses: [Course] {
        filter { course in
            guard let enrollments = course.enrollments else { return false }
            return enrollments.contains { enrollment in
                enrollment.type.lowercased() == "student" &&
                (enrollment.enrollmentState ?? "").lowercased() == "active"
            }
        }
    }
    
    enum SortOption: String, CaseIterable {
        case name = "Name"
        case grade = "Grade"
        case recent = "Recent"
    }
    
    func sorted(by option: SortOption) -> [Course] {
        switch option {
        case .name:
            return sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .grade:
            return sorted { ($0.currentScore ?? 0) > ($1.currentScore ?? 0) }
        case .recent:
            return self
        }
    }
}

// MARK: - Optional Collection Extensions
extension Optional where Wrapped: Collection {
    var isNilOrEmpty: Bool {
        self?.isEmpty ?? true
    }
    
    var countOrZero: Int {
        self?.count ?? 0
    }
}

// MARK: - Collection Extensions
extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Array Extensions
extension Array {
    func limited(to limit: Int) -> ArraySlice<Element> {
        prefix(Swift.max(0, limit))
    }
}

// MARK: - Assignment Array Extensions
extension Array where Element == Assignment {
    var sortedByDueDate: [Assignment] {
        sorted { first, second in
            guard let date1 = first.dueAt, let date2 = second.dueAt else {
                return first.dueAt != nil
            }
            return date1 > date2
        }
    }
    
    var upcoming: [Assignment] {
        let now = Date()

        return filter { assignment in
            guard let dueDate = assignment.dueAt else {
                return false
            }
            return dueDate > now
        }
    }
    
    enum DueStatus: Hashable {
        case overdue
        case dueToday
        case upcoming
        case noDueDate
    }
    
    func groupedByDueStatus() -> [DueStatus: [Assignment]] {
        let now = Date()
        let calendar = Calendar.current

        return Dictionary(grouping: self) { assignment in
            guard let dueDate = assignment.dueAt else {
                return .noDueDate
            }

            if dueDate < now {
                return .overdue
            } else if calendar.isDate(dueDate, inSameDayAs: now) {
                return .dueToday
            } else {
                return .upcoming
            }
        }
    }
}

// MARK: - Modern Result Extensions
extension Result {
    /// Safely unwrap success value with a default
    func unwrapWithDefault(_ defaultValue: Success) -> Success {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return defaultValue
        }
    }
    
    /// Safe value access with proper error handling
    var valueOrNil: Success? {
        try? get()
    }
    
    /// Transform success value while preserving error
    func mapSuccess<NewSuccess>(_ transform: (Success) -> NewSuccess) -> Result<NewSuccess, Failure> {
        map(transform)
    }
    
    /// Chain multiple transformations
    func flatMapSuccess<NewSuccess>(_ transform: (Success) -> Result<NewSuccess, Failure>) -> Result<NewSuccess, Failure> {
        flatMap(transform)
    }
}

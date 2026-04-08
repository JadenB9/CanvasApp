import Foundation
import Network

// MARK: - Error Definitions
enum APIError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int, Data)
    case emptyResponse
    case noConnection
}

// MARK: - API Client Implementation
@MainActor
class CanvasAPIClient {
    private let baseURL: String
    private let token: String
    private let session: URLSession
    private let decoder: JSONDecoder
    
    init(baseURL: String, token: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
        self.decoder = JSONDecoder()

        // Don't use automatic snake_case conversion - we have manual CodingKeys
        // self.decoder.keyDecodingStrategy = .convertFromSnakeCase

        // Canvas uses ISO8601 dates - use flexible decoder
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try multiple ISO8601 formats
            let formatters: [ISO8601DateFormatter] = [
                {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    return f
                }(),
                {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withInternetDateTime]
                    return f
                }(),
                {
                    let f = ISO8601DateFormatter()
                    f.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
                    return f
                }(),
                ISO8601DateFormatter() // Default
            ]

            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    print("✅ Decoded date: \(dateString) -> \(date)")
                    return date
                }
            }

            print("❌ Failed to decode date: \(dateString)")
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string: \(dateString)")
        }

        print("🔐 API Client initialized with token: \(String(token.prefix(5)))...")
    }
    
    private func makeRequest(_ endpoint: String, queryItems: [URLQueryItem] = []) -> URLRequest {
        let cleanBaseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var components = URLComponents(string: "\(cleanBaseURL)/api/v1/\(endpoint)")!
        
        var allQueryItems = queryItems
        allQueryItems.append(URLQueryItem(name: "per_page", value: "100"))
        components.queryItems = allQueryItems
        
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        print("📡 Request URL: \(components.url!)")
        return request
    }
    
    func fetchCourses() async throws -> [Course] {
            let queryItems = [
                URLQueryItem(name: "include[]", value: "total_scores"),
                URLQueryItem(name: "include[]", value: "current_grading_period_scores"),
                URLQueryItem(name: "state[]", value: "available"),

            ]
            let request = makeRequest("courses", queryItems: queryItems)
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(NSError(domain: "HTTPResponse", code: -1))
            }
            
            if let responseStr = String(data: data, encoding: .utf8) {
                print("📄 Courses Response: \(responseStr)")
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError(httpResponse.statusCode, data)
            }
            
            return try decoder.decode([Course].self, from: data)
        }
        
        func fetchAssignments(courseId: Int) async throws -> [Assignment] {
            let queryItems = [
                // Include submission details with all fields
                URLQueryItem(name: "include[]", value: "submission"),

                // Include score statistics for context
                URLQueryItem(name: "include[]", value: "score_statistics"),

                // Include all dates (including overrides)
                URLQueryItem(name: "include[]", value: "all_dates"),

                // Include visibility information
                URLQueryItem(name: "include[]", value: "can_edit"),

                // Pagination
                URLQueryItem(name: "per_page", value: "100"),

                // Order by due date
                URLQueryItem(name: "order_by", value: "due_at")
            ]
            let request = makeRequest("courses/\(courseId)/assignments", queryItems: queryItems)
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(NSError(domain: "HTTPResponse", code: -1))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError(httpResponse.statusCode, data)
            }

            // Parse as JSON to see structure
            if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                print("📄 Raw JSON structure for first assignment:")
                if let first = json.first {
                    print("Available keys: \(first.keys.joined(separator: ", "))")
                    print("due_at: \(first["due_at"] ?? "missing")")
                    print("points_possible: \(first["points_possible"] ?? "missing")")
                    if let submission = first["submission"] as? [String: Any] {
                        print("Submission keys: \(submission.keys.joined(separator: ", "))")
                    }
                }
            }

            let assignments = try decoder.decode([Assignment].self, from: data)

            // Debug: Print parsed assignment details
            print("\n🔍 Parsed \(assignments.count) assignments")
            for assignment in assignments.prefix(5) {
                print("\n📝 Assignment: \(assignment.name)")
                print("   ID: \(assignment.id)")
                print("   Due: \(assignment.dueAt?.description ?? "❌ nil")")
                print("   Points Possible: \(assignment.pointsPossible?.description ?? "❌ nil")")
                print("   Submission: \(assignment.submission != nil ? "✅ Yes" : "❌ No")")
                if let submission = assignment.submission {
                    print("   Score: \(submission.score?.description ?? "nil")")
                    print("   Grade: \(submission.grade ?? "nil")")
                    print("   Submitted At: \(submission.submittedAt?.description ?? "nil")")
                    print("   Workflow: \(submission.workflowState ?? "nil")")
                }
            }
            print("")

            return assignments
        }

        func fetchAssignmentGroups(courseId: Int) async throws -> [AssignmentGroup] {
            let request = makeRequest("courses/\(courseId)/assignment_groups")
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(NSError(domain: "HTTPResponse", code: -1))
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.serverError(httpResponse.statusCode, data)
            }

            return try decoder.decode([AssignmentGroup].self, from: data)
        }
    
    func fetchGrades(courseId: Int) async throws -> CourseGrades {
        let queryItems = [
            URLQueryItem(name: "include[]", value: "total_scores"),
            URLQueryItem(name: "include[]", value: "current_grading_period_scores")
        ]
        let request = makeRequest("courses/\(courseId)", queryItems: queryItems)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "HTTPResponse", code: -1))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode, data)
        }

        if let responseStr = String(data: data, encoding: .utf8) {
            print("📄 Grades Response: \(responseStr)")
        }

        // Decode the full course object to access enrollment grades
        let course = try decoder.decode(Course.self, from: data)

        // Extract grades from the student enrollment
        let studentEnrollment = course.enrollments?.first { $0.isStudent }

        return CourseGrades(
            currentGrade: studentEnrollment?.computedCurrentGrade,
            finalGrade: studentEnrollment?.computedFinalGrade,
            currentScore: studentEnrollment?.computedCurrentScore
        )
    }
}

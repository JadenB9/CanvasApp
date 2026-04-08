import SwiftUI

// MARK: - Persistent Storage
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

// MARK: - Course Preferences Manager
@MainActor
final class CoursePreferences: ObservableObject {
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

struct CustomizableCourseCard: View {
    let course: Course
    @StateObject private var preferences = CoursePreferences()
    @State private var isEditingName = false
    @State private var customName = ""

    private var displayName: String {
        preferences.customNames[course.id] ?? course.name ?? "Untitled Course"
    }

    var body: some View {
        VStack(spacing: 0) {
            courseHeader
            courseMeta
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        }
        .shadow(color: Color.primary.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .sheet(isPresented: $isEditingName) {
            NavigationStack {
                NameEditorView(
                    customName: $customName,
                    isPresented: $isEditingName
                ) {
                    preferences.setCustomName(customName.isEmpty ? nil : customName, for: course.id)
                }
                .preferredColorScheme(.dark)
            }
        }
    }

    private var courseHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                if let code = course.courseCode {
                    Text(code)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                customName = displayName
                isEditingName = true
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
    }

    private var courseMeta: some View {
        HStack(spacing: 20) {
            gradeSection
            Spacer()
        }
        .padding(.top, 8)
    }

    private var gradeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let enrollment = course.enrollments?.first(where: { $0.type.lowercased() == "student" }) {
                // Show letter grade (auto-generated if not provided by API)
                if let grade = enrollment.displayGrade, !grade.isEmpty {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(gradeColor(for: enrollment.computedCurrentScore ?? 0))
                            .frame(width: 10, height: 10)

                        Text(grade)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(gradeColor(for: enrollment.computedCurrentScore ?? 0))
                    }
                }

                // Always show percentage if available
                if let score = enrollment.computedCurrentScore {
                    Text(String(format: "%.1f%%", score))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // If no grade at all
                if enrollment.displayGrade == nil && enrollment.computedCurrentScore == nil {
                    Text("No Grade")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No Grade")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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

// MARK: - Supporting Views
struct NameEditorView: View {
    @Binding var customName: String
    @Binding var isPresented: Bool
    let onSave: () -> Void

    var body: some View {
        Form {
            Section {
                TextField("Enter custom name", text: $customName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
            } header: {
                Text("Custom Course Name")
            } footer: {
                Text("This name will be displayed instead of the default course name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Edit Course Name")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isPresented = false
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave()
                    isPresented = false
                }
                .fontWeight(.semibold)
            }
        }
    }
}

struct CourseStatusView: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .imageScale(.small)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: CourseViewModel
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedSortOption: SortOption = .grade
    @State private var showAllCourses = false
    @State private var selectedTab = 0
    @State private var isShowingCourseDetail = false

    enum SortOption: String, CaseIterable {
        case name = "Name"
        case grade = "Grade"
        case recent = "Recently Updated"

        var icon: String {
            switch self {
            case .name: return "textformat"
            case .grade: return "percent"
            case .recent: return "clock"
            }
        }
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                coursesView
                    .tag(0)

                todoView
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Custom Page Indicator - only on main pages
            if !isShowingCourseDetail {
                VStack {
                    Spacer()

                    HStack(spacing: 20) {
                        PageIndicatorButton(
                            icon: "list.bullet.rectangle.portrait",
                            title: "Courses",
                            isSelected: selectedTab == 0
                        ) {
                            withAnimation {
                                selectedTab = 0
                            }
                        }

                        PageIndicatorButton(
                            icon: "checklist",
                            title: "To-Do",
                            isSelected: selectedTab == 1
                        ) {
                            withAnimation {
                                selectedTab = 1
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.1), radius: 10)
                    .padding(.bottom, 20)
                }
                .allowsHitTesting(true)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var coursesView: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.courses.isEmpty {
                    ProgressView("Loading courses...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    courseList
                }
            }
            .navigationTitle("My Courses")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Sort by", selection: $selectedSortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Label(option.rawValue, systemImage: option.icon)
                                    .tag(option)
                            }
                        }

                        Toggle("Show All Courses", isOn: $showAllCourses)

                        Divider()

                        Button(role: .destructive) {
                            authManager.logout()
                        } label: {
                            Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Label("Options", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .task {
                // Only load courses once on initial view
                if viewModel.courses.isEmpty {
                    await viewModel.loadCourses()
                }
            }
            .refreshable {
                await viewModel.loadCourses()
            }
        }
    }

    private var todoView: some View {
        TodoListView(viewModel: viewModel)
    }

    private var courseList: some View {
        List {
            ForEach(filteredCourses) { course in
                NavigationLink {
                    CourseDetailView(course: course, viewModel: viewModel)
                        .onAppear {
                            withAnimation {
                                isShowingCourseDetail = true
                            }
                        }
                        .onDisappear {
                            withAnimation {
                                isShowingCourseDetail = false
                            }
                        }
                } label: {
                    CustomizableCourseCard(course: course)
                }
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }

            // Add bottom padding so content doesn't hide behind tab bar
            Color.clear
                .frame(height: 100)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .overlay {
            if filteredCourses.isEmpty {
                ContentUnavailableView {
                    Label(showAllCourses ? "No Courses Found" : "No Current Courses",
                          systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text(showAllCourses ? "Check back later for updates" :
                         "Toggle the option to view all courses")
                }
            }
        }
    }
    
    private var filteredCourses: [Course] {
        let courses = viewModel.courses
        
        let filteredCourses = showAllCourses ? courses : courses.filter { course in
            guard let enrollments = course.enrollments else { return false }
            
            return enrollments.contains { enrollment in
                let meetsStudentCriteria = enrollment.type.lowercased() == "student"
                let isCurrentBySemester = course.name?.contains(getCurrentSemesterCode()) ?? false
                let isCurrentByDate = isCurrentSemesterCourse(courseName: course.name ?? "")
                
                return meetsStudentCriteria && (isCurrentBySemester || isCurrentByDate)
            }
        }
        
        switch selectedSortOption {
        case .name:
            return filteredCourses.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .grade:
            return filteredCourses.sorted { ($0.currentScore ?? 0) > ($1.currentScore ?? 0) }
        case .recent:
            return filteredCourses
        }
    }
    
    private func getCurrentSemesterCode() -> String {
        let currentDate = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: currentDate)
        let year = calendar.component(.year, from: currentDate)

        if month >= 1 && month <= 5 {
            return "\(year)SP"
        } else if month >= 6 && month <= 8 {
            return "\(year)SU"
        } else {
            return "\(year)FA"
        }
    }

    private func isCurrentSemesterCourse(courseName: String) -> Bool {
        let currentSemesterCode = getCurrentSemesterCode()
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())

        // Check for standard format like "2025FA", "2025SP"
        if courseName.contains(currentSemesterCode) {
            return true
        }

        // Check for alternative formats like "Fall Semester 2025", "Spring Semester 2025"
        let semesterName: String
        if currentMonth >= 9 && currentMonth <= 12 {
            semesterName = "Fall Semester \(currentYear)"
        } else if currentMonth >= 1 && currentMonth <= 5 {
            semesterName = "Spring Semester \(currentYear)"
        } else {
            semesterName = "Summer Semester \(currentYear)"
        }

        if courseName.contains(semesterName) {
            return true
        }

        return false
    }
}

// MARK: - Page Indicator Button
struct PageIndicatorButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.caption.bold())
            }
            .foregroundColor(isSelected ? .blue : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .cornerRadius(12)
        }
    }
}

import SwiftUI

// change this if you go to a different school
let canvasBaseURL = "https://cedarville.instructure.com"

@main
struct CanvasApp: App {
    @StateObject private var authManager = AuthenticationManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoading {
                    LoadingView()
                } else if authManager.isAuthenticated {
                    ContentView(
                        viewModel: CourseViewModel(
                            apiClient: CanvasAPIClient(
                                baseURL: canvasBaseURL,
                                token: authManager.getCurrentToken() ?? ""
                            )
                        )
                    )
                    .environmentObject(authManager)
                } else {
                    CanvasLoginView()
                        .environmentObject(authManager)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
            Text("Connecting to Canvas...")
                .foregroundColor(.secondary)
        }
    }
}

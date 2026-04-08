import SwiftUI

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
                                baseURL: "https://cedarville.instructure.com",
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

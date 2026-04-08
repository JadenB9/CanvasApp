import SwiftUI
import Foundation

@MainActor
class AuthenticationManager: ObservableObject {
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var authenticationError: String? = nil
    @Published private(set) var isLoading: Bool = false
    
    private let keychain: KeychainManager
    
    private lazy var apiClient: CanvasAPIClient = {
        CanvasAPIClient(
            baseURL: "https://cedarville.instructure.com",
            token: keychain.retrieveToken() ?? ""
        )
    }()
    
    init(keychain: KeychainManager = KeychainManager()) {
        self.keychain = keychain
        
        Task {
            await validateToken()
        }
    }
    
    func resetAuthenticationError() {
        authenticationError = nil
    }
    
    func getCurrentToken() -> String? {
        keychain.retrieveToken()
    }
    
    func login(token: String) {
        guard !token.isEmpty else {
            authenticationError = "Token cannot be empty"
            return
        }
        
        print("🔑 Starting login with token: \(String(token.prefix(5)))...")
        isLoading = true
        
        Task {
            do {
                let tempClient = CanvasAPIClient(
                    baseURL: "https://cedarville.instructure.com",
                    token: token
                )
                
                print("🔄 Validating token...")
                let courses = try await tempClient.fetchCourses()
                print("✅ Token validated successfully - found \(courses.count) courses")
                
                keychain.saveToken(token)
                await updateAuthenticationState(isAuthenticated: true, clearError: true)
            } catch let error as APIError {
                print("❌ Login failed with error: \(error)")
                switch error {
                case .serverError(let statusCode, _):
                    if statusCode == 401 {
                        authenticationError = "Invalid API token. Please check and try again."
                    } else {
                        authenticationError = "Server error (HTTP \(statusCode)). Please try again."
                    }
                case .networkError(_):
                    authenticationError = "Network error. Please check your internet connection."
                case .invalidURL:
                    authenticationError = "Invalid Canvas URL configuration."
                case .decodingError(_):
                    authenticationError = "Error processing server response."
                case .emptyResponse:
                    authenticationError = "No response from server."
                case .noConnection:
                    authenticationError = "FAILED"
                }
                keychain.deleteToken()
                await updateAuthenticationState(isAuthenticated: false)
            } catch {
                print("❌ Unexpected error: \(error)")
                authenticationError = "An unexpected error occurred. Please try again."
                keychain.deleteToken()
                await updateAuthenticationState(isAuthenticated: false)
            }
            isLoading = false
        }
    }
    
    func validateToken() async {
        print("🔄 Validating existing token...")
        guard keychain.retrieveToken() != nil else {
            print("❌ No token found")
            await updateAuthenticationState(isAuthenticated: false)
            return
        }
        
        do {
            _ = try await apiClient.fetchCourses()
            print("✅ Token validation successful")
            await updateAuthenticationState(isAuthenticated: true)
        } catch {
            print("❌ Token validation failed: \(error)")
            await handleAuthenticationError(error)
        }
    }
    
    private func updateAuthenticationState(
        isAuthenticated: Bool,
        clearError: Bool = false
    ) async {
        self.isAuthenticated = isAuthenticated
        if clearError {
            self.authenticationError = nil
        }
    }
    
    private func handleAuthenticationError(_ error: Error) async {
        let errorMessage: String
        
        if let apiError = error as? APIError {
            switch apiError {
            case .serverError(let statusCode, _) where statusCode == 401:
                errorMessage = "Invalid API token. Please check and re-enter your token."
                keychain.deleteToken()
            case .networkError:
                errorMessage = "Network error. Please check your internet connection."
            default:
                errorMessage = "Authentication failed. Please try again."
            }
        } else {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
        
        await MainActor.run {
            self.isAuthenticated = false
            self.authenticationError = errorMessage
        }
    }
    
    func logout() {
        Task {
            keychain.deleteToken()
            await updateAuthenticationState(isAuthenticated: false, clearError: true)
        }
    }
}

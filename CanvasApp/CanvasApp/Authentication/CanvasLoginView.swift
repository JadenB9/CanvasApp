import SwiftUI

struct CanvasLoginView: View {
    @State private var apiToken: String = ""
    @State private var isTokenValid = false
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                headerContent
                
                VStack(spacing: 16) {
                    institutionSection
                    tokenInputSection
                }
                .padding(.horizontal)
                
                if let error = authManager.authenticationError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                connectionButton
            }
            .animation(.default, value: authManager.isLoading)
            .navigationTitle("Canvas Connection")
            .navigationBarTitleDisplayMode(.inline)
            .disabled(authManager.isLoading)
            .overlay {
                if authManager.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
    }
    
    private var headerContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "graduationcap.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
            
            Text("Canvas LMS Login")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Connect your Cedarville Canvas account")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }
    
    private var institutionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Institution")
                .font(.headline)
            
            TextField("Canvas Instance", text: .constant("Cedarville University"))
                .textFieldStyle(.roundedBorder)
                .disabled(true)
        }
    }
    
    private var tokenInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Canvas API Token")
                .font(.headline)
            
            SecureField("Paste your API token", text: $apiToken)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .disabled(authManager.isLoading)
            
            Text("Find your token in Canvas Account Settings")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var connectionButton: some View {
        Button(action: validateToken) {
            Text("Connect to Canvas")
                .frame(maxWidth: .infinity)
                .padding()
                .background(apiToken.isEmpty ? Color.gray.opacity(0.5) : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .disabled(apiToken.isEmpty || authManager.isLoading)
        .padding(.horizontal)
    }
    
    private func validateToken() {
        guard !apiToken.isEmpty else { return }
        authManager.login(token: apiToken)
    }
}

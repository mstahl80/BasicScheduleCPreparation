// SignInWithAppleButton.swift
import SwiftUI
import AuthenticationServices

struct SignInWithAppleButton: View {
    @ObservedObject var authManager = UserAuthManager.shared
    
    var body: some View {
        Button(action: {
            authManager.signInWithApple()
        }) {
            HStack {
                Image(systemName: "apple.logo")
                    .font(.title2)
                Text("Sign in with Apple")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding(.horizontal)
    }
}

#if DEBUG
struct SignInWithAppleButton_Previews: PreviewProvider {
    static var previews: some View {
        SignInWithAppleButton()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
#endif

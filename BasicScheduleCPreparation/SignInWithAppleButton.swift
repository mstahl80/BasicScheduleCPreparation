// SignInWithAppleButton.swift
import SwiftUI
import AuthenticationServices

struct SignInWithAppleButton: View {
    @State private var isSigningIn = false
    
    var body: some View {
        Button(action: {
            isSigningIn = true
            AuthAccess.signInWithApple()
            isSigningIn = false
        }) {
            HStack {
                if isSigningIn {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "apple.logo")
                        .font(.title2)
                }
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

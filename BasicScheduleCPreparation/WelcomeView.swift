// WelcomeView.swift - Initial onboarding screen emphasizing standalone mode
import SwiftUI

struct WelcomeView: View {
    @State private var showMainApp = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // App logo
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.blue)
                    .padding()
                
                // Welcome title
                Text("Welcome to\nBasicScheduleCPreparation")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                // App description
                Text("Track your business income and expenses easily. Perfect for freelancers and small business owners.")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                // Standalone mode card
                VStack(alignment: .leading, spacing: 15) {
                    Text("Standalone Mode (Default)")
                        .font(.headline)
                    
                    Text("Your data stays on this device. No sign-in required. Perfect for personal use.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        Text("Immediately ready to use")
                            .font(.subheadline)
                    }
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        Text("No Apple ID required")
                            .font(.subheadline)
                    }
                    
                    Text("You can enable data sharing later in your User Profile if needed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Optional shared mode info
                VStack(alignment: .leading, spacing: 10) {
                    Text("Data Sharing (Optional)")
                        .font(.headline)
                    
                    Text("Share data across devices or with team members using your Apple ID.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "cloud.fill")
                            .foregroundColor(.blue)
                        
                        Text("Available in User Profile settings")
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                
                Spacer()
                
                // Get started button
                Button {
                    showMainApp = true
                } label: {
                    Text("Get Started")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding()
            .navigationDestination(isPresented: $showMainApp) {
                ScheduleListView()
            }
            .navigationBarHidden(true)
        }
    }
}

#if DEBUG
struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
    }
}
#endif

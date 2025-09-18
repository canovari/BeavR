import SwiftUI

struct SubmissionConfirmationView: View {
    var onDone: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Your post has been submitted!")
                .font(.title2)
                .bold()
            
            Text("Our team will review your post within 24 hours. If your submission is urgent, send us an email at:")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Text("support@campusnow.com") // replace with your email
                .foregroundColor(Color("LSERed"))
                .bold()
            
            Button(action: { onDone() }) {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("LSERed"))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

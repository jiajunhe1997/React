import SwiftUI

struct LoadingView: View {
    var message: String
    
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            Text(message)
                .foregroundColor(.white)
                .padding(.top, 8)
                .font(.body) // Use dynamic type
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(message))
    }
}

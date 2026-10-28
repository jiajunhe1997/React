
import SwiftUI

struct ToastView: View {
    var message: String
    
    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .padding(10)
                .background(Color.black.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.bottom, 120)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(message))
    }
}

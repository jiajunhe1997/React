// CustomButtonView.swift

import SwiftUI

struct CategoryButtonView: View {
    var text: String
    var isSelected: Bool = false
    var action: () -> Void
    
    var body: some View {
        Button(action: {
            // Haptic Feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            action()
        }) {
            Text(text)
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
                .frame(height: 40)
        }
        .accessibilityLabel(Text(text))
    }
}

// MARK: - Preview

struct CustomButtonView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview for a selected button
            CategoryButtonView(text: "Selected Button", isSelected: true, action: {
                print("Selected Button Tapped")
            })
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Selected State")
            
            // Preview for an unselected button
            CategoryButtonView(text: "Unselected Button", isSelected: false, action: {
                print("Unselected Button Tapped")
            })
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Unselected State")
        }
    }
}

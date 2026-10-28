import SwiftUI

// View when longpress on images
struct LongPressImageView: View {
    let image: UIImage
    let isInTrash: Bool
    let onCopy: () -> Void
    let onReplace: () -> Void
    let onDelete: () -> Void
    
    @State private var isTapped = false
    @State private var isZoomed = false
    
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .overlay(
                Rectangle()
                    .fill(Color.black.opacity(isTapped ? 0.3 : 0))
            )
            .frame(width: 170, height: 170)
            .shadow(radius: 5)
            .clipped()
            .onTapGesture {
                // Haptic Feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                withAnimation(.easeInOut(duration: 0.2)) {
                    isTapped = true
                }
                // Delay to reset the tap state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isTapped = false
                    }
                }
                
                onCopy()
            }
            .contextMenu {
                if !isInTrash {
                    Button(action: onReplace) {
                        Label(NSLocalizedString("Replace", comment: "Replace picture with new one"), systemImage: "photo")
                    }
                }
                Button(action: onDelete) {
                    Label(
                        isInTrash ? NSLocalizedString("Delete Permanently", comment: "Permanently delete from trash") : NSLocalizedString("Delete", comment: "Delete image from board"),
                        systemImage: "trash"
                    )
                }
                // Add Zoom Option
                Button(action: {
                    withAnimation {
                        isZoomed = true
                    }
                }) {
                    Label(NSLocalizedString("Zoom", comment: "Zoom into the image"), systemImage: "magnifyingglass")
                }
            }
            .accessibilityLabel(Text("Image"))
            .fullScreenCover(isPresented: $isZoomed) {
                ZoomedImageView(image: image, isPresented: $isZoomed)
            }
    }
}

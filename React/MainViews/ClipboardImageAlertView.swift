import SwiftUI


struct ClipboardImageAlertView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        VStack {
            Text(NSLocalizedString("Add Image", comment: "Paste to Clipboard alert"))
                .font(.headline)
                .padding()

            if let image = viewModel.clipboardImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .padding()
            }

            Text(NSLocalizedString("Would you like to add the copied image to a board?", comment: "Paste to Clipboard alert"))
                .padding()
                .frame(alignment: .center)

            HStack {
                Button(NSLocalizedString("Cancel", comment: "Paste to Clipboard alert")) {
                    viewModel.showCustomClipboardAlert = false
                    viewModel.clipboardImage = nil
                }
                .padding()

                Spacer()

                Button(NSLocalizedString("Add", comment: "Paste to Clipboard alert")) {
                    viewModel.showCustomClipboardAlert = false
                    viewModel.showCategorySelection = true
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .padding()
        .shadow(radius: 10)
        .frame(width: 300)
    }
}

struct ClipboardImageAlertView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample ContentViewModel with the required StoreManager instance
        let viewModel = ContentViewModel(storeManager: StoreManager.shared)

        // Set a sample image for the clipboardImage
        viewModel.clipboardImage = UIImage(named: "AppIcon") // Replace "sampleImage" with an actual image name from your Assets

        // Set the showCustomClipboardAlert to true to display the alert
        viewModel.showCustomClipboardAlert = true

        return ClipboardImageAlertView(viewModel: viewModel)
            .previewLayout(.sizeThatFits)
    }
}

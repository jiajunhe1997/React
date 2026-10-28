import SwiftUI

struct GridView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        ScrollView {
            LazyVGrid(columns: viewModel.columns, spacing: 16) {
                if viewModel.categories.indices.contains(viewModel.selectedCategoryIndex) {
                    let currentCategory = viewModel.categories[viewModel.selectedCategoryIndex]
                    ForEach(currentCategory.imagePaths.indices, id: \.self) { index in
                        if let image = viewModel.loadImage(from: currentCategory.imagePaths[index]) {
                            LongPressImageView(
                                image: image,
                                isInTrash: currentCategory.isTrash,
                                onCopy: {
                                    viewModel.copyImageToClipboard(currentCategory.imagePaths[index])
                                },
                                onReplace: {
                                    viewModel.selectedImageIndex = index
                                    viewModel.isImagePickerPresented = true
                                },
                                onDelete: {
                                    if currentCategory.isTrash {
                                        // Permanently delete the image
                                        viewModel.deleteImagePermanently(at: index)
                                    } else {
                                        viewModel.deleteImage(at: index)
                                    }
                                }
                            )
                        }
                    }
                    // Add image button (not shown in Trash)
                    if !currentCategory.isTrash {
                        if currentCategory.imagePaths.count < viewModel.maxImagesPerCategory || viewModel.isFullVersionPurchased {
                            PlusButtonView {
                                viewModel.selectedImageIndex = viewModel.categories[viewModel.selectedCategoryIndex].imagePaths.count
                                viewModel.isImagePickerPresented = true
                            }
                        } else {
                            Button(action: {
                                viewModel.showPurchasePrompt = true  // Trigger the purchase prompt when tapped
                            }) {
                                Text(NSLocalizedString("Upgrade to add more images", comment: ""))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)  // Indicate it's tappable
                                    .padding()
                            }
                            .buttonStyle(PlainButtonStyle())  // Make it look like regular text
                        }
                    }
                }
            }
            .padding()
        }
    }
}

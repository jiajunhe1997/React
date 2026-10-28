import SwiftUI

struct CategoryButtonsView: View {
    @ObservedObject var viewModel: ContentViewModel
    @Binding var isShowingPictoBrowse: Bool
    @Binding var isShowingAudioBoard: Bool
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                
                //MARK: Discover
                CategoryButtonView(
                    text: NSLocalizedString("Discover", comment: ""),
                    isSelected: isShowingPictoBrowse
                ) {
                    withAnimation {
                        isShowingPictoBrowse = true
                        isShowingAudioBoard = false // Deselect AudioBoard
                        viewModel.selectedCategoryIndex = -1
                    }
                }
                
                //MARK: Soun
                CategoryButtonView(
                    text: NSLocalizedString("♬", comment: ""),
                    isSelected: isShowingAudioBoard
                ) {
                    withAnimation {
                        isShowingAudioBoard = true
                        isShowingPictoBrowse = false // Deselect PictoBrowse
                        viewModel.selectedCategoryIndex = -2 // Assign index for AudioBoard
                    }
                }
                
                //MARK: Regular
                ForEach(viewModel.categories.indices, id: \.self) { index in
                    if !viewModel.categories[index].isTrash {
                        CategoryButtonView(
                            text: viewModel.categories[index].name,
                            isSelected: viewModel.selectedCategoryIndex == index
                        ) {
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            withAnimation {
                                viewModel.selectedCategoryIndex = index
                                isShowingPictoBrowse = false // Deselect PictoBrowse
                                isShowingAudioBoard = false // Deselect AudioBoard
                            }
                        }
                    }
                }
                
                //MARK: Add Board Button
                if viewModel.categories.filter({ !$0.isTrash }).count < viewModel.maxCategories || viewModel.isFullVersionPurchased {
                    CategoryButtonView(text: "+") {
                        withAnimation {
                            viewModel.addNewCategory()
                        }
                    }
                } else {
                    Button(action: {
                        viewModel.showPurchasePrompt = true  // Trigger the purchase prompt when tapped
                    }) {
                        Text(NSLocalizedString("Upgrade to add more boards", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(.gray)  // Indicate it's tappable
                    }
                    .buttonStyle(PlainButtonStyle())  // Make it look like regular text
                }
                
                //MARK: Trash Button
                if let trashIndex = viewModel.categories.firstIndex(where: { $0.isTrash }) {
                    CategoryButtonView(
                        text: NSLocalizedString("Trash", comment: ""),
                        isSelected: viewModel.selectedCategoryIndex == trashIndex
                    ) {
                        // Haptic Feedback
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        withAnimation {
                            viewModel.selectedCategoryIndex = trashIndex
                            isShowingPictoBrowse = false // Show ImageGridView when Trash is selected
                        }
                    }
                }
            }
            .padding()
        }
        .onAppear {
            // If Discover or Sounds was selected when app closed, select first non-trash category
            if viewModel.selectedCategoryIndex == -1 || viewModel.selectedCategoryIndex == -2 {
                if let firstNonTrashIndex = viewModel.categories.firstIndex(where: { !$0.isTrash }) {
                    withAnimation {
                        viewModel.selectedCategoryIndex = firstNonTrashIndex
                        isShowingPictoBrowse = false
                        isShowingAudioBoard = false
                    }
                }
            }
        }
    }
}

struct CategoryButtonsView_Previews: PreviewProvider {
    static var previews: some View {
        CategoryButtonsView(
            viewModel: ContentViewModel(storeManager: StoreManager.shared),
            isShowingPictoBrowse: .constant(false),
            isShowingAudioBoard: .constant(false)
        )
    }
}

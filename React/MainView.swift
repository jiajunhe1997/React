import SwiftUI
import PhotosUI
import Combine
import StoreKit
import UIKit


extension Collection {
    func element(at index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - ContentView
struct ContentView: View {
    @EnvironmentObject var storeManager: StoreManager
    @StateObject private var viewModel: ContentViewModel
    @Environment(\.scenePhase) var scenePhase
    @State private var isShowingPictoBrowse = false
    @State private var isShowingAudioBoard = false
    @State private var adDidLoad = false
    @State private var adHeight: CGFloat = 0
    @State private var shouldShowTutorial: Bool = UserDefaults.standard.object(forKey: "shouldShowTutorial") as? Bool ?? true
    
    init() {
        _viewModel = StateObject(wrappedValue: ContentViewModel(storeManager: StoreManager.shared))
    }
    
    
    
    var body: some View {
        ZStack {
            if shouldShowTutorial {
                TutorialView(shouldShowTutorial: $shouldShowTutorial)
            }
            else {
                VStack {
                    headerView
                    
                    //MARK: Browse or Grid
                    if isShowingPictoBrowse {
                        DiscoverView() // Show PictoBrowse
                            .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    } else if isShowingAudioBoard {
                        AudioBoardView(viewModel: viewModel.audioViewModel) // Show AudioBoard
                            .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing)))
                    } else {
                        GridView(viewModel: viewModel) // Show the default GridView
                            .transition(.slide)
                    }
                    Spacer()
                    
                    CategoryButtonsView(
                        viewModel: viewModel,
                        isShowingPictoBrowse: $isShowingPictoBrowse,
                        isShowingAudioBoard: $isShowingAudioBoard
                    )
                    
                    //MARK: Ads or ProBanner
                    if !viewModel.isFullVersionPurchased {
                        ZStack {
                            // Always instantiate AdBannerView to load the ad
                            AdBannerView(adDidLoad: $adDidLoad, adHeight: $adHeight)
                                .frame(height: adDidLoad ? adHeight : 0)
                                .opacity(adDidLoad ? 1 : 0)
                                .animation(.easeInOut, value: adDidLoad)
                            
                            // Show ProBannerView when adDidLoad is false
                            if !adDidLoad {
                                proBannerView
                                    .frame(height: 50)
                                    .transition(.opacity)
                                    .animation(.easeInOut, value: adDidLoad)
                            }
                        }
                    }
                }
            }
            if viewModel.isLoading {
                LoadingView(message: viewModel.loadingMessage)
            }
            if viewModel.showToast {
                ToastView(message: viewModel.toastMessage)
            }
            if viewModel.showCustomClipboardAlert {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)

                ClipboardImageAlertView(viewModel: viewModel)
            }  
        }
        .fullScreenCover(isPresented: $shouldShowTutorial, content: {
                    TutorialView(shouldShowTutorial: $shouldShowTutorial)
                })
        .sheet(isPresented: $viewModel.isImagePickerPresented) {
            PhotoPicker(isFullVersionPurchased: viewModel.isFullVersionPurchased) { images in
                // Determine available space for free users
                let currentCategory = viewModel.categories[viewModel.selectedCategoryIndex]
                let availableSpace = viewModel.maxImagesPerCategory - currentCategory.imagePaths.count
                
                if !viewModel.isFullVersionPurchased && images.count > availableSpace {
                    viewModel.showToastMessage(NSLocalizedString("Upgrade to add more pictures.", comment: ""))
                    return
                }
                
                // Add selected images to the category
                for image in images {
                    viewModel.saveImage(image) { imagePath in
                        guard let imagePath = imagePath else {
                            viewModel.showToastMessage(NSLocalizedString("Failed to save image.", comment: ""))
                            return
                        }
                        withAnimation {
                            viewModel.categories[viewModel.selectedCategoryIndex].imagePaths.append(imagePath)
                            viewModel.categories[viewModel.selectedCategoryIndex].lastModified = Date() // Update the timestamp
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.isRenameModalPresented) {
            if let categoryToRenameIndex = viewModel.categoryToRenameIndex {
                RenameCategoryModal(
                    newCategoryName: $viewModel.newCategoryName,
                    onSave: {
                        guard viewModel.categories.indices.contains(categoryToRenameIndex) else {
                            viewModel.showToastMessage(NSLocalizedString("Invalid board selected.", comment: ""))
                            return
                        }
                        viewModel.renameCategory(at: categoryToRenameIndex, to: viewModel.newCategoryName)
                    }
                )
            }
        }
        
        .sheet(isPresented: $viewModel.isReorderCategoriesPresented) {
            ReorderCategoriesView(viewModel: viewModel)
        }
        
        .sheet(isPresented: $viewModel.isStorageUsagePresented) {
            StorageUsageView(viewModel: viewModel)
        }
        .alert(isPresented: $viewModel.showPurchasePrompt) {
            Alert(
                title: Text(NSLocalizedString("Upgrade to Pro", comment: "In Purchase Prompt")),
                message: Text(NSLocalizedString("Unlock unlimited boards, unlimited pictures, and iCloud backup!", comment: "In Purchase Prompt")),
                primaryButton: .default(Text(NSLocalizedString("Unlock", comment: "In Purchase Prompt"))) {
                    viewModel.purchaseFullVersion()
                },
                secondaryButton: .cancel()
            )
        }
        // Clipboard Paste
        .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        viewModel.checkClipboardForImage()
                        viewModel.loadCategories()
                    }
                }
                .alert(isPresented: $viewModel.showClipboardImageAlert) {
                    Alert(
                        title: Text(NSLocalizedString("Add Image", comment: "Clipboard Paste")),
                        message: Text(NSLocalizedString("Would you like to add the copied image to a board?", comment: "Clipboard Paste")),
                        primaryButton: .default(Text(NSLocalizedString("Add", comment: "Clipboard Paste"))) {
                            viewModel.showCategorySelection = true
                            viewModel.showClipboardImageAlert = false
                        },
                        secondaryButton: .cancel {
                            viewModel.showClipboardImageAlert = false
                            viewModel.clipboardImage = nil
                        }
                    )
                }
                .confirmationDialog(NSLocalizedString("Select Board", comment: "Clipboard Paste"), isPresented: $viewModel.showCategorySelection, actions: {
                    ForEach(viewModel.categories) { category in
                        Button(category.name) {
                            viewModel.addClipboardImageToCategory(category)
                            viewModel.showCategorySelection = false
                        }
                    }
                    Button(NSLocalizedString("Cancel", comment: "Clipboard Paste"), role: .cancel) {
                        viewModel.showCategorySelection = false
                        // Optionally reset clipboardImage if you don't want to prompt again
                        viewModel.clipboardImage = nil
                    }
            })
    }
    
    
    // MARK: - Header View
    var headerView: some View {
        ZStack {
            Text(viewModel.isFullVersionPurchased ? NSLocalizedString("React Pro 👑", comment: "") : NSLocalizedString("React Lite", comment: ""))
                .font(.headline)
            HStack {
                Spacer()
                HeaderMenuView(viewModel: viewModel)
            }
        }
        .padding(.vertical, 0)
    }
    // MARK: - Pro Banner View
    private var proBannerView: some View {
        Button(action: {
            viewModel.showPurchasePrompt = true
        }) {
            Text(NSLocalizedString("All Pics, No Ads! Upgrade to Unlock Unlimited Boards, Images, and iCloud Backup.", comment: ""))
                .frame(maxWidth: .infinity, maxHeight: 60)
                .padding(.horizontal, 25)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .font(.system(size: 13, weight: .bold))
        }
    }
}

// MARK: Tutorial

struct TutorialPage: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
    let description: String
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
        }
    }
}

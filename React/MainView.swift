import SwiftUI
import PhotosUI
import Combine
import UIKit


extension Collection {
    func element(at index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - ContentView
struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel
    @Environment(\.scenePhase) var scenePhase
    @State private var shouldShowTutorial: Bool = UserDefaults.standard.object(forKey: "shouldShowTutorial") == nil ? true : UserDefaults.standard.bool(forKey: "shouldShowTutorial")

    init() {
        _viewModel = StateObject(wrappedValue: ContentViewModel())
    }



    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            if shouldShowTutorial {
                TutorialView(shouldShowTutorial: $shouldShowTutorial)
            }
            else {
                VStack {
                    headerView

                    TabView(selection: $viewModel.selectedCategoryIndex) {
                        AudioBoardView(viewModel: viewModel.audioViewModel)
                            .simultaneousGesture(DragGesture(minimumDistance: 40).onEnded { value in
                                // List can consume the page's horizontal pan on iOS.
                                // The fixed destination agrees with the native pager, avoiding a double advance.
                                guard value.translation.width < -60,
                                      abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                                withAnimation { viewModel.selectedCategoryIndex = -1 }
                            })
                            .tag(-2)
                        DiscoverView().tag(-1)
                        ForEach(viewModel.categories.indices, id: \.self) { index in
                            GridView(viewModel: viewModel, boardID: viewModel.categories[index].id)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    CategoryButtonsView(
                        viewModel: viewModel
                    )


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
            PhotoPicker() { images in
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


    private var currentPageTitle: String {
        switch viewModel.selectedCategoryIndex {
        case -2: return NSLocalizedString("Sound", comment: "")
        case -1: return NSLocalizedString("Discover", comment: "")
        default: return viewModel.categories.element(at: viewModel.selectedCategoryIndex)?.name ?? NSLocalizedString("Boards", comment: "")
        }
    }

    // MARK: - Header View
    var headerView: some View {
        ZStack {
            VStack(spacing: 2) {
                Text("React").font(.caption).foregroundStyle(.secondary)
                Text(currentPageTitle).font(.headline).lineLimit(1)
            }
            .padding(.horizontal, 54)
            HStack {
                Button {
                    let previousIDs = Set(viewModel.categories.map(\.id))
                    viewModel.addNewCategory()
                    if let index = viewModel.categories.firstIndex(where: { !previousIDs.contains($0.id) && !$0.isTrash }) {
                        viewModel.selectedCategoryIndex = index
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .modifier(ReactGlass())
                }
                .buttonStyle(ToolbarIconStyle())
                .accessibilityLabel("Add Board")
                Spacer()
                HeaderMenuView(viewModel: viewModel)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
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

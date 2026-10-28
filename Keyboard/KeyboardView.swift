import UIKit
import SwiftUI
import Combine
import Foundation

//MARK: KeyboardView

struct KeyboardView: View {
    @ObservedObject var viewModel = KeyboardViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            ImageCarouselView(viewModel: viewModel)
            CategoryBarView(viewModel: viewModel)
        }
        //MARK: - keyboard color
        .background(Color(.systemGray4))
    }
}

//MARK: KeyboardViewController

class KeyboardViewController: UIInputViewController {
    private var heightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()

        let keyboardView = KeyboardView()
        let hostingController = UIHostingController(rootView: keyboardView)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
        
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    
}
//MARK: KeyboardViewModel
class KeyboardViewModel: ObservableObject {
    @Published var categories: [Category] = []
    @Published var selectedCategoryIndex = 0
    @Published var images: [UIImage] = []
    
    private let fileManager = FileManager.default
    private let imageCache = NSCache<NSString, UIImage>()
    
    init() {
        loadCategories()
        loadImages()
    }
    
    func loadCategories() {
        DispatchQueue.global(qos: .userInitiated).async {
            let categoriesURL = self.getCategoriesFileURL()
            do {
                let data = try Data(contentsOf: categoriesURL)
                var categories = try JSONDecoder().decode([Category].self, from: data)
                categories = categories.filter { !$0.isTrash }
                DispatchQueue.main.async {
                    self.categories = categories
                    self.loadImages()
                }
            } catch {
                print("Error loading categories: \(error.localizedDescription)")
            }
        }
    }
    
    func loadImages() {
        guard categories.indices.contains(selectedCategoryIndex) else { return }
        let category = categories[selectedCategoryIndex]
        DispatchQueue.global(qos: .userInitiated).async {
            let images = category.imagePaths.compactMap { self.loadImage(from: $0) }
            DispatchQueue.main.async {
                self.images = images
            }
        }
    }
    
    func loadImage(from filename: String) -> UIImage? {
        if let cachedImage = imageCache.object(forKey: filename as NSString) {
            return cachedImage
        }
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        if let image = UIImage(contentsOfFile: url.path) {
            imageCache.setObject(image, forKey: filename as NSString)
            return image
        }
        return nil
    }
    
    func getDocumentsDirectory() -> URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.PictoBoard.app") else {
            fatalError("Shared container could not be created.")
        }
        let imagesURL = containerURL.appendingPathComponent("Images")
        return imagesURL
    }
    
    func getCategoriesFileURL() -> URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.PictoBoard.app") else {
            fatalError("Shared container could not be created.")
        }
        return containerURL.appendingPathComponent("categories.json")
    }
}

//MARK: ImageCarouselView

struct ImageCarouselView: View {
    @ObservedObject var viewModel: KeyboardViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.images.indices, id: \.self) { index in
                    Button(action: {
                        let selectedImage = viewModel.images[index]
                        UIPasteboard.general.image = selectedImage
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }) {
                        Image(uiImage: viewModel.images[index])
                            .resizable()
                            .scaledToFit()
                            .frame(height: 180)
                            .cornerRadius(5)
                    }
                }
            }
            .padding(.horizontal)
        }
        .frame(height: 211)
    }
}

//MARK: CategoryBarView

struct CategoryBarView: View {
    @ObservedObject var viewModel: KeyboardViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(viewModel.categories.indices, id: \.self) { index in
                    Button(action: {
                        viewModel.selectedCategoryIndex = index
                        viewModel.loadImages()
                    }) {
                        Text(viewModel.categories[index].name)
                            .font(.system(size: 14))
                            .foregroundColor(viewModel.selectedCategoryIndex == index ? .white : Color(.systemGray))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(viewModel.selectedCategoryIndex == index ? Color.accentColor : Color(.systemGray2))
                            .cornerRadius(5)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical)
        }
        //MARK: - Category color
        .background(Color(.systemGray4))
    }
}

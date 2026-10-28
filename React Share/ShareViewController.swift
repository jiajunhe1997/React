import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers
import SwiftUI

class ShareViewController: UIViewController {
    let appGroupID = "group.com.PictoBoard.app"
    var categories: [Category] = []
    var selectedImage: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Load categories
        loadCategories()
        // Handle incoming content
        handleIncomingContent()
    }



    func loadCategories() {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            print("Shared container not found.")
            return
        }
        let categoriesURL = containerURL.appendingPathComponent("categories.json")
        do {
            let data = try Data(contentsOf: categoriesURL)
            categories = try JSONDecoder().decode([Category].self, from: data)
            // Filter out the trash category if needed
            categories = categories.filter { !$0.isTrash }
        } catch {
            print("Error loading categories: \(error.localizedDescription)")
        }
    }

    func handleIncomingContent() {

            // Proceed to handle the incoming image
            if let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
               let attachments = extensionItem.attachments {
                for attachment in attachments {
                    if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                        attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] (data, error) in
                            guard let self = self else { return }
                            if let url = data as? URL {
                                // Handle image URL
                                if let imageData = try? Data(contentsOf: url),
                                   let image = UIImage(data: imageData) {
                                    self.selectedImage = image
                                    DispatchQueue.main.async {
                                        self.presentBoardSelection()
                                    }
                                } else {
                                    self.dismissExtension()
                                }
                            } else if let image = data as? UIImage {
                                // Handle UIImage
                                self.selectedImage = image
                                DispatchQueue.main.async {
                                    self.presentBoardSelection()
                                }
                            } else {
                                self.dismissExtension()
                            }
                        }
                        return // Handle only the first image
                    }
                }
            }

    }

    func presentBoardSelection() {
        guard let selectedImage = selectedImage else {
            dismissExtension()
            return
        }

        let contentView = BoardSelectionView(categories: categories, onCancel: {
            self.dismissExtension()
        }) { [weak self] selectedCategory in
            self?.saveImage(selectedImage, to: selectedCategory)
        }

        let hostingController = UIHostingController(rootView: contentView)
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.largestUndimmedDetentIdentifier = .medium
        }

        present(hostingController, animated: true, completion: nil)
    }

    func saveImage(_ image: UIImage, to category: Category) {
        // Save the image to the app's shared container
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            print("Shared container not found.")
            dismissExtension()
            return
        }

        let imagesURL = containerURL.appendingPathComponent("Images")
        // Ensure the Images directory exists
        if !FileManager.default.fileExists(atPath: imagesURL.path) {
            do {
                try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Failed to create Images directory in shared container: \(error.localizedDescription)")
                dismissExtension()
                return
            }
        }

        let imageName = UUID().uuidString + ".png"
        let imagePath = imagesURL.appendingPathComponent(imageName)

        do {
            if let imageData = image.pngData() {
                try imageData.write(to: imagePath)
                print("Image saved successfully.")
                // Update the category with the new image path
                updateCategory(category, with: imageName)
            }
        } catch {
            print("Error saving image: \(error.localizedDescription)")
        }

        dismissExtension()
    }

    func updateCategory(_ category: Category, with imageName: String) {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            print("Shared container not found.")
            return
        }
        let categoriesURL = containerURL.appendingPathComponent("categories.json")
        do {
            // Load existing categories
            let data = try Data(contentsOf: categoriesURL)
            var existingCategories = try JSONDecoder().decode([Category].self, from: data)
            if let index = existingCategories.firstIndex(where: { $0.id == category.id }) {
                existingCategories[index].imagePaths.append(imageName)
                existingCategories[index].lastModified = Date()
                // Save updated categories
                let updatedData = try JSONEncoder().encode(existingCategories)
                try updatedData.write(to: categoriesURL)
                print("Category updated successfully.")
            }
        } catch {
            print("Error updating category: \(error.localizedDescription)")
        }
    }





    func dismissExtension() {
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}

struct BoardSelectionView: View {
    let categories: [Category]
    let onCancel: () -> Void
    let onSelect: (Category) -> Void

    var body: some View {
        NavigationStack {
            List(categories) { category in
                Button(action: {
                    onSelect(category)
                }) {
                    Text(category.name)
                }
            }
            .navigationBarTitle(NSLocalizedString("Select a Board to Save Image", comment: ""), displayMode: .inline)
            .navigationBarItems(leading: Button(NSLocalizedString("Cancel", comment: ""), action: onCancel))
        }
    }
}

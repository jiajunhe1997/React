import SwiftUI
import Combine
import StoreKit
import UIKit
import Foundation
import CryptoKit // Updated import

class ContentViewModel: ObservableObject {
    // Published properties for UI bindings
    @Published var categories: [Category] = []
    @Published var selectedCategoryIndex = 0 {
        didSet {
            saveSelectedCategoryIndex()
        }
    }
    @Published var isImagePickerPresented = false
    @Published var selectedImageIndex: Int? = nil
    @Published var isRenameModalPresented = false
    @Published var newCategoryName = ""
    @Published var showToast = false
    @Published var toastMessage = ""
    @Published var categoryToRenameIndex: Int? = nil
    @Published var showPurchasePrompt = false
    @Published var purchaseInProgress = false
    @Published var totalStorageUsed: String = "0 KB"
    @Published var isBackingUp = false
    @Published var isStorageUsagePresented = false
    @Published var isReorderCategoriesPresented = false
    @Published var isFullVersionPurchased: Bool = false
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String = ""
    @Published var purchaseError: String? = nil
    @Published var isShowingAudioBoard = false
    
    // Clipboard Paste
    @Published var showClipboardImageAlert = false
    @Published var showCategorySelection = false
    @Published var clipboardImage: UIImage?
    private var lastProcessedClipboardChangeCount = 0
    @Published var showCustomClipboardAlert = false
    private var imageHashCache: [String: String] = [:]
    
    // Constants
    let maxCategories = 4
    let maxImagesPerCategory = 8
    let columns = [
        GridItem(.fixed(170), spacing: 16),
        GridItem(.fixed(170), spacing: 16)
    ]
    
    @Published var audioViewModel: AudioViewModel = AudioViewModel()
    
    // Private properties
    private let selectedCategoryKey = "selectedCategoryIndex"
    private var cancellables = Set<AnyCancellable>()
    private let fileManager = FileManager.default
    private let imageCache = NSCache<NSString, UIImage>()
    private var totalSizeInBytes: Int64 = 0
    private var activeQueries: [NSMetadataQuery] = []
    
    private lazy var cloudManager: CloudManager = CloudManager(viewModel: self)
    private var storeManager: StoreManager

    init(storeManager: StoreManager) {
        self.storeManager = storeManager
        self.cloudManager = CloudManager(viewModel: self)
        
        // Bind StoreManager properties
        storeManager.$isFullVersionPurchased
            .receive(on: DispatchQueue.main)
            .assign(to: &$isFullVersionPurchased)
        
        storeManager.$isPurchasing
            .receive(on: DispatchQueue.main)
            .assign(to: \.purchaseInProgress, on: self)
            .store(in: &cancellables)
        
        storeManager.$purchaseError
            .receive(on: DispatchQueue.main)
            .assign(to: \.purchaseError, on: self)
            .store(in: &cancellables)
        
        // Load initial data
        loadCategories()
        loadSelectedCategoryIndex()
        calculateStorageUsed()
        
        // Observe changes to categories
        $categories
            .receive(on: DispatchQueue.global(qos: .background))
            .sink { [weak self] _ in
                self?.saveCategories()
            }
            .store(in: &cancellables)
        
        // Bind CloudManager properties
        cloudManager.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        cloudManager.$loadingMessage
            .receive(on: DispatchQueue.main)
            .assign(to: \.loadingMessage, on: self)
            .store(in: &cancellables)
        
        cloudManager.$showToast
            .receive(on: DispatchQueue.main)
            .assign(to: \.showToast, on: self)
            .store(in: &cancellables)
        
        cloudManager.$toastMessage
            .receive(on: DispatchQueue.main)
            .assign(to: \.toastMessage, on: self)
            .store(in: &cancellables)
    }
    
    // MARKL - SelectAudioBoard
    func selectAudioBoard() {
        isShowingAudioBoard = true
        selectedCategoryIndex = -2 // Use this index for AudioBoard
    }
    
    // MARK: - Compute Hash
    // Refactored to use ImageUtils
    func computeHash(for image: UIImage) -> String? {
        return ImageUtils.computeHash(for: image)
    }
    
    // MARK: - Clipboard Paste
    func checkClipboardForImage() {
        let pasteboard = UIPasteboard.general
        if pasteboard.changeCount != lastProcessedClipboardChangeCount {
            lastProcessedClipboardChangeCount = pasteboard.changeCount
            if let image = pasteboard.image {
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    guard let self = self else { return }
                    
                    guard let clipboardHash = self.computeHash(for: image) else {
                        DispatchQueue.main.async {
                            self.clipboardImage = image
                            self.showCustomClipboardAlert = true
                        }
                        return
                    }
                    
                    var isDuplicate = false
                    
                    for category in self.categories {
                        for imagePath in category.imagePaths {
                            if let existingImage = self.loadImage(from: imagePath),
                               let existingHash = self.computeHash(for: existingImage),
                               existingHash == clipboardHash {
                                isDuplicate = true
                                break
                            }
                        }
                        if isDuplicate { break }
                    }
                    
                    DispatchQueue.main.async {
                        if !isDuplicate {
                            self.clipboardImage = image
                            self.showCustomClipboardAlert = true
                        }
                    }
                }
            }
        }
    }
    
    func addClipboardImageToCategory(_ category: Category, image: UIImage? = nil) {
        guard let image = image ?? clipboardImage else { return }
        saveImage(image) { imagePath in
            if let imagePath = imagePath {
                if let index = self.categories.firstIndex(where: { $0.id == category.id }) {
                    self.categories[index].imagePaths.append(imagePath)
                    self.categories[index].lastModified = Date()
                }
            } else {
                self.showToastMessage(NSLocalizedString("Failed to save image.", comment: ""))
            }
            // Clear the clipboard image
            self.clipboardImage = nil
        }
    }
    
    // MARK: - Purchase Flow
    func purchaseFullVersion() {
        print("Initiating purchase...")
        purchaseInProgress = true
        Task {
            do {
                try await StoreManager.shared.purchaseFullVersion()
                DispatchQueue.main.async {
                    self.purchaseInProgress = false
                    self.showToastMessage(NSLocalizedString("Thank you for supporting React Pro!", comment: ""))
                }
            } catch {
                DispatchQueue.main.async {
                    self.purchaseInProgress = false
                    self.showToastMessage("\(NSLocalizedString("Purchase failed: ", comment: "Comment"))\(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Toast Message
    func showToastMessage(_ message: String) {
        DispatchQueue.main.async {
            self.toastMessage = message
            self.showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.showToast = false
            }
        }
    }
    
    // MARK: - Category Selection Persistence
    /// Save the selected category index to UserDefaults
    private func saveSelectedCategoryIndex() {
        UserDefaults.standard.set(selectedCategoryIndex, forKey: selectedCategoryKey)
    }
    
    /// Load the selected category index from UserDefaults
    private func loadSelectedCategoryIndex() {
        let savedIndex = UserDefaults.standard.integer(forKey: selectedCategoryKey)
        if savedIndex < categories.count {
            selectedCategoryIndex = savedIndex
        }
    }
    
    // MARK: - Data Persistence
    private func saveCategories() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            do {
                let data = try JSONEncoder().encode(self.categories)
                try data.write(to: self.getCategoriesFileURL())
            } catch {
                print("\(NSLocalizedString("Error saving boards: ", comment: "skip"))\(error.localizedDescription)")
            }
        }
    }
    
    func loadCategories() {
        let localCategoriesURL = getCategoriesFileURL()
        if FileManager.default.fileExists(atPath: localCategoriesURL.path) {
            do {
                let data = try Data(contentsOf: localCategoriesURL)
                categories = try JSONDecoder().decode([Category].self, from: data)
            } catch {
                print("\(NSLocalizedString("Error loading boards: ", comment: "skip"))\(error.localizedDescription)")
                initializeDefaultCategories()
            }
        } else {
            initializeDefaultCategories()
        }
    }
    
    private func initializeDefaultCategories() {
        categories = [
            Category(name: NSLocalizedString("Reaction", comment: "Default Board name 1")),
            Category(name: NSLocalizedString("Greeting", comment: "Default Board name 2")),
            Category(name: NSLocalizedString("Memes", comment: "Default Board name 3")),
            Category(name: NSLocalizedString("Trash", comment: "Trash Category Name"), isTrash: true) // Add Trash category
        ]
    }
    
    func getCategoriesFileURL() -> URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.PictoBoard.app") else {
            fatalError("Shared container could not be created.")
        }
        return containerURL.appendingPathComponent("categories.json")
    }
    
    // MARK: - iCloud Methods
    func syncWithiCloud() {
        cloudManager.syncWithiCloud()
    }
    
    func backupImagesToiCloud() {
        cloudManager.backupImagesToiCloud()
    }
    
    func isICloudAvailable() -> Bool {
        return cloudManager.isICloudAvailable()
    }
    
    func monitoriCloudUploadProgress(for filename: String) {
        cloudManager.monitoriCloudUploadProgress(for: filename)
    }
    
    func stopMonitoringiCloudUploadProgress() {
        cloudManager.stopMonitoringiCloudUploadProgress()
    }
    
    // MARK: - Helper Methods
    func initiateRenameCategory(for index: Int) {
        guard categories.indices.contains(index) else {
            showToastMessage(NSLocalizedString("Invalid board selected.", comment: ""))
            return
        }
        categoryToRenameIndex = index
        newCategoryName = categories[index].name
        isRenameModalPresented = true
    }
    
    // MARK: - Copy Image to Clipboard
    func copyImageToClipboard(_ imagePath: String) {
        guard let image = loadImage(from: imagePath) else { return }
        
        // Call the frame function and check if the user is using the lite version
        copyImageToClipboardWithFixedSize(image, isLiteVersion: !isFullVersionPurchased)
        
        showToastMessage(NSLocalizedString("Image copied to clipboard", comment: ""))
    }

    func copyImageToClipboardWithFixedSize(_ originalImage: UIImage, isLiteVersion: Bool) {
        let fixedOutputWidth: CGFloat = 600
        let frameHeight: CGFloat = 40
        
        if isLiteVersion {
            let aspectRatio = originalImage.size.height / originalImage.size.width
            let resizedHeight = fixedOutputWidth * aspectRatio
            
            let newImageSize = CGSize(width: fixedOutputWidth, height: resizedHeight + frameHeight)
            
            UIGraphicsBeginImageContextWithOptions(newImageSize, false, originalImage.scale)
            
            originalImage.draw(in: CGRect(x: 0, y: 0, width: fixedOutputWidth, height: resizedHeight))
            
            // Draw frame
            let frameRect = CGRect(x: 0, y: resizedHeight, width: fixedOutputWidth, height: frameHeight)
            UIColor.black.setFill()
            UIRectFill(frameRect)
            
            // Draw icon
            let iconSize: CGFloat = 20
            if let appIcon = UIImage(named: "FrameIcon") {
                let iconRect = CGRect(x: fixedOutputWidth - iconSize - 10, y: resizedHeight + (frameHeight - iconSize) / 2, width: iconSize, height: iconSize)
                appIcon.draw(in: iconRect)
            }
            
            // Draw text
            let text = NSLocalizedString("Sent with React", comment: "")
            let textColor = UIColor.white
            let textFont = UIFont.boldSystemFont(ofSize: 18)
            
            let textStyle = NSMutableParagraphStyle()
            textStyle.alignment = .right
            
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: textFont,
                .foregroundColor: textColor,
                .paragraphStyle: textStyle
            ]
            
            let textRect = CGRect(x: 0, y: resizedHeight + (frameHeight - 30) / 2 + 5, width: fixedOutputWidth - iconSize - 15, height: 30)
            text.draw(in: textRect, withAttributes: textAttributes)
            
            let newImageWithFrame = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let finalImage = newImageWithFrame {
                UIPasteboard.general.image = finalImage
            }
        } else {
            UIPasteboard.general.image = originalImage
        }
    }
    
    // MARK: - Add New Board
    func addNewCategory() {
        let regularCategories = categories.filter { !$0.isTrash }
        
        if regularCategories.count >= maxCategories && !isFullVersionPurchased {
            showPurchasePrompt = true
        } else {
            let newCategoryName = String(
                format: NSLocalizedString("Board %d", comment: "Name of new boards with numbers"),
                regularCategories.count + 1
            )
            
            if let trashIndex = categories.firstIndex(where: { $0.isTrash }) {
                var newCategory = Category(name: newCategoryName)
                newCategory.lastModified = Date()
                
                withAnimation {
                    categories.insert(newCategory, at: trashIndex)
                }
            } else {
                var newCategory = Category(name: newCategoryName)
                newCategory.lastModified = Date() // Update the timestamp
                withAnimation {
                    categories.append(newCategory)
                    var trashCategory = Category(name: NSLocalizedString("Trash", comment: ""), isTrash: true)
                    trashCategory.lastModified = Date() // Update the timestamp
                    categories.append(trashCategory)
                }
            }
        }
    }
    
    // MARK: - Delete Board
    func deleteCategory() {
        let regularCategories = categories.filter { !$0.isTrash }
        if regularCategories.count > 1 {
            let indexToRemove = selectedCategoryIndex
            
            guard categories.indices.contains(indexToRemove) else {
                showToastMessage(NSLocalizedString("Invalid board selected.", comment: ""))
                return
            }
            
            let category = categories[indexToRemove]
            for imagePath in category.imagePaths {
                moveImageToTrash(imagePath)
            }
            
            if let trashIndex = categories.firstIndex(where: { $0.isTrash }) {
                categories[trashIndex].lastModified = Date()
            }
            withAnimation {
                categories.remove(at: indexToRemove)
                selectedCategoryIndex = max(0, indexToRemove - 1)
            }
        } else {
            showToastMessage(NSLocalizedString("Can't delete the last board!", comment: ""))
        }
    }
    
    // MARK: - Rename Board
    func renameCategory(at index: Int, to newName: String) {
        guard categories.indices.contains(index) else { return }
        categories[index].name = newName
        categories[index].lastModified = Date()
        isRenameModalPresented = false
        showToastMessage(NSLocalizedString("Board renamed successfully.", comment: ""))
    }
    
    // MARK: - Move Image to Trash
    func moveImageToTrash(_ imagePath: String) {
        if let trashIndex = categories.firstIndex(where: { $0.isTrash }) {
            categories[trashIndex].imagePaths.append(imagePath)
            categories[trashIndex].lastModified = Date()
        } else {
            var trashCategory = Category(
                name: NSLocalizedString("Trash", comment: ""),
                imagePaths: [imagePath],
                isTrash: true
            )
            trashCategory.lastModified = Date()
            categories.append(trashCategory)
        }
    }
    
    // MARK: - Clear Trash
    func clearTrash() {
        if let trashIndex = categories.firstIndex(where: { $0.isTrash }) {
            let trashCategory = categories[trashIndex]
            for imagePath in trashCategory.imagePaths {
                deleteImageFile(named: imagePath)
            }
            withAnimation {
                categories[trashIndex].imagePaths.removeAll()
                categories[trashIndex].lastModified = Date() // Update the timestamp
            }
        }
    }
    
    // MARK: - Image Handling with Caching
    func loadImage(from filename: String) -> UIImage? {
        let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
        return UIImage(contentsOfFile: fileURL.path)
    }

    func getDocumentsDirectory() -> URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.PictoBoard.app") else {
            fatalError("Shared container could not be created.")
        }
        let imagesURL = containerURL.appendingPathComponent("Images")
        
        // Ensure the Images directory exists
        if !FileManager.default.fileExists(atPath: imagesURL.path) {
            do {
                try FileManager.default.createDirectory(at: imagesURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Failed to create Images directory in shared container: \(error.localizedDescription)")
            }
        }
        
        return imagesURL
    }
    
    func saveImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }
        let filename = UUID().uuidString + ".jpg"
        let fileURL = getDocumentsDirectory().appendingPathComponent(filename)
        
        DispatchQueue.global(qos: .background).async {
            do {
                try data.write(to: fileURL)
                DispatchQueue.main.async {
                    if let hash = ImageUtils.computeHash(for: image) {
                        self.imageHashCache[filename] = hash
                    }
                    completion(filename)
                }
            } catch {
                print("Error saving image: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    func deleteImage(at index: Int) {
        guard categories.indices.contains(selectedCategoryIndex),
              categories[selectedCategoryIndex].imagePaths.indices.contains(index) else {
            showToastMessage(NSLocalizedString("Invalid image selected.", comment: ""))
            return
        }
        
        let imagePath = categories[selectedCategoryIndex].imagePaths[index]
        moveImageToTrash(imagePath)
        withAnimation {
            _ = categories[selectedCategoryIndex].imagePaths.remove(at: index)
        }
    }
    
    func deleteImagePermanently(at index: Int) {
        guard categories.indices.contains(selectedCategoryIndex),
              categories[selectedCategoryIndex].imagePaths.indices.contains(index) else {
            showToastMessage(NSLocalizedString("Invalid image selected.", comment: ""))
            return
        }
        
        let imagePath = categories[selectedCategoryIndex].imagePaths[index]
        deleteImageFile(named: imagePath)
        withAnimation {
            _ = categories[selectedCategoryIndex].imagePaths.remove(at: index)
        }
    }
    
    func deleteImageFile(named filename: String) {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        do {
            // Remove from cache
            imageCache.removeObject(forKey: filename as NSString)
            // Get file size
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? NSNumber {
                updateStorageUsed(byAdding: -fileSize.int64Value)
            }
            try fileManager.removeItem(at: url)
        } catch {
            print("\(NSLocalizedString("Error deleting image file: ", comment: "skip"))\(error.localizedDescription)")
        }
    }
    
    // MARK: - Storage Used
    private func updateStorageUsed(byAdding bytes: Int64) {
        DispatchQueue.main.async {
            self.totalSizeInBytes += bytes
            self.totalSizeInBytes = max(0, self.totalSizeInBytes) // Ensure it doesn't go negative
            self.totalStorageUsed = self.formatBytes(self.totalSizeInBytes)
        }
    }
    
    private func calculateStorageUsed() {
        DispatchQueue.global(qos: .background).async {
            let documentsURL = self.getDocumentsDirectory()
            do {
                let files = try self.fileManager.contentsOfDirectory(
                    at: documentsURL,
                    includingPropertiesForKeys: [.fileSizeKey],
                    options: .skipsHiddenFiles
                )
                let totalSize = files.reduce(Int64(0)) { (size, fileURL) -> Int64 in
                    let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    return size + Int64(fileSize)
                }
                DispatchQueue.main.async {
                    self.totalSizeInBytes = totalSize
                    self.totalStorageUsed = self.formatBytes(totalSize)
                }
            } catch {
                print("\(NSLocalizedString("Error calculating storage used: ", comment: "skip"))\(error.localizedDescription)")
            }
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Storage Used by Category
    func storageUsedByCategory(_ category: Category) -> String {
        let totalSize = category.imagePaths.reduce(Int64(0)) { size, imagePath in
            let url = getDocumentsDirectory().appendingPathComponent(imagePath)
            let fileSize = (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
            return size + fileSize
        }
        return formatBytes(totalSize)
    }
}

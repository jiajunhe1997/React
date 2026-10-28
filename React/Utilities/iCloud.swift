import Foundation
import Combine
import UIKit
import CryptoKit

class CloudManager: ObservableObject {
    static let shared = CloudManager()

    // MARK: - Published Properties
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String = ""
    @Published var showToast: Bool = false
    @Published var toastMessage: String = ""

    // MARK: - Properties
    weak var viewModel: ContentViewModel?
    private var activeQueries: [NSMetadataQuery] = []
    private let fileManager = FileManager.default

    // MARK: - Initializers
    init(viewModel: ContentViewModel? = nil) {
        self.viewModel = viewModel
    }
    
    private init() {}

    // MARK: - iCloud Availability
    func isICloudAvailable() -> Bool {
        return fileManager.url(forUbiquityContainerIdentifier: nil) != nil
    }

    // MARK: - Syncing with iCloud
    func syncWithiCloud() {
        guard let viewModel = viewModel else {
            return
        }
        guard isICloudAvailable() else {
            showToastMessage(NSLocalizedString("iCloud is not available.", comment: ""))
            return
        }

        DispatchQueue.main.async {
            self.isLoading = true
            self.loadingMessage = NSLocalizedString("Syncing with iCloud...", comment: "")
        }

        Task {
            do {
                let iCloudCategories = try await fetchiCloudCategories()
                let mergedCategories = mergeCategories(localCategories: viewModel.categories, iCloudCategories: iCloudCategories)
                DispatchQueue.main.async {
                    viewModel.categories = mergedCategories
                }
                try await saveCategoriesToiCloud(categories: mergedCategories)
                try await downloadMissingImages(from: mergedCategories)
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.showToastMessage(NSLocalizedString("Download completed successfully.", comment: ""))
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.showToastMessage(NSLocalizedString("Download failed: \(error.localizedDescription)", comment: ""))
                }
                print("Download failed: \(error.localizedDescription)")
            }
        }
    }

    private func fetchiCloudCategories() async throws -> [Category] {
        guard let viewModel = viewModel else { return [] }
        guard let iCloudContainerURL = fileManager.url(forUbiquityContainerIdentifier: nil) else {
            throw NSError(domain: "iCloud", code: 0, userInfo: [NSLocalizedDescriptionKey: "iCloud container not found."])
        }
        let iCloudDocumentsURL = iCloudContainerURL.appendingPathComponent("Documents")
        let iCloudCategoriesURL = iCloudDocumentsURL.appendingPathComponent("categories.json")
        if fileManager.fileExists(atPath: iCloudCategoriesURL.path) {
            let data = try Data(contentsOf: iCloudCategoriesURL)
            let categories = try JSONDecoder().decode([Category].self, from: data)
            return categories
        } else {
            return viewModel.categories
        }
    }

    private func mergeCategories(localCategories: [Category], iCloudCategories: [Category]) -> [Category] {
        var merged = localCategories
        for iCloudCategory in iCloudCategories {
            if let localIndex = merged.firstIndex(where: { $0.id == iCloudCategory.id }) {
                let localCategory = merged[localIndex]
                if iCloudCategory.lastModified > localCategory.lastModified {
                    merged[localIndex] = iCloudCategory
                }
            } else {
                merged.append(iCloudCategory)
            }
        }
        return merged.filter { !$0.imagePaths.isEmpty }
    }

    private func saveCategoriesToiCloud(categories: [Category]) async throws {
        guard let iCloudContainerURL = fileManager.url(forUbiquityContainerIdentifier: nil) else {
            throw NSError(domain: "iCloud", code: 0, userInfo: [NSLocalizedDescriptionKey: "iCloud container not found."])
        }
        let iCloudDocumentsURL = iCloudContainerURL.appendingPathComponent("Documents")
        let iCloudImagesURL = iCloudDocumentsURL.appendingPathComponent("Images")
        try fileManager.createDirectory(at: iCloudDocumentsURL, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createDirectory(at: iCloudImagesURL, withIntermediateDirectories: true, attributes: nil)
        let iCloudCategoriesURL = iCloudDocumentsURL.appendingPathComponent("categories.json")
        let filteredCategories = categories.filter { !$0.imagePaths.isEmpty }
        let data = try JSONEncoder().encode(filteredCategories)
        try data.write(to: iCloudCategoriesURL)
    }

    private func downloadMissingImages(from categories: [Category]) async throws {
        guard let viewModel = viewModel else { return }
        guard let iCloudContainerURL = fileManager.url(forUbiquityContainerIdentifier: nil) else {
            throw NSError(domain: "iCloud", code: 0, userInfo: [NSLocalizedDescriptionKey: "iCloud container not found."])
        }
        let iCloudImagesURL = iCloudContainerURL.appendingPathComponent("Documents").appendingPathComponent("Images")
        for category in categories where !category.isTrash {
            for imagePath in category.imagePaths {
                let localImageURL = viewModel.getDocumentsDirectory().appendingPathComponent(imagePath)
                let iCloudImageURL = iCloudImagesURL.appendingPathComponent(imagePath)
                if !fileManager.fileExists(atPath: localImageURL.path) && fileManager.fileExists(atPath: iCloudImageURL.path) {
                    let downloadedURL = try await downloadFile(from: iCloudImageURL, to: localImageURL)
                    print("Downloaded image: \(downloadedURL.path)")
                }
            }
        }
    }

    private func downloadFile(from iCloudURL: URL, to localURL: URL) async throws -> URL {
        let (tempURL, _) = try await URLSession.shared.download(from: iCloudURL)
        guard let viewModel = viewModel else { return localURL }
        let localImagesURL = viewModel.getDocumentsDirectory()
        try fileManager.createDirectory(at: localImagesURL, withIntermediateDirectories: true, attributes: nil)
        try fileManager.moveItem(at: tempURL, to: localURL)
        return localURL
    }

    // MARK: - iCloud Backup
    func backupImagesToiCloud() {
        guard let viewModel = viewModel, isICloudAvailable() else {
            showToastMessage(NSLocalizedString("iCloud is not available.", comment: ""))
            return
        }
        guard let iCloudContainerURL = fileManager.url(forUbiquityContainerIdentifier: nil) else {
            showToastMessage(NSLocalizedString("iCloud container not found.", comment: ""))
            return
        }
        let iCloudDocumentsURL = iCloudContainerURL.appendingPathComponent("Documents")
        let iCloudImagesURL = iCloudDocumentsURL.appendingPathComponent("Images")
        DispatchQueue.main.async {
            self.isLoading = true
            self.loadingMessage = NSLocalizedString("Backing up to iCloud...", comment: "")
        }
        Task {
            do {
                try fileManager.createDirectory(at: iCloudImagesURL, withIntermediateDirectories: true, attributes: nil)
                let localCategoriesURL = getCategoriesFileURL()
                let iCloudCategoriesURL = iCloudDocumentsURL.appendingPathComponent("categories.json")
                if fileManager.fileExists(atPath: localCategoriesURL.path) {
                    if fileManager.fileExists(atPath: iCloudCategoriesURL.path) {
                        try fileManager.removeItem(at: iCloudCategoriesURL)
                    }
                    try fileManager.copyItem(at: localCategoriesURL, to: iCloudCategoriesURL)
                }
                for category in viewModel.categories where !category.isTrash && !category.imagePaths.isEmpty {
                    for imagePath in category.imagePaths {
                        let localImageURL = viewModel.getDocumentsDirectory().appendingPathComponent(imagePath)
                        let iCloudImageURL = iCloudImagesURL.appendingPathComponent(imagePath)
                        if fileManager.fileExists(atPath: localImageURL.path) && !fileManager.fileExists(atPath: iCloudImageURL.path) {
                            try fileManager.setUbiquitous(true, itemAt: localImageURL, destinationURL: iCloudImageURL)
                            monitoriCloudUploadProgress(for: imagePath)
                        }
                    }
                }
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.showToastMessage(NSLocalizedString("Backup to iCloud completed.", comment: ""))
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.showToastMessage(String(format: NSLocalizedString("Backup failed: %@", comment: ""), error.localizedDescription))
                }
                print("Backup failed: \(error.localizedDescription)")
            }
        }
    }

    private func getCategoriesFileURL() -> URL {
        guard let viewModel = viewModel else { return URL(fileURLWithPath: "") }
        return viewModel.getCategoriesFileURL()
    }

    // MARK: - Monitor iCloud Upload Progress
    func monitoriCloudUploadProgress(for filename: String) {
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K == %@", argumentArray: [NSMetadataItemFSNameKey, filename])
        
        NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] notification in
            self?.queryDidUpdate(query)
        }
        
        NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { [weak self] notification in
            self?.queryDidFinish(query)
        }
        query.start()
        activeQueries.append(query)
    }

    private func queryDidUpdate(_ query: NSMetadataQuery) {
        processQueryResults(query)
    }

    private func queryDidFinish(_ query: NSMetadataQuery) {
        processQueryResults(query)
        query.stop()
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: query)
        NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: query)
        if let index = activeQueries.firstIndex(of: query) {
            activeQueries.remove(at: index)
        }
    }

    private func processQueryResults(_ query: NSMetadataQuery) {
        query.disableUpdates()
        defer { query.enableUpdates() }
        for item in query.results as? [NSMetadataItem] ?? [] {
            if let percentUploaded = item.value(forAttribute: NSMetadataUbiquitousItemPercentUploadedKey) as? Double,
               let isUploaded = item.value(forAttribute: NSMetadataUbiquitousItemIsUploadedKey) as? Bool {
                print("File \(item.value(forAttribute: NSMetadataItemFSNameKey) as? String ?? "Unknown") is \(percentUploaded)% uploaded. Uploaded: \(isUploaded)")
                if isUploaded {
                    showToastMessage("File \(item.value(forAttribute: NSMetadataItemFSNameKey) as? String ?? "Unknown") has been successfully uploaded to iCloud.")
                }
            }
        }
    }

    // MARK: - Stop Monitoring iCloud Upload Progress
    func stopMonitoringiCloudUploadProgress() {
        for query in activeQueries {
            query.stop()
            NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidUpdate, object: query)
            NotificationCenter.default.removeObserver(self, name: .NSMetadataQueryDidFinishGathering, object: query)
        }
        activeQueries.removeAll()
    }

    // MARK: - Delete Empty Boards
    func deleteEmptyBoards() async {
        guard let viewModel = viewModel else { return }
        viewModel.categories.removeAll { $0.imagePaths.isEmpty }
        do {
            try await saveCategoriesToiCloud(categories: viewModel.categories)
            DispatchQueue.main.async {
                self.showToastMessage(NSLocalizedString("Empty boards deleted successfully.", comment: ""))
            }
        } catch {
            DispatchQueue.main.async {
                self.showToastMessage(String(format: NSLocalizedString("Failed to delete empty boards: %@", comment: ""), error.localizedDescription))
            }
            print("Failed to delete empty boards: \(error.localizedDescription)")
        }
    }

    // MARK: - Toast and Loading Messages
    private func showToastMessage(_ message: String) {
        DispatchQueue.main.async {
            self.toastMessage = message
            
            self.showToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.showToast = false
            }
        }
    }
}

//
//  ImageViewModel.swift
//  React
//
//  Created by 何佳駿 on 2024/10/30.
//

import SwiftUI

struct PaginatedResponse: Decodable {
    let items: [ImageFile]
    let pagination: PaginationInfo
}

struct PaginationInfo: Decodable {
    let total: Int
    let start: Int
    let limit: Int
    let hasMore: Bool
}

@MainActor
class ImageViewModel: ObservableObject {
    // Published properties for UI updates
    @Published private(set) var displayedImages: [ImageFile] = []
    @Published private(set) var isLoadingMore = false
    @Published private(set) var isInitialLoad = true
    
    // Category-specific image lists
    private var categoryLists: [SortingOption: [ImageFile]] = [
        .trending: [],
        .new: [],
        .mostFavorited: [],
        .myFavorites: []
    ]
    
    // Current sorting option with instant list switch
    var currentSortingOption: SortingOption = .trending {
        didSet {
            print("🔄 Switching category to: \(currentSortingOption)")
            // Reset pagination state
            displayedImages = []
            hasMorePages = true
            
            // Fetch first page for new category
            Task {
                await refreshCategory(currentSortingOption)
            }
        }
    }
    
    private var allImages: [ImageFile] = []
    private let initialPageSize = 10
    private let standardPageSize = 20
    private var hasMorePages: Bool = true
    private var favoriteImageIDs: Set<String> = []
    private let favoritesKey = "FavoriteImageIDs"
    private let backendURL = "https://script.google.com/macros/s/AKfycbx4G71X5Pu0jL6dxvaySaU9foc5ercV7yLPgU5zPYKE84Un6fHW7x_t00HSw-avyPorpQ/exec"
    
    // Task management
    private var refreshTasks: [SortingOption: Task<Void, Never>] = [:]
    private var loadMoreDebouncer: Task<Void, Never>?
    private var isFetching = false
    
    init() {
        loadFavorites()
        Task {
            await initialLoad()
        }
    }
    
    private func loadFavorites() {
        if let savedFavorites = UserDefaults.standard.array(forKey: favoritesKey) as? [String] {
            favoriteImageIDs = Set(savedFavorites)
            print("📱 Loaded \(favoriteImageIDs.count) favorites from local storage")
        }
    }
    
    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteImageIDs), forKey: favoritesKey)
        print("💾 Saved \(favoriteImageIDs.count) favorites to local storage")
    }
    
    private func initialLoad() async {
        print("🚀 Starting initial load")
        isInitialLoad = true
        
        // Initial quick load for current category
        await fetchAndSortImages(pageSize: initialPageSize, forceRefresh: true)
        isInitialLoad = false
        print("✅ Initial load complete")
    }
    
    private func refreshCategory(_ category: SortingOption) async {
        print("🔄 Refreshing category: \(category)")
        // Cancel existing refresh task for this category
        refreshTasks[category]?.cancel()
        
        // Create new refresh task
        let task = Task {
            await fetchAndSortImages(forCategory: category, forceRefresh: true)
        }
        refreshTasks[category] = task
        
        // Wait for completion and clean up
        await task.value
        refreshTasks[category] = nil
        print("✅ Category refresh complete: \(category)")
    }
    
    func refresh() async {
        print("🔄 Manual refresh triggered")
        // Reset pagination state
        displayedImages = []
        hasMorePages = true
        
        // Refresh current category immediately
        await fetchAndSortImages(forceRefresh: true)
        print("✅ Manual refresh complete")
    }
    
    private func fetchAndSortImages(pageSize: Int = 20, forCategory: SortingOption? = nil, forceRefresh: Bool = false) async {
        guard !isFetching || forceRefresh else { return }
        
        // Create URL with pagination parameters
        var urlComponents = URLComponents(string: backendURL)!
        let start = forceRefresh ? 0 : displayedImages.count
        urlComponents.queryItems = [
            URLQueryItem(name: "sheet", value: "IMAGE"),
            URLQueryItem(name: "start", value: "\(start)"),
            URLQueryItem(name: "limit", value: "\(pageSize)")
        ]
        
        guard let url = urlComponents.url else { return }
        
        isFetching = true
        let targetCategory = forCategory ?? currentSortingOption
        print("📡 Fetching images - Category: \(targetCategory), Start: \(start), Limit: \(pageSize)")
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            
            let response = try decoder.decode(PaginatedResponse.self, from: data)
            var fetchedImages = response.items
            print("📥 Received \(fetchedImages.count) images from backend")
            
            fetchedImages = fetchedImages.map { image in
                var mutable = image
                mutable.isFavorite = favoriteImageIDs.contains(image.id)
                return mutable
            }
            
            // Sort images based on category
            var sortedImages = fetchedImages
            switch targetCategory {
            case .trending:
                sortedImages.sort {
                    let score1 = Double($0.access) + Double($0.like) * 2
                    let score2 = Double($1.access) + Double($1.like) * 2
                    return score1 > score2
                }
            case .new:
                sortedImages.sort { $0.date > $1.date }
            case .mostFavorited:
                sortedImages.sort { $0.like > $1.like }
            case .myFavorites:
                sortedImages = sortedImages.filter { $0.isFavorite }
                sortedImages.sort { $0.date > $1.date }
            }
            
            // Update displayed images
            if targetCategory == currentSortingOption {
                if forceRefresh {
                    displayedImages = sortedImages
                } else {
                    displayedImages.append(contentsOf: sortedImages)
                }
                print("🔄 Updated display - Total images: \(displayedImages.count)")
            }
            
            hasMorePages = response.pagination.hasMore && !sortedImages.isEmpty
            print("📊 Pagination status - Has more: \(hasMorePages)")
            
        } catch {
            print("❌ Error fetching images: \(error)")
        }
        
        isFetching = false
    }
    
    func loadMoreIfNeeded(currentItem: ImageFile) {
        // Cancel previous debouncer
        loadMoreDebouncer?.cancel()
        
        // Create new debounced task
        loadMoreDebouncer = Task {
            // Add debounce delay first
            try? await Task.sleep(nanoseconds: 250_000_000) // 0.25 second debounce
            
            // Check conditions after the delay
            guard !Task.isCancelled,
                  !isLoadingMore,
                  !isFetching,
                  hasMorePages,
                  !displayedImages.isEmpty else { return }
            
            let thresholdIndex = displayedImages.index(displayedImages.endIndex, offsetBy: -5)
            guard let itemIndex = displayedImages.firstIndex(where: { $0.id == currentItem.id }),
                  itemIndex >= thresholdIndex else { return }
            
            print("📜 Loading more images - Triggered by item at index \(itemIndex)")
            isLoadingMore = true
            await fetchAndSortImages(pageSize: standardPageSize, forceRefresh: false)
            isLoadingMore = false
        }
    }
    
    func handleFavorite(imageFile: ImageFile) {
        guard let index = displayedImages.firstIndex(where: { $0.id == imageFile.id }) else { return }
        
        var updatedFile = displayedImages[index]
        updatedFile.isFavorite.toggle()
        
        if updatedFile.isFavorite {
            favoriteImageIDs.insert(imageFile.id)
            updatedFile.like += 1
            print("❤️ Image favorited: \(imageFile.id)")
        } else {
            favoriteImageIDs.remove(imageFile.id)
            updatedFile.like = max(updatedFile.like - 1, 0)
            print("💔 Image unfavorited: \(imageFile.id)")
        }
        
        // Update displayed images
        displayedImages[index] = updatedFile
        
        saveFavorites()
        
        // Update backend
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
            if !Task.isCancelled {
                await updateBackend(imageFile: imageFile, type: updatedFile.isFavorite ? "like" : "unlike")
            }
        }
    }
    
    func handleImageCopy(imageFile: ImageFile, image: UIImage) {
        UIPasteboard.general.image = image
        print("📋 Image copied to clipboard: \(imageFile.id)")
        
        guard let index = displayedImages.firstIndex(where: { $0.id == imageFile.id }) else { return }
        
        var updatedFile = displayedImages[index]
        updatedFile.access += 1
        
        // Update displayed images
        displayedImages[index] = updatedFile
        
        // Update backend
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
            if !Task.isCancelled {
                await updateBackend(imageFile: imageFile, type: "access")
            }
        }
    }
    
    private func updateBackend(imageFile: ImageFile, type: String) async {
        guard let url = URL(string: backendURL) else { return }
        
        print("📤 Updating backend - Type: \(type), Image: \(imageFile.id)")
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let postData: [String: Any] = ["url": imageFile.url.absoluteString, "type": type]
            request.httpBody = try JSONSerialization.data(withJSONObject: postData)
            
            let (_, _) = try await URLSession.shared.data(for: request)
            print("✅ Backend update successful - Type: \(type)")
        } catch {
            print("❌ Error updating backend: \(error)")
        }
    }
}

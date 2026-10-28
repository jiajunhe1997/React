//
//  ImageLoader.swift
//  React
//
//  Created by 何佳駿 on 2024/10/30.
//

import SwiftUI

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var isLoadingOriginal = false
    private var loadedThumbnail = false

    static let shared = ImageLoader()
    private var preloadedImages = NSCache<NSString, UIImage>()
    
    private func getOriginalURL(_ url: URL) -> URL {
        var urlString = url.absoluteString
        if let range = urlString.range(of: "/masonry/") {
            urlString.replaceSubrange(range, with: "/original/")
        }
        return URL(string: urlString) ?? url
    }
    
    func loadImage(from url: URL) {
        print("🔍 Attempting to load image from URL: \(url.absoluteString)")
        
        // First try to load from preloaded cache
        if let preloadedImage = preloadedImages.object(forKey: url.absoluteString as NSString) {
            print("✨ Found image in preload cache: \(url.absoluteString)")
            self.image = preloadedImage
            preloadedImages.removeObject(forKey: url.absoluteString as NSString)
            print("🗑️ Removed from preload cache: \(url.absoluteString)")
            return
        }
        
        // Then check regular cache
        if let cachedImage = ImageCache.shared.getImage(forKey: url.absoluteString) {
            print("📦 Found image in main cache: \(url.absoluteString)")
            self.image = cachedImage
            return
        }

        print("🌐 Image not in cache, loading from network: \(url.absoluteString)")
        // Load thumbnail first
        loadThumbnail(from: url)
    }

    private func loadThumbnail(from url: URL) {
        print("👍 Loading thumbnail: \(url.absoluteString)")
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Thumbnail load failed: \(error.localizedDescription)")
                return
            }
            
            if let data = data, let thumbnailImage = UIImage(data: data) {
                print("✅ Thumbnail loaded successfully: \(url.absoluteString)")
                DispatchQueue.main.async {
                    if !self.loadedThumbnail {
                        self.image = thumbnailImage
                        self.loadedThumbnail = true
                        ImageCache.shared.setImage(thumbnailImage, forKey: url.absoluteString)
                        print("💾 Thumbnail cached: \(url.absoluteString)")
                    }
                    
                    // Load original image after thumbnail
                    self.loadOriginalImage(from: url)
                }
            }
        }.resume()
    }

    private func loadOriginalImage(from url: URL) {
        guard !isLoadingOriginal else {
            print("⏳ Original image load already in progress: \(url.absoluteString)")
            return
        }
        isLoadingOriginal = true
        
        let originalURL = getOriginalURL(url)
        print("🖼️ Loading original image: \(originalURL.absoluteString)")
        
        URLSession.shared.dataTask(with: originalURL) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Original image load failed: \(error.localizedDescription)")
                self.isLoadingOriginal = false
                return
            }
            
            if let data = data, let originalImage = UIImage(data: data) {
                print("✅ Original image loaded successfully: \(originalURL.absoluteString)")
                DispatchQueue.main.async {
                    self.image = originalImage
                    // Cache with both URLs for faster lookup
                    ImageCache.shared.setImage(originalImage, forKey: url.absoluteString)
                    ImageCache.shared.setImage(originalImage, forKey: originalURL.absoluteString)
                    print("💾 Original image cached with both URLs:")
                    print("   - Masonry URL: \(url.absoluteString)")
                    print("   - Original URL: \(originalURL.absoluteString)")
                    self.isLoadingOriginal = false
                }
            }
        }.resume()
    }

    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        print("🔍 Loading image with completion handler: \(url.absoluteString)")
        
        // Check preloaded cache first
        if let preloadedImage = preloadedImages.object(forKey: url.absoluteString as NSString) {
            print("✨ Found image in preload cache: \(url.absoluteString)")
            DispatchQueue.main.async {
                completion(preloadedImage)
            }
            preloadedImages.removeObject(forKey: url.absoluteString as NSString)
            print("🗑️ Removed from preload cache: \(url.absoluteString)")
            return
        }
        
        // Then check regular cache with both URLs
        let originalURL = getOriginalURL(url)
        if let cachedImage = ImageCache.shared.getImage(forKey: url.absoluteString) {
            print("📦 Found image in main cache with masonry URL: \(url.absoluteString)")
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        } else if let cachedImage = ImageCache.shared.getImage(forKey: originalURL.absoluteString) {
            print("📦 Found image in main cache with original URL: \(originalURL.absoluteString)")
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }

        print("🌐 Image not in cache, loading from network: \(url.absoluteString)")
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Image load failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            var image: UIImage?
            if let data = data, let downloadedImage = UIImage(data: data) {
                print("✅ Image downloaded successfully: \(url.absoluteString)")
                ImageCache.shared.setImage(downloadedImage, forKey: url.absoluteString)
                ImageCache.shared.setImage(downloadedImage, forKey: originalURL.absoluteString)
                print("💾 Image cached with both URLs:")
                print("   - Masonry URL: \(url.absoluteString)")
                print("   - Original URL: \(originalURL.absoluteString)")
                image = downloadedImage
            }
            DispatchQueue.main.async {
                completion(image)
            }
        }.resume()
    }
    
    func preloadImage(from url: URL) {
        print("🔮 Attempting to preload image: \(url.absoluteString)")
        let originalURL = getOriginalURL(url)
        
        guard preloadedImages.object(forKey: url.absoluteString as NSString) == nil,
              preloadedImages.object(forKey: originalURL.absoluteString as NSString) == nil else {
            print("⚡️ Image already in preload cache: \(url.absoluteString)")
            return
        }
        
        guard ImageCache.shared.getImage(forKey: url.absoluteString) == nil,
              ImageCache.shared.getImage(forKey: originalURL.absoluteString) == nil else {
            print("📦 Image already in main cache: \(url.absoluteString)")
            return
        }
        
        print("🌐 Preloading image from network: \(url.absoluteString)")
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("❌ Preload failed: \(error.localizedDescription)")
                return
            }
            
            if let data = data, let image = UIImage(data: data) {
                print("✅ Image preloaded successfully: \(url.absoluteString)")
                self?.preloadedImages.setObject(image, forKey: url.absoluteString as NSString)
                self?.preloadedImages.setObject(image, forKey: originalURL.absoluteString as NSString)
                print("💾 Image added to preload cache with both URLs:")
                print("   - Masonry URL: \(url.absoluteString)")
                print("   - Original URL: \(originalURL.absoluteString)")
            }
        }.resume()
    }
}

class ImageCache {
    static let shared = ImageCache()
    private init() {}

    private var cache = NSCache<NSString, UIImage>()
    private var cacheHits = 0
    private var cacheMisses = 0
    
    init(countLimit: Int = 100) {
        cache.countLimit = countLimit
        print("📊 Image cache initialized with limit: \(countLimit)")
    }

    func getImage(forKey key: String) -> UIImage? {
        let image = cache.object(forKey: key as NSString)
        if image != nil {
            cacheHits += 1
            print("📈 Cache hit (\(cacheHits) total) - Key: \(key)")
        } else {
            cacheMisses += 1
            print("📉 Cache miss (\(cacheMisses) total) - Key: \(key)")
        }
        return image
    }

    func setImage(_ image: UIImage, forKey key: String) {
        print("💾 Caching image - Key: \(key)")
        cache.setObject(image, forKey: key as NSString)
    }
    
    func removeImage(forKey key: String) {
        print("🗑️ Removing image from cache - Key: \(key)")
        cache.removeObject(forKey: key as NSString)
    }
    
    func clear() {
        print("🧹 Clearing entire image cache")
        cache.removeAllObjects()
        cacheHits = 0
        cacheMisses = 0
    }
    
    func getCacheStats() -> String {
        let total = cacheHits + cacheMisses
        let hitRate = total > 0 ? Double(cacheHits) / Double(total) * 100 : 0
        return String(format: "Cache Stats - Hits: %d, Misses: %d, Hit Rate: %.1f%%", cacheHits, cacheMisses, hitRate)
    }
}

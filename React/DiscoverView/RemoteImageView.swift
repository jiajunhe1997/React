//
//  RemoteImageView.swift
//  React
//
//  Created by 何佳駿 on 2024/10/30.
//

import SwiftUI

struct RemoteImageView: View {
    @StateObject private var imageLoader = ImageLoader()
    let thumbnailURL: URL
    let originalURL: URL
    let isFavorite: Bool
    let onCopy: (UIImage) -> Void
    let onFavorite: () -> Void

    @State private var isDimmed = false
    @State private var isTapped = false
    @State private var isZoomed = false

    var body: some View {
        VStack {
            if let image = imageLoader.image {
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    
                    // Black overlay for dimming effect
                    Color.black
                        .opacity(isTapped ? 0.5 : 0)
                }
                .onTapGesture {
                    // Copy the original image
                    copyOriginalImage()
                    // Haptic Feedback
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()

                    // Trigger dimming effect without animation
                    isTapped = true
                    
                    // Reset dimming effect after 0.5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isTapped = false
                    }
                }
                .contextMenu {
                    Button(action: {
                        isZoomed = true
                    }) {
                        Label(NSLocalizedString("Zoom", comment: "Zoom into the image"), systemImage: "magnifyingglass")
                    }
                }
                .fullScreenCover(isPresented: $isZoomed) {
                    OnlineZoomedImageView(imageURL: originalURL, isPresented: $isZoomed)
                }
            } else {
                ProgressView()
            }
            // Favorite Button
            Button(action: onFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(isFavorite ? .red : .gray)
            }
        }
        .onAppear {
            imageLoader.loadImage(from: thumbnailURL)
        }
        .animation(nil) // Disable all animations for this view
    }

    private func copyOriginalImage() {
        ImageLoader.shared.loadImage(from: originalURL) { image in
            if let image = image {
                onCopy(image)
            } else {
                print("Failed to load original image for copying.")
            }
        }
    }
}

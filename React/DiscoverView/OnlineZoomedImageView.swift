//
//  OnlineZoomedImageView.swift
//  React
//
//  Created by 何佳駿 on 2024/10/30.
//

import SwiftUI
import Foundation


struct OnlineZoomedImageView: View {
    let imageURL: URL
    @Binding var isPresented: Bool
    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        VStack {
            if let image = image {
                OnlineZoomableScrollView {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            } else if isLoading {
                ProgressView()
            } else {
                Text("Failed to load image")
            }
        }
        .onAppear {
            ImageLoader.shared.loadImage(from: imageURL) { loadedImage in
                self.image = loadedImage
                self.isLoading = false
            }
        }
        .onTapGesture {
            isPresented = false
        }
    }
}


struct OnlineZoomableScrollView<Content: View>: UIViewRepresentable {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = WindowSizedZoomScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 5.0
        scrollView.minimumZoomScale = 1.0

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = true
        hostingController.view.frame = scrollView.bounds
        scrollView.zoomContent = hostingController.view
        scrollView.addSubview(hostingController.view)

        context.coordinator.hostingController = hostingController

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController?.view
        }
    }
}

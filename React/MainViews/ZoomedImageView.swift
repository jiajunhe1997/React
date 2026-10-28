import SwiftUI
import UIKit

struct ZoomedImageView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {            
            // Zoomable image
            ZoomableScrollView {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .onTapGesture {
                    isPresented = false
            }
            .edgesIgnoringSafeArea(.all)
        }
        .transition(.slide)
        .animation(.easeInOut, value: isPresented)
    }
}

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 5.0
        scrollView.minimumZoomScale = 1.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.bounces = true

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = true
        hostingController.view.frame = UIScreen.main.bounds
        scrollView.addSubview(hostingController.view)

        context.coordinator.hostingController = hostingController

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // No need to update the view
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController?.view
        }
        
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            // Center the content while zooming
            let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
            scrollView.contentInset = UIEdgeInsets(top: offsetY, left: offsetX, bottom: 0, right: 0)
        }
    }
}

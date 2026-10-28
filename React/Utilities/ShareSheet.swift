import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    var completion: (() -> Void)? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        
        // Configure completion handler if provided
        controller.completionWithItemsHandler = { _, _, _, _ in
            completion?()
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No need for update logic in this case
    }
    
    static func dismantleUIViewController(_ uiViewController: UIActivityViewController, coordinator: ()) {
        // Optional: Cleanup if necessary
    }
    
    class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            // Handle sheet dismissal if necessary
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}

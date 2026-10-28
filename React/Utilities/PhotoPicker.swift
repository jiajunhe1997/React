import SwiftUI
import PhotosUI
import UIKit

// MARK: - PhotoPicker Wrapper
struct PhotoPicker: UIViewControllerRepresentable {
    var onImagesPicked: ([UIImage]) -> Void // Update to handle multiple images
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImagesPicked: onImagesPicked)
    }
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        
        configuration.selectionLimit = 0 // Unlimited selection for everyone.


        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    // MARK: - Coordinator
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var onImagesPicked: ([UIImage]) -> Void
        
        init(onImagesPicked: @escaping ([UIImage]) -> Void) {
            self.onImagesPicked = onImagesPicked
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true, completion: nil)
            
            var pickedImages = [UIImage]()
            let dispatchGroup = DispatchGroup()
            
            for result in results {
                guard result.itemProvider.canLoadObject(ofClass: UIImage.self) else { continue }
                
                dispatchGroup.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { (image, error) in
                    DispatchQueue.main.async {
                        if let image = image as? UIImage {
                            pickedImages.append(image)
                        }
                        dispatchGroup.leave()
                    }
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                self.onImagesPicked(pickedImages) // Return all picked images
            }
        }
    }
}

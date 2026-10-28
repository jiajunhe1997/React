import Foundation
import UIKit
import CryptoKit

struct ImageUtils {
    /// Computes the SHA256 hash for a given UIImage.
    static func computeHash(for image: UIImage) -> String? {
        guard let data = image.pngData() else { return nil }
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

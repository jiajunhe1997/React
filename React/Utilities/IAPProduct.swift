import Foundation

struct IAPProduct {
    static let fullVersion = "UnlockPro"
    
    /// A list of all product IDs available in the app.
    static var allProductIDs: [String] {
        return [fullVersion]
    }
}

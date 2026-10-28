import StoreKit
import Combine
import UIKit

class StoreManager: ObservableObject {
    @Published var isFullVersionPurchased: Bool = false
    @Published var purchaseError: String? = nil // To hold error messages for the UI
    @Published var isPurchasing: Bool = false // New property to track purchase progress

    static let shared = StoreManager()

    private let purchaseKey = "isFullVersionPurchased"
    private let fullVersionProductID = IAPProduct.fullVersion
    private var cancellables = Set<AnyCancellable>()

    private init() {

        #if DEBUG
        isFullVersionPurchased = true
        #else
        $isFullVersionPurchased
            .receive(on: DispatchQueue.main)
            .assign(to: &$isFullVersionPurchased)
        #endif
        
        // Observe purchase errors
        $purchaseError
            .sink { error in
                if let error = error {
                    print("Purchase Error: \(error)")
                }
            }
            .store(in: &cancellables)
        
        // Check existing entitlements when StoreManager is initialized
        Task {
            await checkPurchasedProducts()
        }
        
        // Listen for new transactions using async-await
        Task {
            for await verificationResult in Transaction.updates {
                guard case let .verified(transaction) = verificationResult else {
                    print("Transaction unverified or failed verification.")
                    continue
                }
                await handleTransaction(transaction)
            }
        }
        
        // Set the app icon based on saved purchase state
        DispatchQueue.main.async {
            self.updateAppIcon()
        }
        
        #if DEBUG
        Task {
            await updatePurchaseState(true)
        }
        #else

        #endif
    }

    /// Updates the app icon based on purchase status
    func updateAppIcon() {
        let iconName = isFullVersionPurchased ? "AppIcon-Pro" : nil // nil reverts to primary icon
        
        // Check if the desired icon is already set to avoid unnecessary changes
        if UIApplication.shared.alternateIconName == iconName {
            print("Desired app icon is already set.")
            return
        }
        
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                print("Failed to change app icon: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.purchaseError = "Failed to change app icon: \(error.localizedDescription)"
                }
            } else {
                print("App icon successfully changed to \(iconName ?? "Default")")
            }
        }
    }
    
    /// Initiates the purchase process for the full version.
    func purchaseFullVersion() async throws {
        try await purchaseFullVersionInternal()
    }
    
    private func purchaseFullVersionInternal() async throws {
        guard let product = try await fetchProduct() else {
            print("Purchase failed: Product not found")
            throw StoreError.productNotFound
        }

        print("Attempting to purchase product: \(product.id)")
        
        // Set isPurchasing to true before initiating the purchase
        DispatchQueue.main.async {
            self.isPurchasing = true
        }
        
        // Defer block to ensure isPurchasing is set to false when exiting the method
        defer {
            DispatchQueue.main.async {
                self.isPurchasing = false
            }
        }
        
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verificationResult):
                if case let .verified(transaction) = verificationResult {
                    print("Purchase successful: \(transaction.productID)")
                    await updatePurchaseState(true)
                } else {
                    print("Purchase failed: Transaction unverified")
                    throw StoreError.unverifiedTransaction
                }
            case .userCancelled:
                print("Purchase cancelled by user.")
                throw StoreError.userCancelled
            case .pending:
                print("Purchase is pending.")
                // Optionally handle pending state here
                break
            @unknown default:
                print("Purchase failed: Unknown error.")
                throw StoreError.unknown
            }
        } catch {
            // Capture and throw detailed error information
            if let storeKitError = error as? SKError {
                print("StoreKit Error (\(storeKitError.code.rawValue)): \(storeKitError.localizedDescription)")
                throw StoreError.storeKitError(storeKitError)
            } else {
                print("Unexpected Error: \(error.localizedDescription)")
                throw StoreError.unknown
            }
        }
    }

    /// Fetches the product from the App Store.
    private func fetchProduct() async throws -> Product? {
        let products = try await Product.products(for: IAPProduct.allProductIDs)
        if products.isEmpty {
            print("No products found for IDs: \(IAPProduct.allProductIDs)")
        } else {
            print("Fetched products: \(products.map { $0.id })")
        }
        return products.first { $0.id == fullVersionProductID }
    }

    /// Checks existing entitlements to update purchase state.
    private func checkPurchasedProducts() async {
        print("Checking existing entitlements...")
        for await result in Transaction.currentEntitlements {
            if case let .verified(transaction) = result, transaction.productID == fullVersionProductID {
                print("Entitlement found for product: \(transaction.productID)")
                await updatePurchaseState(true)
            }
        }
        print("Entitlement check completed.")
    }

    /// Handles incoming transactions
    @MainActor
    private func handleTransaction(_ transaction: Transaction) async {
        if transaction.productID == fullVersionProductID {
            updatePurchaseState(true)
            print("Handled transaction for product: \(transaction.productID)")
        }
        // In StoreKit 2, finishing the transaction is optional
        // await transaction.finish() // Consider commenting this out
    }

    /// Updates the purchase state and saves it to UserDefaults.
    @MainActor
    private func updatePurchaseState(_ purchased: Bool) {
        self.isFullVersionPurchased = purchased
        UserDefaults.standard.set(purchased, forKey: purchaseKey)
        print("Purchase state updated to: \(purchased)")
        if let sharedDefaults = UserDefaults(suiteName: "group.com.PictoBoard.app") {
            sharedDefaults.set(purchased, forKey: "isFullVersionPurchased")
            sharedDefaults.synchronize()
        }
    }

    /// Saves the purchase state to UserDefaults.
    private func savePurchaseState(_ purchased: Bool) {
        UserDefaults.standard.set(purchased, forKey: purchaseKey)
        print("Purchase state saved to UserDefaults: \(purchased)")
    }
    
    /// Restores all previous purchases.
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkPurchasedProducts()
            print("Purchases restored successfully.")
        } catch {
            print("Failed to restore purchases: \(error.localizedDescription)")
        }
    }

    enum StoreError: LocalizedError {
        case productNotFound
        case unverifiedTransaction
        case userCancelled
        case unknown
        case storeKitError(SKError)

        var errorDescription: String? {
            switch self {
            case .productNotFound:
                return "Product not found."
            case .unverifiedTransaction:
                return "Transaction could not be verified."
            case .userCancelled:
                return "Purchase was cancelled by the user."
            case .unknown:
                return "An unknown error occurred."
            case .storeKitError(let error):
                return "StoreKit Error (\(error.code.rawValue)): \(error.localizedDescription)"
            }
        }
    }
}

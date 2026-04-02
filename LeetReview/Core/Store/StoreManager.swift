import Foundation
import Observation
import StoreKit

/// Manages the "Remove Ads" one-time IAP using StoreKit 2.
///
/// Product ID is configured in App Store Connect.
/// Default: `com.leetreview.removeads` ($4.99 one-time).
@Observable
@MainActor
final class StoreManager {
    static let removeAdsProductID = "com.leetreview.removeads"

    private(set) var removeAdsProduct: Product?
    private(set) var isPurchased = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private var transactionListener: Task<Void, Never>?

    init() {
        // Defer product loading to avoid blocking app launch
        transactionListener = listenForTransactions()
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        Task {
            await loadProducts()
            await checkPurchaseStatus()
        }
    }

    private var hasStarted = false

    func cancelListener() {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        do {
            let products = try await Product.products(for: [Self.removeAdsProductID])
            removeAdsProduct = products.first
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Purchase

    func purchaseRemoveAds() async {
        guard let product = removeAdsProduct else {
            errorMessage = "Product not available."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                isPurchased = true
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil

        try? await AppStore.sync()
        await checkPurchaseStatus()

        if !isPurchased {
            errorMessage = "No purchases to restore."
        }

        isLoading = false
    }

    // MARK: - Check Status

    func checkPurchaseStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.removeAdsProductID {
                isPurchased = true
                return
            }
        }
        // If we get here, no valid entitlement was found
        // Only reset if we haven't already set it to true
        if !isPurchased {
            isPurchased = false
        }
    }

    var shouldShowAds: Bool {
        !isPurchased
    }

    var priceString: String {
        removeAdsProduct?.displayPrice ?? "$4.99"
    }

    // MARK: - Private

    private func listenForTransactions() -> Task<Void, Never> {
        let productID = Self.removeAdsProductID
        return Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result,
                   transaction.productID == productID {
                    await MainActor.run { [weak self] in
                        self?.isPurchased = true
                    }
                    await transaction.finish()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}

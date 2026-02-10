//
//  StoreManager.swift
//  OKViewUpsell
//
//  StoreKit 2 purchase handler for OKVideo Pro.
//

import Combine
import StoreKit

// MARK: - Product Identifiers
// ┌──────────────────────────────────────────────────────────┐
// │  TODO: Replace these strings with your actual App Store  │
// │  Connect product identifiers before shipping.            │
// └──────────────────────────────────────────────────────────┘

enum OKVideoProductID {
    /// The new "unlock everything" bundle IAP
    static let pro       = "com.okvideo.pro"

    /// Existing individual IAPs
    static let projects  = "com.okvideo.projects"   // multiple projects  – €2.99
    static let watermark = "com.okvideo.watermark"   // remove watermark   – €1.99
    static let editor    = "com.okvideo.editor"      // timeline editor    – €3.99

    static let all: [String] = [pro, projects, watermark, editor]
    static let individuals: [String] = [projects, watermark, editor]
}

// MARK: - Store Manager

@MainActor
final class StoreManager: ObservableObject {

    // MARK: State

    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var transactionListener: Task<Void, Never>?

    // MARK: Computed

    /// The bundle product.
    var proProduct: Product? { products[OKVideoProductID.pro] }

    /// Individual products in display order.
    var individualProducts: [Product] {
        OKVideoProductID.individuals.compactMap { products[$0] }
    }

    /// True when the user owns everything (bundle OR all three individuals).
    var isFullyUnlocked: Bool {
        purchasedProductIDs.contains(OKVideoProductID.pro)
        || OKVideoProductID.individuals.allSatisfy { purchasedProductIDs.contains($0) }
    }

    /// Whether a specific feature is unlocked (via bundle or individual purchase).
    func isPurchased(_ productID: String) -> Bool {
        purchasedProductIDs.contains(productID)
        || purchasedProductIDs.contains(OKVideoProductID.pro)
    }

    /// Savings percentage of the bundle vs. buying all three individually.
    var savingsPercentage: Int {
        let total = individualProducts.reduce(Decimal.zero) { $0 + $1.price }
        guard let proPrice = proProduct?.price, total > 0 else { return 0 }
        let fraction = NSDecimalNumber(decimal: proPrice / total).doubleValue
        return max(0, Int(((1.0 - fraction) * 100).rounded()))
    }

    /// Formatted sum of all individual prices (for strikethrough display).
    var individualTotalFormatted: String? {
        let total = individualProducts.reduce(Decimal.zero) { $0 + $1.price }
        guard total > 0, let ref = individualProducts.first else { return nil }
        return total.formatted(ref.priceFormatStyle)
    }

    // MARK: Init

    init() {
        transactionListener = listenForTransactions()
        Task { await checkEntitlements() }
    }

    // No deinit needed: the task holds [weak self], so it becomes
    // inert once this object is deallocated. In practice StoreManager
    // is typically long-lived (app-scoped).

    // MARK: Load Products

    func loadProducts() async {
        guard products.isEmpty || errorMessage != nil else { return }
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await Product.products(for: OKVideoProductID.all)
            for product in fetched {
                products[product.id] = product
            }
        } catch {
            errorMessage = "Unable to load products. Please check your connection."
            print("StoreManager: Failed to load products – \(error)")
        }
        isLoading = false
    }

    // MARK: Purchase

    @discardableResult
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await checkEntitlements()
            return transaction
        case .userCancelled, .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    // MARK: Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await checkEntitlements()
        } catch {
            errorMessage = "Unable to restore purchases."
            print("StoreManager: Restore failed – \(error)")
        }
    }

    // MARK: Entitlements

    private func checkEntitlements() async {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                ids.insert(transaction.productID)
            }
        }
        purchasedProductIDs = ids
    }

    // MARK: Transaction Updates

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? self?.checkVerified(result) {
                    await transaction.finish()
                    await self?.checkEntitlements()
                }
            }
        }
    }

    // MARK: Verification

    // Pure function — safe to call from any isolation context
    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let value):
            return value
        }
    }
}

// MARK: - Errors

enum StoreError: LocalizedError {
    case failedVerification
    var errorDescription: String? { "Transaction verification failed." }
}

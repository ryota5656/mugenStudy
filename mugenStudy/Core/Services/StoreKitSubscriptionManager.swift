import Foundation
import StoreKit
internal import Combine

@MainActor
final class StoreKitSubscriptionManager: ObservableObject {
    static let shared = StoreKitSubscriptionManager()
    
    private let productIds: Set<String> = ["mutenStudyAPP.plus"]
    
    @Published var products: [Product] = []
    @Published var isSubscribed: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastErrorMessage: String?
    
    private var updatesTask: Task<Void, Never>?
    
    private init() {
        updatesTask = Task { [weak self] in
            guard let self else { return }
            for await _ in Transaction.updates {
                await self.updateSubscriptionStatus()
            }
        }
        Task { await updateSubscriptionStatus() }
    }
    
    deinit {
        updatesTask?.cancel()
    }
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await Product.products(for: Array(productIds))
            // サブスクのみ
            products = fetched.filter { $0.type == .autoRenewable }
        } catch {
            print("Productの読み込みに失敗😭")
            lastErrorMessage = error.localizedDescription
        }
    }
    
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateSubscriptionStatus()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
    
    func updateSubscriptionStatus() async {
        var active = false
        for await entitlement in Transaction.currentEntitlements {
            do {
                let txn = try checkVerified(entitlement)
                if txn.productType == .autoRenewable,
                   productIds.contains(txn.productID) {
                    active = true
                    break
                }
            } catch {
                // 検証失敗は無視して次へ
                continue
            }
        }
        isSubscribed = active
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "StoreKitVerification", code: -1, userInfo: [NSLocalizedDescriptionKey: "トランザクションの検証に失敗しました"])
        case .verified(let safe):
            return safe
        }
    }
}



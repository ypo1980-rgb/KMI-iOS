import Foundation
import StoreKit
import Combine

@MainActor
final class BillingRepository: ObservableObject {

    struct SubscriptionState {
        var connected: Bool = false
        var active: Bool = false
        var productId: String? = nil
        var purchaseToken: String? = nil
        var error: String? = nil
        var isLoading: Bool = false
    }

    enum ProductId: String, CaseIterable {
        case monthly = "kmi_monthly"
        case yearly = "kmi_yearly"
        case perBelt = "kmi_per_belt"
    }

    @Published private(set) var state = SubscriptionState()
    @Published private(set) var products: [Product] = []

    private var updatesTask: Task<Void, Never>?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    deinit {
        updatesTask?.cancel()
    }

    func start() {
        guard updatesTask == nil else { return }

        updatesTask = Task { [weak self] in
            guard let self else { return }
            await self.observeTransactions()
        }

        Task {
            await loadProducts()
            await refreshPurchases()
        }
    }

    func loadProducts() async {
        state.isLoading = true
        state.error = nil

        do {
            let ids = ProductId.allCases.map(\.rawValue)
            let loaded = try await Product.products(for: ids)
            products = loaded.sorted { lhs, rhs in
                lhs.id < rhs.id
            }
            state.connected = true
        } catch {
            state.connected = false
            state.error = error.localizedDescription
        }

        state.isLoading = false
    }

    func product(for productId: String) -> Product? {
        products.first(where: { $0.id == productId })
    }

    func purchase(productId: String) async {
        guard let product = product(for: productId) else {
            state.error = "המוצר לא נטען עדיין"
            return
        }

        state.isLoading = true
        state.error = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await apply(transaction: transaction)
                await transaction.finish()

            case .userCancelled:
                break

            case .pending:
                state.error = "הרכישה ממתינה לאישור"

            @unknown default:
                state.error = "סטטוס רכישה לא מוכר"
            }
        } catch {
            state.error = error.localizedDescription
        }

        state.isLoading = false
    }

    func restorePurchases() async {
        state.isLoading = true
        state.error = nil

        do {
            try await AppStore.sync()
            await refreshPurchases()
        } catch {
            state.error = error.localizedDescription
        }

        state.isLoading = false
    }

    func refreshPurchases() async {
        state.error = nil

        var activeTransaction: Transaction?

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)

                if ProductId.allCases.map(\.rawValue).contains(transaction.productID) {
                    activeTransaction = transaction
                    break
                }
            } catch {
                state.error = error.localizedDescription
            }
        }

        if let transaction = activeTransaction {
            await apply(transaction: transaction)
        } else {
            defaults.removeObject(forKey: "sub_product")
            defaults.removeObject(forKey: "sub_token")
            KmiAccess.setFullAccess(false, defaults: defaults)

            state.active = false
            state.productId = nil
            state.purchaseToken = nil
        }
    }

    private func observeTransactions() async {
        for await result in Transaction.updates {
            do {
                let transaction = try checkVerified(result)
                await apply(transaction: transaction)
                await transaction.finish()
            } catch {
                state.error = error.localizedDescription
            }
        }
    }

    private func apply(transaction: Transaction) async {
        defaults.set(transaction.productID, forKey: "sub_product")
        defaults.set(String(transaction.originalID), forKey: "sub_token")
        KmiAccess.setFullAccess(true, defaults: defaults)

        state.connected = true
        state.active = true
        state.productId = transaction.productID
        state.purchaseToken = String(transaction.originalID)
        state.error = nil
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw NSError(
                domain: "BillingRepository",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "רכישה לא אומתה"]
            )
        }
    }
}

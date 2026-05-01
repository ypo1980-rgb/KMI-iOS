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

        // התאמה לאנדרואיד: מחירים ומצב טעינת מוצרים
        var monthlyPriceText: String? = nil
        var yearlyPriceText: String? = nil
        var productsLoaded: Bool = false
        var loadedProductIds: [String] = []
    }

    enum ProductId: String, CaseIterable {
        case regularMonthly = "regular_monthly"
        case regularYearly = "regular_yearly"
        case memberMonthly = "member_monthly"
        case memberYearly = "member_yearly"

        var isMemberProduct: Bool {
            switch self {
            case .memberMonthly, .memberYearly:
                return true
            case .regularMonthly, .regularYearly:
                return false
            }
        }

        var isYearlyProduct: Bool {
            switch self {
            case .regularYearly, .memberYearly:
                return true
            case .regularMonthly, .memberMonthly:
                return false
            }
        }

        var isMonthlyProduct: Bool {
            !isYearlyProduct
        }

        static func resolveMonthlyProduct(isAssociationMember: Bool) -> ProductId {
            isAssociationMember ? .memberMonthly : .regularMonthly
        }

        static func resolveYearlyProduct(isAssociationMember: Bool) -> ProductId {
            isAssociationMember ? .memberYearly : .regularYearly
        }

        static func resolveProduct(
            isAssociationMember: Bool,
            isYearly: Bool
        ) -> ProductId {
            isYearly
            ? resolveYearlyProduct(isAssociationMember: isAssociationMember)
            : resolveMonthlyProduct(isAssociationMember: isAssociationMember)
        }
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

            let loadedIds = products.map(\.id)

            state.connected = true
            state.productsLoaded = !loadedIds.isEmpty
            state.loadedProductIds = loadedIds
            state.error = loadedIds.isEmpty
            ? "No subscription products loaded from App Store"
            : nil

            refreshPriceState()
        } catch {
            state.connected = false
            state.productsLoaded = false
            state.loadedProductIds = []
            state.error = error.localizedDescription
        }

        state.isLoading = false
    }

    func product(for productId: String) -> Product? {
        products.first(where: { $0.id == productId })
    }

    func getPriceForProduct(_ productId: String) -> String? {
        product(for: productId)?.displayPrice
    }

    private func refreshPriceState() {
        state.monthlyPriceText = getPriceForProduct(ProductId.regularMonthly.rawValue)
        state.yearlyPriceText = getPriceForProduct(ProductId.regularYearly.rawValue)
    }

    func purchase(productId: String) async {
        guard let product = product(for: productId) else {
            state.error = "Product not loaded from App Store: \(productId)"
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
            writeAccessEverywhere(
                enabled: false,
                productId: nil,
                purchaseToken: nil,
                purchaseDate: nil
            )

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
        let token = String(transaction.originalID)

        writeAccessEverywhere(
            enabled: true,
            productId: transaction.productID,
            purchaseToken: token,
            purchaseDate: transaction.purchaseDate
        )

        state.connected = true
        state.active = true
        state.productId = transaction.productID
        state.purchaseToken = token
        state.error = nil

        refreshPriceState()
    }

    private func writeAccessEverywhere(
        enabled: Bool,
        productId: String?,
        purchaseToken: String?,
        purchaseDate: Date?
    ) {
        let nowMillis = currentTimeMillis()
        let accessUntil = enabled
        ? calculateAccessUntilForSubscription(
            productId: productId ?? "",
            purchaseDate: purchaseDate ?? Date()
        )
        : 0

        KmiAccess.setFullAccess(enabled, defaults: defaults)

        defaults.set(enabled, forKey: "full_access")
        defaults.set(enabled, forKey: "has_full_access")
        defaults.set(enabled, forKey: "subscription_active")
        defaults.set(enabled, forKey: "is_subscribed")
        defaults.set(enabled, forKey: "app_store_subscription_verified")
        defaults.set(nowMillis, forKey: "app_store_subscription_checked_at")
        defaults.set(productId ?? "", forKey: "sub_product")
        defaults.set(purchaseToken ?? "", forKey: "sub_token")
        defaults.set(purchaseDateMillis(purchaseDate), forKey: "sub_purchase_time")
        defaults.set(accessUntil, forKey: "sub_access_until")
        defaults.set(nowMillis, forKey: "access_changed_at")
    }

    private func calculateAccessUntilForSubscription(
        productId: String,
        purchaseDate: Date
    ) -> Int64 {
        let now = currentTimeMillis()

        // בדיקות פנימיות: חודשי = 5 דקות, שנתי = 30 דקות.
        // לפני הפצה אמיתית אפשר לשנות ל-false.
        let forceShortTestExpiry = true

        if forceShortTestExpiry {
            let testDurationMillis: Int64

            if ProductId.regularYearly.rawValue == productId ||
                ProductId.memberYearly.rawValue == productId {
                testDurationMillis = 30 * 60 * 1000
            } else {
                testDurationMillis = 5 * 60 * 1000
            }

            return now + testDurationMillis
        }

        let productionDurationMillis: Int64

        if ProductId.regularYearly.rawValue == productId ||
            ProductId.memberYearly.rawValue == productId {
            productionDurationMillis = 370 * 24 * 60 * 60 * 1000
        } else {
            productionDurationMillis = 31 * 24 * 60 * 60 * 1000
        }

        return now + productionDurationMillis
    }

    private func purchaseDateMillis(_ date: Date?) -> Int64 {
        guard let date else { return 0 }
        return Int64(date.timeIntervalSince1970 * 1000)
    }

    private func currentTimeMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
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

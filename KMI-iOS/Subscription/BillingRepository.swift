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
        var renewalDate: Int64? = nil
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
                productSortRank(lhs.id) < productSortRank(rhs.id)
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

    private func productSortRank(_ productId: String) -> Int {
        switch productId {
        case ProductId.regularMonthly.rawValue:
            return 0
        case ProductId.regularYearly.rawValue:
            return 1
        case ProductId.memberMonthly.rawValue:
            return 2
        case ProductId.memberYearly.rawValue:
            return 3
        default:
            return 99
        }
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
            state.renewalDate = nil
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

        let accessUntil = writeAccessEverywhere(
            enabled: true,
            productId: transaction.productID,
            purchaseToken: token,
            purchaseDate: transaction.purchaseDate
        )

        let active = accessUntil > currentTimeMillis()

        state.connected = true
        state.active = active
        state.productId = active ? transaction.productID : nil
        state.purchaseToken = active ? token : nil
        state.renewalDate = active ? accessUntil : nil
        state.error = nil

        refreshPriceState()
    }

    @discardableResult
    private func writeAccessEverywhere(
        enabled: Bool,
        productId: String?,
        purchaseToken: String?,
        purchaseDate: Date?
    ) -> Int64 {
        let nowMillis = currentTimeMillis()
        let currentToken = purchaseToken ?? ""
        let existingToken = defaults.string(forKey: "sub_token") ?? ""
        let existingAccessUntil = Int64(defaults.integer(forKey: "sub_access_until"))
        let expiredToken = defaults.string(forKey: "expired_sub_token") ?? ""
        let lastToken = defaults.string(forKey: "last_sub_token") ?? ""

        let accessUntil: Int64

        if enabled {
            let isSamePurchaseToken =
                !currentToken.isEmpty &&
                existingToken == currentToken

            let isExpiredPurchaseToken =
                !currentToken.isEmpty &&
                expiredToken == currentToken

            let wasLastTokenAlreadyClosed =
                !currentToken.isEmpty &&
                lastToken == currentToken &&
                existingToken.isEmpty &&
                existingAccessUntil == 0

            if isExpiredPurchaseToken || wasLastTokenAlreadyClosed {
                accessUntil = 0
            } else if isSamePurchaseToken && existingAccessUntil > nowMillis {
                accessUntil = existingAccessUntil
            } else if isSamePurchaseToken && existingAccessUntil > 0 && existingAccessUntil <= nowMillis {
                closeExpiredAccessForToken(
                    expiredToken: currentToken,
                    expiredUntil: existingAccessUntil,
                    expiredProduct: productId
                )
                return 0
            } else {
                accessUntil = calculateAccessUntilForSubscription(
                    productId: productId ?? "",
                    purchaseDate: purchaseDate ?? Date()
                )
            }
        } else {
            accessUntil = 0
        }

        let finalEnabled = enabled && accessUntil > nowMillis

        KmiAccess.setFullAccess(finalEnabled, defaults: defaults)

        defaults.set(finalEnabled, forKey: "full_access")
        defaults.set(finalEnabled, forKey: "has_full_access")
        defaults.set(finalEnabled, forKey: "subscription_active")
        defaults.set(finalEnabled, forKey: "is_subscribed")

        // iOS מקור האמת
        defaults.set(finalEnabled, forKey: "app_store_subscription_verified")
        defaults.set(nowMillis, forKey: "app_store_subscription_checked_at")

        // תאימות זמנית לקוד קיים שקורא גם google_subscription_verified
        defaults.set(finalEnabled, forKey: "google_subscription_verified")
        defaults.set(nowMillis, forKey: "google_subscription_checked_at")

        defaults.set(finalEnabled ? (productId ?? "") : "", forKey: "sub_product")
        defaults.set(finalEnabled ? currentToken : "", forKey: "sub_token")
        defaults.set(finalEnabled ? purchaseDateMillis(purchaseDate) : 0, forKey: "sub_purchase_time")
        defaults.set(finalEnabled ? accessUntil : 0, forKey: "sub_access_until")

        if !currentToken.isEmpty {
            defaults.set(currentToken, forKey: "last_sub_token")
        }

        defaults.set(productId ?? "", forKey: "last_sub_product")
        defaults.set(nowMillis, forKey: "access_changed_at")
        defaults.synchronize()

        NotificationCenter.default.post(
            name: Notification.Name("KMI_ACCESS_CHANGED"),
            object: nil
        )

        return finalEnabled ? accessUntil : 0
    }

    private func closeExpiredAccessForToken(
        expiredToken: String,
        expiredUntil: Int64,
        expiredProduct: String?
    ) {
        let nowMillis = currentTimeMillis()

        KmiAccess.setFullAccess(false, defaults: defaults)

        defaults.set(false, forKey: "full_access")
        defaults.set(false, forKey: "has_full_access")
        defaults.set(false, forKey: "subscription_active")
        defaults.set(false, forKey: "is_subscribed")
        defaults.set(false, forKey: "app_store_subscription_verified")
        defaults.set(false, forKey: "google_subscription_verified")
        defaults.set(nowMillis, forKey: "app_store_subscription_checked_at")
        defaults.set(nowMillis, forKey: "google_subscription_checked_at")

        defaults.set(expiredToken, forKey: "expired_sub_token")
        defaults.set(expiredUntil, forKey: "expired_sub_access_until")
        defaults.set(expiredProduct ?? "", forKey: "expired_sub_product")
        defaults.set(expiredToken, forKey: "last_sub_token")
        defaults.set(expiredProduct ?? "", forKey: "last_sub_product")

        defaults.removeObject(forKey: "sub_product")
        defaults.removeObject(forKey: "sub_token")
        defaults.removeObject(forKey: "sub_purchase_time")
        defaults.removeObject(forKey: "sub_access_until")

        defaults.set(nowMillis, forKey: "access_changed_at")
        defaults.synchronize()

        NotificationCenter.default.post(
            name: Notification.Name("KMI_ACCESS_CHANGED"),
            object: nil
        )
    }
    
    private func calculateAccessUntilForSubscription(
        productId: String,
        purchaseDate: Date
    ) -> Int64 {
        let purchaseMillis = purchaseDateMillis(purchaseDate)

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

            return purchaseMillis + testDurationMillis
        }

        let productionDurationMillis: Int64

        if ProductId.regularYearly.rawValue == productId ||
            ProductId.memberYearly.rawValue == productId {
            productionDurationMillis = 370 * 24 * 60 * 60 * 1000
        } else {
            productionDurationMillis = 31 * 24 * 60 * 60 * 1000
        }

        return purchaseMillis + productionDurationMillis
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

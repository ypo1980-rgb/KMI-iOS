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
                let transaction =
                    try checkVerified(
                        verification
                    )

                await apply(
                    transaction: transaction
                )

                await transaction.finish()

                /*
                 * קוראים שוב את הזכאויות לאחר סיום העסקה,
                 * כדי לוודא שגם state וגם UserDefaults
                 * משקפים את המנוי שאושר ב-App Store.
                 */
                await refreshPurchases()

            case .userCancelled:
                /*
                 * StoreKit מחזיר userCancelled גם כאשר חלון
                 * הרכישה נסגר לפני אישור מלא.
                 */
                state.error =
                    "StoreKit החזיר: הרכישה בוטלה לפני שהושלמה."

            case .pending:
                state.error =
                    "StoreKit החזיר: הרכישה ממתינה לאישור. ייתכן שנדרש אישור חשבון, אמצעי תשלום או אישור משפחתי."

            @unknown default:
                state.error =
                    "StoreKit החזיר סטטוס רכישה לא מוכר."
            }
        } catch {
            let nsError =
                error as NSError

            state.error =
                """
                שגיאת StoreKit:
                \(error.localizedDescription)
                קוד: \(nsError.domain) / \(nsError.code)
                """
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

        let supportedProductIds =
            Set(
                ProductId.allCases.map(
                    \.rawValue
                )
            )

        for await result in Transaction.currentEntitlements {
            do {
                let transaction =
                    try checkVerified(result)

                guard supportedProductIds.contains(
                    transaction.productID
                ) else {
                    continue
                }

                guard transaction.revocationDate == nil else {
                    continue
                }

                guard !transaction.isUpgraded else {
                    continue
                }

                if let expirationDate =
                    transaction.expirationDate,
                   expirationDate <= Date() {
                    continue
                }

                if let current =
                    activeTransaction {
                    let currentExpiration =
                        current.expirationDate ??
                        .distantFuture

                    let candidateExpiration =
                        transaction.expirationDate ??
                        .distantFuture

                    if candidateExpiration >
                        currentExpiration {
                        activeTransaction =
                            transaction
                    }
                } else {
                    activeTransaction =
                        transaction
                }
            } catch {
                state.error =
                    error.localizedDescription
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

    private func apply(
        transaction: Transaction
    ) async {
        /*
         * transaction.id הוא המזהה של העסקה הנוכחית.
         *
         * אין להשתמש כאן ב-originalID:
         * במנוי מתחדש originalID נשאר קבוע לכל שרשרת
         * המנוי, ולכן עסקת חידוש עלולה להיחשב בטעות
         * לעסקה ישנה שכבר פגה.
         */
        let token = String(transaction.id)

        let accessUntil = writeAccessEverywhere(
            enabled: true,
            productId: transaction.productID,
            purchaseToken: token,
            purchaseDate: transaction.purchaseDate,
            expirationDate: transaction.expirationDate
        )

        let active =
            accessUntil > currentTimeMillis()

        state.connected = true
        state.active = active
        state.productId =
            active
                ? transaction.productID
                : nil
        state.purchaseToken =
            active
                ? token
                : nil
        state.renewalDate =
            active
                ? accessUntil
                : nil

        state.error =
            active
                ? nil
                : "הרכישה אומתה, אך לא נמצא מנוי פעיל בתוקף"

        refreshPriceState()
    }

    @discardableResult
    private func writeAccessEverywhere(
        enabled: Bool,
        productId: String?,
        purchaseToken: String?,
        purchaseDate: Date?,
        expirationDate: Date? = nil
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
                    purchaseDate: purchaseDate ?? Date(),
                    expirationDate: expirationDate
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
        purchaseDate: Date,
        expirationDate: Date?
    ) -> Int64 {
        if let expirationDate {
            return purchaseDateMillis(expirationDate)
        }

        let purchaseMillis = purchaseDateMillis(purchaseDate)

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

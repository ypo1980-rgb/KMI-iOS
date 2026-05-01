import SwiftUI

struct SubscriptionScreen: View {

    let onBack: () -> Void
    let onOpenPlans: () -> Void
    let onOpenHome: () -> Void

    @StateObject private var repo = BillingRepository()

    @State private var isAdmin: Bool = KmiAccess.isAdmin()
    @State private var showDevDialog = false
    @State private var devCode = ""

    @AppStorage("kmi_app_language") private var kmiAppLanguageCode: String = "he"
    @AppStorage("app_language") private var appLanguageRaw: String = "HEBREW"
    @AppStorage("initial_language_code") private var initialLanguageCode: String = "HEBREW"

    private var isEnglish: Bool {
        let values = [
            kmiAppLanguageCode.lowercased(),
            appLanguageRaw.lowercased(),
            initialLanguageCode.lowercased()
        ]

        return values.contains("en") || values.contains("english")
    }

    private var screenLayoutDirection: LayoutDirection {
        isEnglish ? .leftToRight : .rightToLeft
    }

    private var primaryTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var horizontalTextAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var horizontalStackAlignment: HorizontalAlignment {
        isEnglish ? .leading : .trailing
    }

    private func tr(_ he: String, _ en: String) -> String {
        isEnglish ? en : he
    }

    var body: some View {
        VStack(spacing: 16) {
            if isAdmin {
                adminCard
            } else {
                subscriptionHeroCard
                statusCard

                premiumSubscriptionButton(
                    title: tr("רכוש / הארך מנוי", "Buy / renew subscription"),
                    onTap: onOpenPlans
                )
                
                Button(action: {
                    Task { await repo.restorePurchases() }
                }) {
                    Text(tr("שחזור רכישות", "Restore purchases"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .disabled(repo.state.isLoading || !repo.state.connected)

                Button(action: {
                    showDevDialog = true
                }) {
                    Text(tr("כניסת מנהל / קוד מפתח", "Admin / tester access code"))
                        .font(.subheadline.weight(.semibold))
                }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }

                Spacer()

            Button(action: onOpenHome) {
                Text(tr("חזרה למסך הבית", "Back to home"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)

        Button(action: onBack) {
            Text(tr("סגור", "Close"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        }
        .padding(16)
        .environment(\.layoutDirection, screenLayoutDirection)
        .task {
            isAdmin = KmiAccess.isAdmin()
            KmiAccess.ensureTrialStarted()
            repo.start()
        }
        .alert(tr("קוד גישה", "Access code"), isPresented: $showDevDialog) {
            SecureField(tr("קוד גישה", "Access code"), text: $devCode)

            Button(tr("אישור", "OK")) {
                let code = devCode.trimmingCharacters(in: .whitespacesAndNewlines)

                if KmiAccess.tryDevUnlock(code: code) {
                    // גישת מפתח מלאה בלי להפוך את המשתמש למנהל.
                    isAdmin = KmiAccess.isAdmin()
                    repo.start()
                }

                devCode = ""
            }

            Button(tr("בטל", "Cancel"), role: .cancel) {
                devCode = ""
            }
        } message: {
            Text(tr(
                "ניתן להזין קוד גישה לבודקים כדי לפתוח את האפליקציה ללא מנוי.",
                "Enter a tester access code to unlock the app without a subscription."
            ))
        }
    }

    private var subscriptionHeroCard: some View {
        VStack(spacing: 8) {
            Text(tr("מנוי KMI", "KMI Subscription"))
                .font(.title2.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)

            Text(tr(
                "כאן אפשר לבדוק סטטוס מנוי, לרכוש מנוי חדש או לשחזר רכישות קיימות.",
                "Here you can check your subscription status, purchase a new subscription, or restore previous purchases."
            ))
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white.opacity(0.92))
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.49, green: 0.23, blue: 0.93),
                            Color(red: 0.43, green: 0.16, blue: 0.85),
                            Color(red: 0.35, green: 0.13, blue: 0.71)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 14, x: 0, y: 8)
    }

    private var hasEffectiveFullAccess: Bool {
        KmiAccess.hasFullAccess()
    }

    private func planDisplayName(_ productId: String?) -> String {
        switch productId {
        case BillingRepository.ProductId.regularMonthly.rawValue:
            return tr("מנוי חודשי רגיל", "Regular monthly subscription")

        case BillingRepository.ProductId.regularYearly.rawValue:
            return tr("מנוי שנתי רגיל", "Regular yearly subscription")

        case BillingRepository.ProductId.memberMonthly.rawValue:
            return tr("מנוי חודשי לחבר עמותה", "Association monthly subscription")

        case BillingRepository.ProductId.memberYearly.rawValue:
            return tr("מנוי שנתי לחבר עמותה", "Association yearly subscription")

        case .some(let raw) where !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty:
            return raw

        default:
            return "-"
        }
    }

    private func premiumSubscriptionButton(
        title: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if isEnglish {
                    premiumCrownBubble
                    premiumButtonTitle(title)
                    premiumChevronBubble
                } else {
                    premiumChevronBubble
                    premiumButtonTitle(title)
                    premiumCrownBubble
                }
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.49, green: 0.23, blue: 0.93),
                                Color(red: 0.43, green: 0.16, blue: 0.85),
                                Color(red: 0.35, green: 0.13, blue: 0.71)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.30), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 12, x: 0, y: 7)
        }
        .buttonStyle(.plain)
    }

    private var premiumCrownBubble: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.14))

            Text("👑")
                .font(.system(size: 18))
        }
        .frame(width: 34, height: 34)
    }

    private var premiumChevronBubble: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.13))

            Image(systemName: isEnglish ? "chevron.right" : "chevron.left")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.white)
        }
        .frame(width: 34, height: 34)
    }

    private func premiumButtonTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.heavy))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }

    private func statusAccent(active: Bool) -> Color {
        active
        ? Color(red: 0.09, green: 0.46, blue: 0.24)
        : Color(red: 0.86, green: 0.15, blue: 0.15)
    }

    private func statusCardFill(active: Bool) -> Color {
        active
        ? Color(red: 0.94, green: 0.99, blue: 0.96)
        : Color(red: 1.00, green: 0.95, blue: 0.96)
    }

    private func statusIcon(active: Bool) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: active
                        ? [
                            Color(red: 0.82, green: 0.98, blue: 0.90),
                            Color(red: 0.93, green: 0.99, blue: 0.96)
                        ]
                        : [
                            Color(red: 1.00, green: 0.88, blue: 0.88),
                            Color(red: 1.00, green: 0.95, blue: 0.96)
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 34
                    )
                )

            Text(active ? "✓" : "!")
                .font(.title2.weight(.heavy))
                .foregroundStyle(statusAccent(active: active))
        }
        .frame(width: 58, height: 58)
    }

    private func statusTitleBlock(active: Bool) -> some View {
        VStack(alignment: horizontalStackAlignment, spacing: 4) {
            Text(active ? tr("גישה מלאה פעילה", "Full access active") : tr("אין מנוי פעיל", "No active subscription"))
                .font(.title3.weight(.heavy))
                .foregroundStyle(Color.black.opacity(0.86))
                .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                .multilineTextAlignment(primaryTextAlignment)

            Text(active ? tr("כל התכנים פתוחים עבורך", "All app content is available") : tr("חלק מהתכנים דורשים מנוי", "Some content requires a subscription"))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.55))
                .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                .multilineTextAlignment(primaryTextAlignment)
        }
    }

    private var statusCard: some View {
        let active = hasEffectiveFullAccess || repo.state.active

        return VStack(alignment: horizontalStackAlignment, spacing: 12) {
            HStack(spacing: 12) {
                if isEnglish {
                    statusIcon(active: active)
                    statusTitleBlock(active: active)
                } else {
                    statusTitleBlock(active: active)
                    statusIcon(active: active)
                }
            }
            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)

            if KmiAccess.isAdmin() {
                Text(tr("גישה מלאה: מנהל מערכת", "Full access: administrator"))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                    .multilineTextAlignment(primaryTextAlignment)
            } else if KmiAccess.hasDevUnlock() {
                Text(tr("גישה מלאה: קוד בודק פעיל", "Full access: tester code active"))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                    .multilineTextAlignment(primaryTextAlignment)
            } else if KmiAccess.hasFullAccess() {
                Text(tr("גישה מלאה: פעילה", "Full access: active"))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                    .multilineTextAlignment(primaryTextAlignment)
            } else if KmiAccess.isTrialActive() {
                Text(tr(
                    "ניסיון פעיל: \(KmiAccess.trialDaysLeft()) ימים נותרו",
                    "Trial active: \(KmiAccess.trialDaysLeft()) days left"
                ))
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                .multilineTextAlignment(primaryTextAlignment)
            } else {
                Text(tr("גישה מלאה: כבויה", "Full access: off"))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                    .multilineTextAlignment(primaryTextAlignment)
            }

            if KmiAccess.hasDevUnlock() {
                Button(action: {
                    KmiAccess.clearDevUnlock()
                    repo.start()
                }) {
                    Text(tr("בטל גישת בודק", "Disable tester access"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }

            Text("\(tr("מסלול", "Plan")): \(planDisplayName(repo.state.productId))")
                .font(.body)
                .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                .multilineTextAlignment(primaryTextAlignment)

            if let productId = repo.state.productId,
               !productId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("\(tr("מזהה מוצר", "Product ID")): \(productId)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                    .multilineTextAlignment(primaryTextAlignment)
            }

            if let token = repo.state.purchaseToken, !token.isEmpty {
                Text("\(tr("מזהה רכישה", "Purchase ID")): \(token)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                    .multilineTextAlignment(primaryTextAlignment)
            }

            if let error = repo.state.error, !error.isEmpty {
                Text("\(tr("שגיאה", "Error")): \(error)")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                    .multilineTextAlignment(primaryTextAlignment)
            }
        }
        .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(statusCardFill(active: active))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(statusAccent(active: active).opacity(0.20), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 5)
    }

    private var adminCard: some View {
        VStack(alignment: horizontalStackAlignment, spacing: 12) {
            Text(tr("מצב מנוי: מנהל מערכת", "Subscription status: administrator"))
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
                .multilineTextAlignment(primaryTextAlignment)

            Text(tr(
                "כמנהל מערכת כל התכנים באפליקציה פתוחים עבורך ואין צורך ברכישת מנוי.",
                "As an administrator, all app content is open for you and no subscription purchase is required."
            ))
            .font(.body.weight(.semibold))
            .foregroundStyle(.white.opacity(0.92))
            .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
            .multilineTextAlignment(primaryTextAlignment)

            Button(action: {
                KmiAccess.setAdmin(false)
                isAdmin = false
            }) {
                Text(tr("יציאה ממצב מנהל", "Exit administrator mode"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: horizontalTextAlignment)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.49, green: 0.23, blue: 0.93),
                            Color(red: 0.43, green: 0.16, blue: 0.85),
                            Color(red: 0.35, green: 0.13, blue: 0.71)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 7)
    }
}

#Preview {
    SubscriptionScreen(
        onBack: {},
        onOpenPlans: {},
        onOpenHome: {}
    )
}

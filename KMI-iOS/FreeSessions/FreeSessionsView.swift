import SwiftUI
import Combine
import UIKit
import MapKit
import Shared

private func kmiFreeAdaptiveColor(
    light: UIColor,
    dark: UIColor
) -> Color {
    Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? dark
                : light
        }
    )
}

private let kmiFreeBgTop = kmiFreeAdaptiveColor(
    light: UIColor(
        red: 248 / 255,
        green: 251 / 255,
        blue: 255 / 255,
        alpha: 1
    ),
    dark: UIColor(
        red: 15 / 255,
        green: 23 / 255,
        blue: 42 / 255,
        alpha: 1
    )
)

private let kmiFreeBgMid = kmiFreeAdaptiveColor(
    light: UIColor(
        red: 234 / 255,
        green: 244 / 255,
        blue: 255 / 255,
        alpha: 1
    ),
    dark: UIColor(
        red: 30 / 255,
        green: 41 / 255,
        blue: 59 / 255,
        alpha: 1
    )
)

private let kmiFreeBgBottom = kmiFreeAdaptiveColor(
    light: UIColor(
        red: 14 / 255,
        green: 165 / 255,
        blue: 215 / 255,
        alpha: 1
    ),
    dark: UIColor(
        red: 3 / 255,
        green: 105 / 255,
        blue: 161 / 255,
        alpha: 1
    )
)

private let kmiFreeCard = kmiFreeAdaptiveColor(
    light: UIColor(
        red: 247 / 255,
        green: 251 / 255,
        blue: 255 / 255,
        alpha: 0.97
    ),
    dark: UIColor(
        red: 15 / 255,
        green: 23 / 255,
        blue: 42 / 255,
        alpha: 0.96
    )
)

private let kmiFreeCardSoft = kmiFreeAdaptiveColor(
    light: UIColor.white,
    dark: UIColor(
        red: 30 / 255,
        green: 41 / 255,
        blue: 59 / 255,
        alpha: 1
    )
)

private let kmiFreeBorder = kmiFreeAdaptiveColor(
    light: UIColor(
        red: 191 / 255,
        green: 215 / 255,
        blue: 239 / 255,
        alpha: 1
    ),
    dark: UIColor(
        red: 125 / 255,
        green: 211 / 255,
        blue: 252 / 255,
        alpha: 0.24
    )
)

private let kmiFreeBorderStrong = kmiFreeAdaptiveColor(
    light: UIColor(
        red: 14 / 255,
        green: 165 / 255,
        blue: 215 / 255,
        alpha: 1
    ),
    dark: UIColor(
        red: 56 / 255,
        green: 189 / 255,
        blue: 248 / 255,
        alpha: 1
    )
)

private let kmiFreeTitle = kmiFreeAdaptiveColor(
    light: UIColor(
        red: 15 / 255,
        green: 23 / 255,
        blue: 42 / 255,
        alpha: 1
    ),
    dark: UIColor(
        red: 241 / 255,
        green: 245 / 255,
        blue: 249 / 255,
        alpha: 1
    )
)

private let kmiFreeText = kmiFreeAdaptiveColor(
    light: UIColor(
        red: 17 / 255,
        green: 24 / 255,
        blue: 39 / 255,
        alpha: 1
    ),
    dark: UIColor(
        red: 226 / 255,
        green: 232 / 255,
        blue: 240 / 255,
        alpha: 1
    )
)

private let kmiFreeSubText = kmiFreeAdaptiveColor(
    light: UIColor(
        red: 100 / 255,
        green: 116 / 255,
        blue: 139 / 255,
        alpha: 1
    ),
    dark: UIColor(
        red: 148 / 255,
        green: 163 / 255,
        blue: 184 / 255,
        alpha: 1
    )
)

private let kmiFreeCyan = Color(
    red: 34 / 255,
    green: 211 / 255,
    blue: 238 / 255
)

struct FreeSessionsView: View {
    let branch: String
    let groupKey: String
    let currentUid: String
    let currentName: String

    @EnvironmentObject private var auth: AuthViewModel

    @Environment(\.colorScheme)
    private var colorScheme

    @AppStorage("kmi_app_language")
    private var kmiAppLanguage: String = ""

    @AppStorage("app_language")
    private var appLanguage: String = ""

    @AppStorage("initial_language_code")
    private var initialLanguageCode: String = ""

    @AppStorage("selected_language_code")
    private var selectedLanguageCode: String = ""

    @StateObject private var vm = FreeSessionsViewModel()

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var effectiveLanguageCode: String {
        let candidates = [
            kmiAppLanguage,
            appLanguage,
            selectedLanguageCode,
            initialLanguageCode
        ]
        .map {
            $0
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()
        }
        .filter { !$0.isEmpty }

        return candidates.first ?? "he"
    }

    private var isEnglish: Bool {
        effectiveLanguageCode.hasPrefix("en")
    }

    private var screenLayoutDirection: LayoutDirection {
        isEnglish
            ? .leftToRight
            : .rightToLeft
    }

    private var screenTextAlignment: TextAlignment {
        .leading
    }

    private var screenFrameAlignment: Alignment {
        .leading
    }

    private func tr(
        _ he: String,
        _ en: String
    ) -> String {
        isEnglish ? en : he
    }
    
    @State private var showCreateDialog = false
    @State private var createErrorMessage: String?
    @State private var createTitle = ""
    @State private var createLocation = ""
    @State private var chosenBranch = ""
    @State private var chosenGroup = ""
    @State private var selectedPlace: SessionPlace?
    @State private var placeSuggestions: [SessionPlace] = []
    @State private var suggestionsSearchID: [String] = []
    @State private var createDate = Date().addingTimeInterval(3600)

    private struct SessionPlace: Identifiable {
        let name: String
        let coordinate: CLLocationCoordinate2D

        var id: String {
            "\(coordinate.latitude),\(coordinate.longitude)|\(name)"
        }
    }

    private var groupsByBranch: [String: [String]] {
        var result: [String: [String]] = [:]

        for assignment in auth.userBranchAssignments {
            let name = assignment.branch.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }

            for value in assignment.groups {
                let group = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !group.isEmpty else { continue }

                if !result[name, default: []].contains(group) {
                    result[name, default: []].append(group)
                }
            }
        }

        if auth.userBranchAssignments.isEmpty {
            let name = branch.trimmingCharacters(in: .whitespacesAndNewlines)
            let group = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty, !group.isEmpty {
                result[name] = [group]
            }
        }

        return result
    }

    private var branchOptions: [String] {
        groupsByBranch.keys.sorted()
    }

    private var activeBranch: String {
        if branchOptions.contains(chosenBranch) { return chosenBranch }

        let initial = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        return branchOptions.contains(initial) ? initial : (branchOptions.first ?? "")
    }

    private var groupOptions: [String] {
        groupsByBranch[activeBranch] ?? []
    }

    private var activeGroup: String {
        if groupOptions.contains(chosenGroup) { return chosenGroup }

        let initial = groupKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return groupOptions.contains(initial) ? initial : (groupOptions.first ?? "")
    }

    private var placeSearchID: [String] {
        [
            activeBranch,
            createLocation.trimmingCharacters(in: .whitespacesAndNewlines),
            selectedPlace?.id ?? ""
        ]
    }
    @State private var showCreateDatePicker = false
    @State private var showCreateTimePicker = false
    
    @State private var pendingDelete: FreeSession?
    @State private var freeSessionsPDF: FreeSessionsPDFShareItem?

    private struct FreeSessionsPDFShareItem: Identifiable {
        let url: URL
        var id: URL { url }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: KmiAppTheme.screenBackgroundColors(for: colorScheme),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 12) {
                headerCard
                
                if vm.upcoming.isEmpty {
                    emptyState
                    
                    Spacer(minLength: 0)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.upcoming) { session in
                                FreeSessionCard(
                                    session: session,
                                    canManage: vm.canManage(session),
                                    isEnglish: isEnglish,
                                    onTap: {
                                        vm.openDetails(session)
                                    },
                                    onEdit: {
                                        vm.openDetails(session)
                                    },
                                    onDelete: {
                                        pendingDelete = session
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 110)
                    }
                    .refreshable {
                        vm.bindUpcoming()
                    }
                }
            }
            .padding(.top, 14)
            
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    Button {
                        createErrorMessage = nil
                        showCreateDialog = true
                    } label: {
                        Image(systemName: "plus")
                            .kmiIconSize(24)
                            .fontWeight(.black)
                            .foregroundStyle(KmiAppTheme.onPrimary(for: colorScheme))
                            .frame(width: 58, height: 58)
                            .background(KmiAppTheme.primary(for: colorScheme), in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("יצירת אימון חופשי", "Create free session"))
                    .padding(.trailing, 20)
                    .padding(.bottom, 28)
                }
            }
        }
        .sheet(
            item: $vm.selectedSession,
            onDismiss: {
                vm.closeDetails()
            }
        ) { session in
            FreeSessionDetailsSheet(
                vm: vm,
                session: session,
                currentUid: currentUid,
                onClose: { vm.closeDetails() }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert(
            tr(
                "מחיקת אימון",
                "Delete session"
            ),
            isPresented: Binding(
                get: {
                    pendingDelete != nil
                },
                set: {
                    if !$0 {
                        pendingDelete = nil
                    }
                }
            )
        ) {
            Button(
                tr(
                    "ביטול",
                    "Cancel"
                ),
                role: .cancel
            ) {
                pendingDelete = nil
            }

            Button(
                tr(
                    "מחק",
                    "Delete"
                ),
                role: .destructive
            ) {
                if let session = pendingDelete {
                    Task {
                        await vm.deleteSession(
                            sessionId: session.id
                        )
                    }
                }

                pendingDelete = nil
            }
        } message: {
            Text(
                isEnglish
                    ? "Delete the session \"\(pendingDelete?.title ?? "")\"?"
                    : "למחוק את האימון \"\(pendingDelete?.title ?? "")\"?"
            )
        }
        .alert(
            tr(
                "שגיאה",
                "Error"
            ),
            isPresented: Binding(
                get: {
                    vm.errorMessage != nil
                },
                set: {
                    if !$0 {
                        vm.errorMessage = nil
                    }
                }
            )
        ) {
            Button(
                tr(
                    "סגור",
                    "Close"
                ),
                role: .cancel
            ) {
                vm.errorMessage = nil
            }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .sheet(isPresented: $showCreateDialog) {
            createSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(vm.isLoading)
        }
      
        .sheet(item: $freeSessionsPDF) { item in
            KmiShareSheet(items: [item.url])
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: Notification.Name("KMI_FREE_SESSIONS_SHARE_PDF")
            )
        ) { _ in
            guard !showCreateDialog,
                  !vm.isLoading,
                  vm.selectedSession == nil,
                  pendingDelete == nil,
                  freeSessionsPDF == nil else { return }

            shareFreeSessionsPDF()
        }
        .task(id: [activeBranch, activeGroup, currentUid, currentName]) {
            vm.setContext(
                branch: activeBranch,
                groupKey: activeGroup,
                myUid: currentUid,
                myName: currentName
            )
        }
        .environment(
            \.layoutDirection,
            screenLayoutDirection
        )
    }
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            let branchLabel = activeBranch.isEmpty
                ? "—"
                : TrainingCatalogIOS.displayBranch(activeBranch, isEnglish: isEnglish)
            let groupLabel = activeGroup.isEmpty
                ? "—"
                : TrainingCatalogIOS.displayGroup(activeGroup, isEnglish: isEnglish)

            Text(tr("סניף: \(branchLabel)", "Branch: \(branchLabel)"))
                .kmiFont(size: 14, weight: .heavy)
                .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
                .frame(
                    maxWidth: .infinity,
                    alignment: screenFrameAlignment
                )
                .multilineTextAlignment(screenTextAlignment)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            Text(tr("קבוצה: \(groupLabel)", "Group: \(groupLabel)"))
            .kmiFont(size: 14, weight: .heavy)
            .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(screenTextAlignment)
            .lineLimit(2)
            .minimumScaleFactor(0.75)

            Divider()
                .overlay(KmiAppTheme.outlineVariant(for: colorScheme))

            Text(
                tr(
                    "אימונים עתידיים: \(vm.upcoming.count)",
                    "Upcoming sessions: \(vm.upcoming.count)"
                )
            )
            .kmiFont(size: 15, weight: .black)
            .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(screenTextAlignment)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
        .frame(
            maxWidth: .infinity,
            alignment: screenFrameAlignment
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            KmiAppTheme.surface(for: colorScheme),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(KmiAppTheme.outlineVariant(for: colorScheme), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                tr(
                    "אין עדיין אימונים מתוכננים",
                    "No free sessions planned yet"
                )
            )
            .kmiFont(size: 17, weight: .black)
            .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(screenTextAlignment)
            .fixedSize(
                horizontal: false,
                vertical: true
            )

            Text(
                tr(
                    "אפשר ליצור אימון חדש ולשלוח הזמנה לכל המתאמנים בקבוצה.",
                    "Create a new free session and invite the group."
                )
            )
            .kmiFont(size: 15, weight: .bold)
            .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
            .frame(
                maxWidth: .infinity,
                alignment: screenFrameAlignment
            )
            .multilineTextAlignment(screenTextAlignment)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
        .frame(
            maxWidth: .infinity,
            alignment: screenFrameAlignment
        )
        .padding(16)
        .background(
            KmiAppTheme.surface(for: colorScheme),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(KmiAppTheme.outlineVariant(for: colorScheme), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 16)
    }

    private var createSheet: some View {
        ZStack {
            LinearGradient(
                colors: KmiAppTheme.screenBackgroundColors(for: colorScheme),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 14) {
                    VStack(
                        alignment: isEnglish ? .leading : .trailing,
                        spacing: 12
                    ) {
                        HStack(
                            alignment: .center,
                            spacing: 12
                        ) {
                            Image(systemName: "clock.fill")
                                .kmiIconSize(22)
                                .foregroundStyle(KmiAppTheme.onPrimaryContainer(for: colorScheme))
                                .frame(width: 46, height: 46)
                                .background(KmiAppTheme.primaryContainer(for: colorScheme), in: Circle())
                                .accessibilityHidden(true)

                            VStack(
                                alignment: isEnglish ? .leading : .trailing,
                                spacing: 4
                            ) {
                                Text(
                                    tr(
                                        "יצירת אימון חדש",
                                        "Create a new session"
                                    )
                                )
                                .kmiFont(size: 22, weight: .black)
                                .foregroundStyle(kmiFreeTitle)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: screenFrameAlignment
                                )
                                .multilineTextAlignment(screenTextAlignment)
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )

                                Text(
                                    tr(
                                        "בחר כותרת, מקום, תאריך ושעה לאימון החופשי",
                                        "Choose a title, location, date and time for the free session"
                                    )
                                )
                                .kmiFont(size: 12, weight: .bold)
                                .foregroundStyle(kmiFreeSubText)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: screenFrameAlignment
                                )
                                .multilineTextAlignment(screenTextAlignment)
                                .fixedSize(
                                    horizontal: false,
                                    vertical: true
                                )
                            }
                        }

                        Divider()
                            .overlay(KmiAppTheme.outlineVariant(for: colorScheme))
                            .accessibilityHidden(true)

                        KmiPremiumDropdown(
                            title: tr("סניף", "Branch"),
                            options: branchOptions,
                            selectedValue: Binding(
                                get: { activeBranch },
                                set: { value in
                                    guard branchOptions.contains(value),
                                          value != activeBranch else { return }

                                    chosenBranch = value
                                    chosenGroup = groupsByBranch[value]?.first ?? ""
                                }
                            ),
                            placeholder: tr("אין סניף משויך", "No assigned branch"),
                            isEnglish: isEnglish,
                            isEnabled: branchOptions.count > 1 && !vm.isLoading,
                            labelForOption: {
                                TrainingCatalogIOS.displayBranch($0, isEnglish: isEnglish)
                            },
                            titleInsideField: true
                        )

                        KmiPremiumDropdown(
                            title: tr("קבוצה", "Group"),
                            options: groupOptions,
                            selectedValue: Binding(
                                get: { activeGroup },
                                set: { value in
                                    guard groupOptions.contains(value) else { return }
                                    chosenGroup = value
                                }
                            ),
                            placeholder: tr("אין קבוצה משויכת", "No assigned group"),
                            isEnglish: isEnglish,
                            isEnabled: groupOptions.count > 1 && !vm.isLoading,
                            labelForOption: {
                                TrainingCatalogIOS.displayGroup($0, isEnglish: isEnglish)
                            },
                            titleInsideField: true
                        )
                        
                        VStack(
                            alignment: isEnglish ? .leading : .trailing,
                            spacing: 8
                        ) {
                            Text(
                                tr(
                                    "כותרת",
                                    "Title"
                                )
                            )
                            .kmiFont(size: 14, weight: .heavy)
                            .foregroundStyle(kmiFreeTitle)
                            .frame(
                                maxWidth: .infinity,
                                alignment: screenFrameAlignment
                            )
                            .multilineTextAlignment(screenTextAlignment)

                            TextField(
                                "",
                                text: $createTitle,
                                prompt: Text(
                                    tr(
                                        "כותרת",
                                        "Title"
                                    )
                                )
                                .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
                            )
                            .textFieldStyle(.plain)
                            .kmiFont(size: 16, weight: .heavy)
                            .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
                            .multilineTextAlignment(screenTextAlignment)
                            .padding(14)
                            .background(
                                KmiAppTheme.surfaceVariant(for: colorScheme),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(KmiAppTheme.outlineVariant(for: colorScheme))
                                    .allowsHitTesting(false)
                            }
                            .accessibilityLabel(tr("כותרת", "Title"))
                        }
                        
                        VStack(
                            alignment: isEnglish ? .leading : .trailing,
                            spacing: 8
                        ) {
                            Text(
                                tr(
                                    "מקום (אופציונלי)",
                                    "Location (optional)"
                                )
                            )
                            .kmiFont(size: 14, weight: .heavy)
                            .foregroundStyle(kmiFreeTitle)
                            .frame(
                                maxWidth: .infinity,
                                alignment: screenFrameAlignment
                            )
                            .multilineTextAlignment(screenTextAlignment)

                            HStack(spacing: 8) {
                                Image(systemName: "mappin.and.ellipse")
                                    .kmiIconSize(16)
                                    .foregroundStyle(KmiAppTheme.primary(for: colorScheme))
                                    .accessibilityHidden(true)

                                createLocationTextField
                                    .accessibilityLabel(tr("מקום (אופציונלי)", "Location (optional)"))
                            }
                            .padding(14)
                            .background(
                                KmiAppTheme.surfaceVariant(for: colorScheme),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(KmiAppTheme.outlineVariant(for: colorScheme))
                                    .allowsHitTesting(false)
                            }

                            if selectedPlace == nil, suggestionsSearchID == placeSearchID {
                                ForEach(placeSuggestions) { place in
                                    Button {
                                        selectedPlace = place
                                        createLocation = place.name
                                    } label: {
                                        Label(place.name, systemImage: "mappin.circle")
                                            .kmiFont(size: 13, weight: .semibold)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(KmiAppTheme.primary(for: colorScheme))
                                }
                            }
                        }
                        
                        VStack(
                            alignment: isEnglish ? .leading : .trailing,
                            spacing: 12
                        ) {
                            Text(
                                tr(
                                    "בחירת יום ושעה",
                                    "Choose a date and time"
                                )
                            )
                            .kmiFont(size: 18, weight: .black)
                            .foregroundStyle(kmiFreeTitle)
                            .frame(
                                maxWidth: .infinity,
                                alignment: screenFrameAlignment
                            )
                            .multilineTextAlignment(screenTextAlignment)

                            Button {
                                showCreateDatePicker = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(Color.white)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Color.white.opacity(0.16)
                                        )
                                        .clipShape(Circle())

                                    VStack(
                                        alignment: isEnglish ? .leading : .trailing,
                                        spacing: 4
                                    ) {
                                        Text(
                                            tr(
                                                "התאריך והשעה שנבחרו",
                                                "Selected date and time"
                                            )
                                        )
                                        .kmiFont(size: 12, weight: .bold)
                                        .foregroundStyle(
                                            Color.white.opacity(0.80)
                                        )
                                        .frame(
                                            maxWidth: .infinity,
                                            alignment: screenFrameAlignment
                                        )
                                        .multilineTextAlignment(screenTextAlignment)

                                        Text(
                                            isEnglish
                                                ? createDate.formatted(
                                                    date: .abbreviated,
                                                    time: .shortened
                                                )
                                                : fmtSelectedDateHeb(createDate)
                                        )
                                        .kmiFont(size: 17, weight: .black)
                                        .foregroundStyle(Color.white)
                                        .frame(
                                            maxWidth: .infinity,
                                            alignment: screenFrameAlignment
                                        )
                                        .multilineTextAlignment(screenTextAlignment)
                                        .fixedSize(
                                            horizontal: false,
                                            vertical: true
                                        )
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity)
                                .background(kmiFreeBgBottom)
                                .overlay(
                                    RoundedRectangle(
                                        cornerRadius: 22,
                                        style: .continuous
                                    )
                                    .stroke(
                                        kmiFreeBorderStrong,
                                        lineWidth: 1
                                    )
                                )
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: 22,
                                        style: .continuous
                                    )
                                )
                            }
                            .buttonStyle(.plain)

                            Text(
                                tr(
                                    "לחיצה תפתח לוח שנה, ולאחר בחירת יום תיפתח בחירת שעה.",
                                    "Tap to choose a date, followed by the session time."
                                )
                            )
                            .kmiFont(size: 12, weight: .bold)
                            .foregroundStyle(kmiFreeSubText)
                            .frame(
                                maxWidth: .infinity,
                                alignment: screenFrameAlignment
                            )
                            .multilineTextAlignment(screenTextAlignment)
                            .fixedSize(
                                horizontal: false,
                                vertical: true
                            )
                        }
                        
                        if let createErrorMessage {
                            Text(createErrorMessage)
                                .kmiFont(size: 13, weight: .semibold)
                                .foregroundStyle(KmiAppTheme.error(for: colorScheme))
                                .multilineTextAlignment(screenTextAlignment)
                                .frame(maxWidth: .infinity, alignment: screenFrameAlignment)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack(spacing: 10) {
                            Button {
                                resetCreateForm()
                                showCreateDialog = false
                            } label: {
                                Text(
                                    tr(
                                        "ביטול",
                                        "Cancel"
                                    )
                                )
                                .kmiFont(size: 16, weight: .heavy)
                                .foregroundStyle(kmiFreeSubText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(kmiFreeCardSoft)
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            kmiFreeBorder,
                                            lineWidth: 1
                                        )
                                )
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Button {
                                let cleanTitle = createTitle
                                    .trimmingCharacters(
                                        in: .whitespacesAndNewlines
                                    )

                                createErrorMessage = nil

                                guard !cleanTitle.isEmpty else {
                                    createErrorMessage = tr(
                                        "נא להזין כותרת",
                                        "Please enter a title"
                                    )
                                    return
                                }

                                guard !activeBranch.isEmpty, !activeGroup.isEmpty else {
                                    createErrorMessage = tr(
                                        "יש לבחור סניף וקבוצה משויכים.",
                                        "Select an assigned branch and group."
                                    )
                                    return
                                }

                                let sessionBranch = activeBranch
                                let sessionGroup = activeGroup
                                let place = selectedPlace
                                let cleanLocation = createLocation
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                let startsAt = Int64(createDate.timeIntervalSince1970 * 1000)

                                Task { @MainActor in
                                    guard !vm.isLoading,
                                          activeBranch == sessionBranch,
                                          activeGroup == sessionGroup else { return }

                                    vm.setContext(
                                        branch: sessionBranch,
                                        groupKey: sessionGroup,
                                        myUid: currentUid,
                                        myName: currentName
                                    )

                                    let created = await vm.createSession(
                                        title: cleanTitle,
                                        locationName: cleanLocation.isEmpty ? nil : cleanLocation,
                                        lat: place?.coordinate.latitude,
                                        lng: place?.coordinate.longitude,
                                        startsAt: startsAt
                                    )

                                    guard created else {
                                        vm.errorMessage = nil
                                        createErrorMessage = tr(
                                            "לא ניתן לאשר שהאימון נוצר. בדוק את רשימת האימונים לפני ניסיון חוזר.",
                                            "Could not confirm the session was created. Check the sessions list before trying again."
                                        )
                                        return
                                    }

                                    resetCreateForm()
                                    showCreateDialog = false
                                }
                            } label: {
                                HStack(spacing: 7) {
                                    if vm.isLoading {
                                        ProgressView()
                                            .tint(
                                                Color(
                                                    red: 4 / 255,
                                                    green: 16 / 255,
                                                    blue: 31 / 255
                                                )
                                            )
                                            .controlSize(.small)
                                    }

                                    Text(
                                        tr(
                                            "צור",
                                            "Create"
                                        )
                                    )
                                    .kmiFont(size: 16, weight: .black)
                                }
                                .foregroundStyle(KmiAppTheme.onPrimary(for: colorScheme))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(KmiAppTheme.primary(for: colorScheme), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(vm.isLoading)
                            .opacity(vm.isLoading ? 0.72 : 1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    }
                    .disabled(vm.isLoading)
                    .padding(18)
                    .background(
                        KmiAppTheme.surface(for: colorScheme),
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(KmiAppTheme.outlineVariant(for: colorScheme))
                            .allowsHitTesting(false)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 24)
                }
            }

            if showCreateDatePicker {
                KmiAndroidStyleDatePickerDialog(
                    selectedDate: createDate,
                    isEnglish: isEnglish,
                    onDismiss: {
                        showCreateDatePicker = false
                    },
                    onToday: {
                        createDate = mergeDateKeepingTime(
                            Date(),
                            timeFrom: createDate
                        )

                        showCreateDatePicker = false

                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + 0.15
                        ) {
                            showCreateTimePicker = true
                        }
                    },
                    onDateSelected: { date in
                        createDate = mergeDateKeepingTime(
                            date,
                            timeFrom: createDate
                        )

                        showCreateDatePicker = false

                        DispatchQueue.main.asyncAfter(
                            deadline: .now() + 0.15
                        ) {
                            showCreateTimePicker = true
                        }
                    }
                )
                .environment(
                    \.layoutDirection,
                    screenLayoutDirection
                )
                .zIndex(20)
            }

            if showCreateTimePicker {
                KmiAndroidStyleTimePickerDialog(
                    selectedDate: createDate,
                    isEnglish: isEnglish,
                    onDismiss: {
                        showCreateTimePicker = false
                    },
                    onConfirm: { hour, minute in
                        createDate = mergeTimeIntoDate(
                            createDate,
                            hour: hour,
                            minute: minute
                        )

                        showCreateTimePicker = false
                    }
                )
                .environment(
                    \.layoutDirection,
                    screenLayoutDirection
                )
                .zIndex(30)
            }
        }
    }
 
    private var createLocationTextField: some View {
        TextField(
            "",
            text: Binding(
                get: { createLocation },
                set: { value in
                    guard value != createLocation else { return }
                    selectedPlace = nil
                    placeSuggestions = []
                    suggestionsSearchID = []
                    createLocation = value
                }
            ),
            prompt: Text(
                tr(
                    "הקלד מקום, כתובת או עיר",
                    "Enter a location, address or city"
                )
            )
            .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
        )
        .textFieldStyle(.plain)
        .kmiFont(size: 16, weight: .heavy)
        .foregroundStyle(KmiAppTheme.onSurface(for: colorScheme))
        .multilineTextAlignment(screenTextAlignment)
        .task(id: placeSearchID) {
            let searchID = placeSearchID
            await loadPlaceSuggestions(for: searchID)
        }
    }

    @MainActor
    private func loadPlaceSuggestions(for searchID: [String]) async {
        let query = createLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard selectedPlace == nil, query.count >= 3 else { return }

        do {
            try await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, searchID == placeSearchID else { return }

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            let response = try await MKLocalSearch(request: request).start()

            guard !Task.isCancelled, searchID == placeSearchID else { return }

            var seen = Set<String>()
            let results = response.mapItems.compactMap { item -> SessionPlace? in
                let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let address = [
                    item.placemark.thoroughfare,
                    item.placemark.locality
                ]
                .compactMap { $0 }
                .joined(separator: ", ")
                let label = [name, address].filter { !$0.isEmpty }.joined(separator: " · ")
                let coordinate = item.placemark.coordinate
                guard !label.isEmpty, CLLocationCoordinate2DIsValid(coordinate) else {
                    return nil
                }

                let place = SessionPlace(name: label, coordinate: coordinate)
                return seen.insert(place.id).inserted ? place : nil
            }

            placeSuggestions = Array(results.prefix(5))
            suggestionsSearchID = searchID
        } catch {
            guard !Task.isCancelled, searchID == placeSearchID else { return }
            placeSuggestions = []
            suggestionsSearchID = searchID
        }
    }

    @MainActor
    private func shareFreeSessionsPDF() {
        do {
            let url = try makeFreeSessionsPDF(sessions: vm.upcoming)
            freeSessionsPDF = FreeSessionsPDFShareItem(url: url)
        } catch {
            vm.errorMessage = tr(
                "לא ניתן היה ליצור את דוח האימונים החופשיים.",
                "Could not create the free sessions report."
            )
        }
    }

    @MainActor
    private func makeFreeSessionsPDF(sessions: [FreeSession]) throws -> URL {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 32
        let contentWidth = page.width - 2 * margin
        let contentBottom = page.height - KmiPdfFooter.CONTENT_BOTTOM_PADDING

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = isEnglish ? .left : .right
        paragraph.baseWritingDirection = isEnglish ? .leftToRight : .rightToLeft
        paragraph.lineBreakMode = .byTruncatingTail

        let bodyColor = UIColor(KmiAppTheme.onSurface(for: .light))
        let cardColor = UIColor(KmiAppTheme.surfaceVariant(for: .light))
        let borderColor = UIColor(KmiAppTheme.outlineVariant(for: .light))

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: isEnglish ? "en_US" : "he_IL")
        dateFormatter.dateFormat = "dd/MM/yyyy · HH:mm"

        let branchLabel = activeBranch.isEmpty
            ? "—"
            : TrainingCatalogIOS.displayBranch(activeBranch, isEnglish: isEnglish)
        let groupLabel = activeGroup.isEmpty
            ? "—"
            : TrainingCatalogIOS.displayGroup(activeGroup, isEnglish: isEnglish)

        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let data = renderer.pdfData { output in
            var pageNumber = 0
            var y: CGFloat = 0

            func drawLine(
                _ text: String,
                x: CGFloat,
                y: CGFloat,
                width: CGFloat,
                font: UIFont
            ) {
                let rect = CGRect(x: x, y: y, width: width, height: ceil(font.lineHeight) + 2)
                (text as NSString).draw(
                    with: rect,
                    options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                    attributes: [
                        .font: font,
                        .foregroundColor: bodyColor,
                        .paragraphStyle: paragraph
                    ],
                    context: nil
                )
            }

            func cardText(
                _ text: String,
                font: UIFont
            ) -> NSAttributedString {
                let style = NSMutableParagraphStyle()
                style.alignment = paragraph.alignment
                style.baseWritingDirection = paragraph.baseWritingDirection
                style.lineBreakMode = .byWordWrapping

                return NSAttributedString(
                    string: text,
                    attributes: [
                        .font: font,
                        .foregroundColor: bodyColor,
                        .paragraphStyle: style
                    ]
                )
            }

            let textDrawingOptions: NSStringDrawingOptions = [
                .usesLineFragmentOrigin,
                .usesFontLeading
            ]

            func measuredHeight(_ text: NSAttributedString, width: CGFloat) -> CGFloat {
                ceil(text.boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: textDrawingOptions,
                    context: nil
                ).height)
            }

            func drawFooter() {
                KmiPdfFooter.draw(
                    context: output.cgContext,
                    pageWidth: page.width,
                    pageHeight: page.height,
                    pageNumber: pageNumber,
                    isEnglish: isEnglish
                )
            }

            func beginPage() {
                if pageNumber > 0 {
                    drawFooter()
                }

                output.beginPage()
                pageNumber += 1

                KmiPdfHeader.draw(
                    context: output.cgContext,
                    pageWidth: page.width,
                    isEnglish: isEnglish,
                    titleHebrew: "אימונים חופשיים",
                    titleEnglish: "Free Sessions",
                    subtitleHebrew: "רשימת האימונים החופשיים הפעילים",
                    subtitleEnglish: "Active free sessions"
                )

                y = KmiPdfHeader.CONTENT_TOP
            }

            beginPage()

            let summary = [
                tr("סניף: \(branchLabel)", "Branch: \(branchLabel)"),
                tr("קבוצה: \(groupLabel)", "Group: \(groupLabel)"),
                tr("מספר אימונים: \(sessions.count)", "Sessions: \(sessions.count)")
            ]

            for line in summary {
                drawLine(line, x: margin, y: y, width: contentWidth,
                         font: .systemFont(ofSize: 12, weight: .semibold))
                y += 20
            }
            y += 6

            if sessions.isEmpty {
                drawLine(
                    tr(
                        "אין אימונים חופשיים מתוכננים כרגע.",
                        "No free sessions are currently scheduled."
                    ),
                    x: margin,
                    y: y,
                    width: contentWidth,
                    font: .systemFont(ofSize: 12)
                )
            }

            for (index, session) in sessions.enumerated() {
                let location = session.locationName?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let textWidth = contentWidth - 24
                let titleFont = UIFont.systemFont(ofSize: 14, weight: .bold)
                let detailFont = UIFont.systemFont(ofSize: 11)
                let detailLineHeight = ceil(detailFont.lineHeight) + 2

                let title = "\(index + 1). \(session.title)"
                let locationLine = tr("מקום: \(location)", "Location: \(location)")
                let wrappedTitle = cardText(title, font: titleFont)
                let wrappedLocation = cardText(locationLine, font: detailFont)

                let locationHeight = location.isEmpty
                    ? 0
                    : min(
                        measuredHeight(wrappedLocation, width: textWidth) + 2,
                        2 * detailLineHeight
                    )
                let fixedHeight: CGFloat = 22 + 36 + (location.isEmpty ? 0 : 2)
                let maxTitleHeight = max(
                    ceil(titleFont.lineHeight) + 2,
                    contentBottom - KmiPdfHeader.CONTENT_TOP - fixedHeight - locationHeight
                )
                let fullTitleHeight = measuredHeight(wrappedTitle, width: textWidth) + 2
                let titleHeight = min(fullTitleHeight, maxTitleHeight)
                let cardHeight = fixedHeight + titleHeight + locationHeight

                if y + cardHeight > contentBottom {
                    beginPage()
                }

                let rect = CGRect(x: margin, y: y, width: contentWidth, height: cardHeight)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 14)
                cardColor.setFill()
                path.fill()
                borderColor.setStroke()
                path.lineWidth = 0.75
                path.stroke()

                let date = Date(timeIntervalSince1970: TimeInterval(session.startsAt) / 1_000)
                let time = dateFormatter.string(from: date)
                let count = session.goingCount + session.onWayCount
                    + session.arrivedCount + session.cantCount

                let x = rect.minX + 12
                let titleY = rect.minY + 10

                wrappedTitle.draw(
                    with: CGRect(x: x, y: titleY, width: textWidth, height: titleHeight),
                    options: textDrawingOptions.union(.truncatesLastVisibleLine),
                    context: nil
                )

                let detailsY = titleY + titleHeight + 2
                drawLine(
                    tr("שעה: \(time)", "Time: \(time)"),
                    x: x, y: detailsY, width: textWidth, font: detailFont
                )
                drawLine(
                    tr("משתתפים: \(count)", "Participants: \(count)"),
                    x: x, y: detailsY + 18, width: textWidth, font: detailFont
                )

                if !location.isEmpty {
                    wrappedLocation.draw(
                        with: CGRect(
                            x: x, y: detailsY + 36,
                            width: textWidth, height: locationHeight
                        ),
                        options: textDrawingOptions.union(.truncatesLastVisibleLine),
                        context: nil
                    )
                }

                y = rect.maxY + 12
            }

            drawFooter()
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("free_sessions_pdfs", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let url = directory.appendingPathComponent(
            tr("אימונים חופשיים.pdf", "Free Sessions.pdf")
        )
        try data.write(to: url, options: .atomic)
        return url
    }

    private func resetCreateForm() {
        createErrorMessage = nil
        createTitle = ""
        createLocation = ""
        selectedPlace = nil
        placeSuggestions = []
        suggestionsSearchID = []
        createDate = Calendar.current.date(
            byAdding: .hour,
            value: 1,
            to: Date()
        ) ?? Date().addingTimeInterval(3600)
        showCreateDatePicker = false
        showCreateTimePicker = false
    }
}

// MARK: - Card

private struct FreeSessionCard: View {
    let session: FreeSession
    let canManage: Bool
    let isEnglish: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @ObservedObject private var demoPrivacy = DemoPrivacy.shared

    @Environment(\.colorScheme)
    private var colorScheme

    private var displayedCreatorName: String {
        if demoPrivacy.isEnabled {
            return isEnglish ? "User" : "משתמש"
        }

        return session.createdByName
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var cardTextAlignment: TextAlignment {
        .leading
    }

    private var cardFrameAlignment: Alignment {
        .leading
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sessionHeader

            sessionInformation

            if let location = session.locationName,
               !location
                    .trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    .isEmpty {
                sessionLocation(location)
            }

            Text(
                isEnglish
                    ? "Tap to select your status"
                    : "לחץ כדי לבחור סטטוס (מגיע / לא יכול / וכו׳)"
            )
            .kmiFont(size: 12, weight: .bold)
            .foregroundStyle(kmiFreeSubText)
            .frame(
                maxWidth: .infinity,
                alignment: cardFrameAlignment
            )
            .multilineTextAlignment(cardTextAlignment)
            .fixedSize(
                horizontal: false,
                vertical: true
            )

            ProgressView(
                value: session.progressValue
            )
            .progressViewStyle(.linear)
            .tint(KmiAppTheme.success(for: colorScheme))
            .scaleEffect(
                x: 1,
                y: 1.6,
                anchor: .center
            )
            .clipShape(Capsule())
        }
        .padding(14)
        .frame(
            maxWidth: .infinity,
            alignment: cardFrameAlignment
        )
        .background(
            KmiAppTheme.surface(for: colorScheme),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(KmiAppTheme.outlineVariant(for: colorScheme), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .contentShape(
            RoundedRectangle(
                cornerRadius: 24,
                style: .continuous
            )
        )
        .onTapGesture {
            onTap()
        }
        .accessibilityAddTraits(.isButton)
    }

    private var sessionHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            sessionHeading
                .layoutPriority(1)

            sessionActions
        }
    }

    private var sessionHeading: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(session.title)
                .kmiFont(size: 17, weight: .black)
                .foregroundStyle(kmiFreeText)
                .frame(
                    maxWidth: .infinity,
                    alignment: cardFrameAlignment
                )
                .multilineTextAlignment(cardTextAlignment)
                .lineLimit(3)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            Text(
                isEnglish
                    ? "Created by \(displayedCreatorName)"
                    : "נוצר ע״י \(displayedCreatorName)"
            )
            .kmiFont(size: 12, weight: .bold)
            .foregroundStyle(KmiAppTheme.onSurfaceVariant(for: colorScheme))
            .frame(
                maxWidth: .infinity,
                alignment: cardFrameAlignment
            )
            .multilineTextAlignment(cardTextAlignment)
            .lineLimit(2)
        }
    }

    private var sessionActions: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(
                    Color(
                        red: 125 / 255,
                        green: 211 / 255,
                        blue: 252 / 255
                    )
                )
                .frame(width: 36, height: 36)

            if canManage {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(kmiFreeSubText)
                        .frame(width: 40, height: 40)
                        .background(
                            kmiFreeCardSoft.opacity(0.75)
                        )
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button(
                    role: .destructive,
                    action: onDelete
                ) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(
                            Color(
                                red: 239 / 255,
                                green: 68 / 255,
                                blue: 68 / 255
                            )
                        )
                        .frame(width: 40, height: 40)
                        .background(
                            kmiFreeCardSoft.opacity(0.75)
                        )
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var sessionInformation: some View {
        HStack(spacing: 10) {
            Text(
                shortSessionTime(
                    session.startsAt
                )
            )
            .kmiFont(size: 13, weight: .semibold)
            .foregroundStyle(kmiFreeSubText)
            .lineLimit(2)
            .minimumScaleFactor(0.75)

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Image(systemName: "person.3.fill")
                    .foregroundStyle(kmiFreeCyan)

                Text(
                    isEnglish
                        ? "\(session.totalParticipants) participants"
                        : "\(session.totalParticipants) משתתפים"
                )
                .kmiFont(size: 13, weight: .bold)
                .foregroundStyle(kmiFreeText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
    }

    private func sessionLocation(
        _ location: String
    ) -> some View {
        HStack(spacing: 6) {
            if isEnglish {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(
                        Color(
                            red: 249 / 255,
                            green: 115 / 255,
                            blue: 22 / 255
                        )
                    )

                Text(location)
                    .kmiFont(size: 14, weight: .bold)
                    .foregroundStyle(kmiFreeText)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

            } else {
                Spacer(minLength: 0)

                Text(location)
                    .kmiFont(size: 14, weight: .bold)
                    .foregroundStyle(kmiFreeText)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(3)

                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(
                        Color(
                            red: 249 / 255,
                            green: 115 / 255,
                            blue: 22 / 255
                        )
                    )
            }
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .frame(
            maxWidth: .infinity,
            alignment: cardFrameAlignment
        )
    }

    private func shortSessionTime(
        _ millis: Int64
    ) -> String {
        let date = Date(
            timeIntervalSince1970:
                TimeInterval(millis) / 1000.0
        )

        let formatter = DateFormatter()
        formatter.locale = Locale(
            identifier:
                isEnglish
                ? "en_US"
                : "he_IL"
        )
        formatter.calendar = Calendar(
            identifier: .gregorian
        )
        formatter.dateFormat =
            isEnglish
            ? "EEE · MMM d, yyyy · HH:mm"
            : "EEEE · d.M.yyyy · HH:mm"

        return formatter.string(
            from: date
        )
    }
}

// MARK: - Android-style Date/Time Pickers

private struct KmiAndroidStyleDatePickerDialog: View {
    let selectedDate: Date
    let isEnglish: Bool
    let onDismiss: () -> Void
    let onToday: () -> Void
    let onDateSelected: (Date) -> Void

    @Environment(\.colorScheme)
    private var colorScheme

    @State private var visibleMonth = Date()

    private let calendar = Calendar(
        identifier: .gregorian
    )

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var pickerTextAlignment: TextAlignment {
        isEnglish ? .leading : .trailing
    }

    private var pickerFrameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    private var weekDayNames: [String] {
        isEnglish
            ? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            : ["א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ש׳"]
    }

    var body: some View {
        ZStack {
            Color.black.opacity(
                isDarkMode ? 0.58 : 0.42
            )
            .ignoresSafeArea()
            .onTapGesture {
                onDismiss()
            }

            VStack(
                alignment: isEnglish ? .leading : .trailing,
                spacing: 16
            ) {
                header

                Divider()
                    .overlay(kmiFreeBorder)

                monthSwitcher
                weekDaysRow
                daysGrid
                footer
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(kmiFreeCard)
            .overlay(
                RoundedRectangle(
                    cornerRadius: 30,
                    style: .continuous
                )
                .stroke(
                    kmiFreeBorderStrong,
                    lineWidth: 1
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 30,
                    style: .continuous
                )
            )
            .shadow(
                color: Color.black.opacity(
                    isDarkMode ? 0.40 : 0.28
                ),
                radius: 18,
                x: 0,
                y: 10
            )
            .padding(.horizontal, 18)
            .onAppear {
                visibleMonth = firstDayOfMonth(
                    selectedDate
                )
            }
        }
    }

    private var header: some View {
        HStack(
            alignment: .top,
            spacing: 12
        ) {
            if isEnglish {
                calendarIcon
                headerTexts
            } else {
                headerTexts
                calendarIcon
            }
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .frame(
            maxWidth: .infinity,
            alignment: pickerFrameAlignment
        )
    }

    private var calendarIcon: some View {
        Image(systemName: "calendar")
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(Color.red)
            .frame(width: 42, height: 42)
            .background(kmiFreeCardSoft)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 10,
                    style: .continuous
                )
                .stroke(
                    kmiFreeBorder,
                    lineWidth: 1
                )
            )
    }

    private var headerTexts: some View {
        VStack(
            alignment: isEnglish ? .leading : .trailing,
            spacing: 6
        ) {
            Text(
                isEnglish
                    ? "Choose a session date"
                    : "בחר תאריך לאימון"
            )
            .kmiFont(size: 20, weight: .black)
            .foregroundStyle(kmiFreeSubText)
            .frame(
                maxWidth: .infinity,
                alignment: pickerFrameAlignment
            )
            .multilineTextAlignment(
                pickerTextAlignment
            )

            Text(dateTitle(selectedDate))
                .kmiFont(size: 27, weight: .black)
                .foregroundStyle(kmiFreeText)
                .frame(
                    maxWidth: .infinity,
                    alignment: pickerFrameAlignment
                )
                .multilineTextAlignment(
                    pickerTextAlignment
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
    }

    private var monthSwitcher: some View {
        HStack(spacing: 14) {
            Button {
                visibleMonth = addMonth(
                    isEnglish ? -1 : 1
                )
            } label: {
                Image(
                    systemName:
                        isEnglish
                        ? "chevron.left"
                        : "chevron.right"
                )
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.white)
                .frame(width: 42, height: 42)
                .background(kmiFreeBgBottom)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text(monthTitle(visibleMonth))
                .kmiFont(size: 23, weight: .black)
                .foregroundStyle(kmiFreeText)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Button {
                visibleMonth = addMonth(
                    isEnglish ? 1 : -1
                )
            } label: {
                Image(
                    systemName:
                        isEnglish
                        ? "chevron.right"
                        : "chevron.left"
                )
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.white)
                .frame(width: 42, height: 42)
                .background(kmiFreeBgBottom)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
    }

    private var weekDaysRow: some View {
        HStack(spacing: 0) {
            ForEach(
                weekDayNames,
                id: \.self
            ) { day in
                Text(day)
                    .kmiFont(size: 14, weight: .black)
                    .foregroundStyle(kmiFreeText)
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .padding(.vertical, 10)
        .background(kmiFreeCardSoft)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
    }

    private var daysGrid: some View {
        let days = monthCells()

        return LazyVGrid(
            columns: Array(
                repeating: GridItem(
                    .flexible(),
                    spacing: 0
                ),
                count: 7
            ),
            spacing: 10
        ) {
            ForEach(
                Array(days.enumerated()),
                id: \.offset
            ) { _, date in
                if let date {
                    dayCell(date)
                } else {
                    Color.clear
                        .frame(height: 36)
                }
            }
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 14)
        .background(kmiFreeCardSoft)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 20,
                style: .continuous
            )
        )
    }

    private func dayCell(
        _ date: Date
    ) -> some View {
        let selected = calendar.isDate(
            date,
            inSameDayAs: selectedDate
        )

        let today = calendar.isDateInToday(date)

        return Button {
            onDateSelected(date)
        } label: {
            Text(
                "\(calendar.component(.day, from: date))"
            )
            .kmiFont(size: 17, weight: .black)
            .foregroundStyle(
                selected
                    ? Color(
                        red: 4 / 255,
                        green: 16 / 255,
                        blue: 31 / 255
                    )
                    : kmiFreeText
            )
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(
                        selected
                            ? kmiFreeCyan
                            : (
                                today
                                    ? kmiFreeCyan.opacity(0.18)
                                    : Color.clear
                            )
                    )
            )
            .overlay(
                Circle()
                    .stroke(
                        today && !selected
                            ? kmiFreeBorderStrong.opacity(0.55)
                            : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                onToday()
            } label: {
                Text(
                    isEnglish
                        ? "Today"
                        : "היום"
                )
                .kmiFont(size: 18, weight: .black)
                .foregroundStyle(
                    Color(
                        red: 4 / 255,
                        green: 16 / 255,
                        blue: 31 / 255
                    )
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(kmiFreeCyan)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                onDismiss()
            } label: {
                Text(
                    isEnglish
                        ? "Cancel"
                        : "ביטול"
                )
                .kmiFont(size: 18, weight: .black)
                .foregroundStyle(kmiFreeSubText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(kmiFreeCardSoft)
                .overlay(
                    Capsule()
                        .stroke(
                            kmiFreeBorder,
                            lineWidth: 1
                        )
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func firstDayOfMonth(
        _ date: Date
    ) -> Date {
        let components = calendar.dateComponents(
            [.year, .month],
            from: date
        )

        return calendar.date(
            from: components
        ) ?? date
    }

    private func addMonth(
        _ value: Int
    ) -> Date {
        calendar.date(
            byAdding: .month,
            value: value,
            to: visibleMonth
        ) ?? visibleMonth
    }

    private func monthCells() -> [Date?] {
        let start = firstDayOfMonth(
            visibleMonth
        )

        let range = calendar.range(
            of: .day,
            in: .month,
            for: start
        ) ?? 1..<1

        let firstWeekday = calendar.component(
            .weekday,
            from: start
        )

        let leading = firstWeekday - 1

        var cells: [Date?] = Array(
            repeating: nil,
            count: leading
        )

        for day in range {
            var components = calendar.dateComponents(
                [.year, .month],
                from: start
            )

            components.day = day

            cells.append(
                calendar.date(
                    from: components
                )
            )
        }

        while cells.count % 7 != 0 {
            cells.append(nil)
        }

        return cells
    }

    private func dateTitle(
        _ date: Date
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(
            identifier:
                isEnglish
                ? "en_US"
                : "he_IL"
        )
        formatter.calendar = calendar
        formatter.dateFormat =
            isEnglish
            ? "EEEE · MMMM d, yyyy"
            : "EEEE · d MMMM yyyy"

        return formatter.string(
            from: date
        )
    }

    private func monthTitle(
        _ date: Date
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(
            identifier:
                isEnglish
                ? "en_US"
                : "he_IL"
        )
        formatter.calendar = calendar
        formatter.dateFormat = "MMMM yyyy"

        return formatter.string(
            from: date
        )
    }
}

private struct KmiAndroidStyleTimePickerDialog: View {
    let selectedDate: Date
    let isEnglish: Bool
    let onDismiss: () -> Void
    let onConfirm: (
        _ hour: Int,
        _ minute: Int
    ) -> Void

    @Environment(\.colorScheme)
    private var colorScheme

    @State private var hour = 19
    @State private var minute = 0

    private let hours = Array(0...23)
    private let minutes = Array(0...59)

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var pickerFrameAlignment: Alignment {
        isEnglish ? .leading : .trailing
    }

    var body: some View {
        ZStack {
            Color.black.opacity(
                isDarkMode ? 0.58 : 0.42
            )
            .ignoresSafeArea()
            .onTapGesture {
                onDismiss()
            }

            VStack(
                alignment: isEnglish ? .leading : .trailing,
                spacing: 22
            ) {
                Text(
                    isEnglish
                        ? "Choose a session time"
                        : "בחר שעה לאימון"
                )
                .kmiFont(size: 26, weight: .black)
                .foregroundStyle(kmiFreeTitle)
                .frame(
                    maxWidth: .infinity,
                    alignment: pickerFrameAlignment
                )
                .multilineTextAlignment(
                    isEnglish ? .leading : .trailing
                )

                selectedTimeDisplay
                timeWheels
                footer
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
            .background(kmiFreeCard)
            .overlay(
                RoundedRectangle(
                    cornerRadius: 30,
                    style: .continuous
                )
                .stroke(
                    kmiFreeBorderStrong,
                    lineWidth: 1
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 30,
                    style: .continuous
                )
            )
            .shadow(
                color: Color.black.opacity(
                    isDarkMode ? 0.42 : 0.28
                ),
                radius: 18,
                x: 0,
                y: 10
            )
            .padding(.horizontal, 18)
            .onAppear {
                let components =
                    Calendar.current.dateComponents(
                        [.hour, .minute],
                        from: selectedDate
                    )

                hour = components.hour ?? 19
                minute = components.minute ?? 0
            }
        }
    }

    private var selectedTimeDisplay: some View {
        HStack(spacing: 10) {
            timeBox(
                value: String(
                    format: "%02d",
                    hour
                ),
                selected: true
            )

            Text(":")
                .kmiFont(size: 42, weight: .black)
                .foregroundStyle(
                    kmiFreeSubText.opacity(0.55)
                )

            timeBox(
                value: String(
                    format: "%02d",
                    minute
                ),
                selected: false
            )
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .frame(
            maxWidth: .infinity,
            alignment: .center
        )
    }

    private var timeWheels: some View {
        HStack(spacing: 0) {
            Picker(
                isEnglish ? "Hour" : "שעה",
                selection: $hour
            ) {
                ForEach(
                    hours,
                    id: \.self
                ) { value in
                    Text(
                        String(
                            format: "%02d",
                            value
                        )
                    )
                    .kmiFont(size: 24, weight: .black)
                    .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()

            Picker(
                isEnglish ? "Minute" : "דקה",
                selection: $minute
            ) {
                ForEach(
                    minutes,
                    id: \.self
                ) { value in
                    Text(
                        String(
                            format: "%02d",
                            value
                        )
                    )
                    .kmiFont(size: 24, weight: .black)
                    .tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .environment(
            \.layoutDirection,
            .leftToRight
        )
        .frame(height: 190)
        .background(kmiFreeCardSoft)
        .overlay(
            RoundedRectangle(
                cornerRadius: 28,
                style: .continuous
            )
            .stroke(
                kmiFreeBorder,
                lineWidth: 1
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 28,
                style: .continuous
            )
        )
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                onConfirm(
                    hour,
                    minute
                )
            } label: {
                Text(
                    isEnglish
                        ? "Confirm"
                        : "אישור"
                )
                .kmiFont(size: 18, weight: .black)
                .foregroundStyle(
                    Color(
                        red: 4 / 255,
                        green: 16 / 255,
                        blue: 31 / 255
                    )
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(kmiFreeCyan)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                onDismiss()
            } label: {
                Text(
                    isEnglish
                        ? "Cancel"
                        : "ביטול"
                )
                .kmiFont(size: 18, weight: .black)
                .foregroundStyle(kmiFreeSubText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(kmiFreeCardSoft)
                .overlay(
                    Capsule()
                        .stroke(
                            kmiFreeBorder,
                            lineWidth: 1
                        )
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func timeBox(
        value: String,
        selected: Bool
    ) -> some View {
        Text(value)
            .kmiFont(size: 44, weight: .black)
            .foregroundStyle(
                selected
                    ? Color(
                        red: 4 / 255,
                        green: 16 / 255,
                        blue: 31 / 255
                    )
                    : kmiFreeText
            )
            .frame(
                maxWidth: .infinity,
                minHeight: 76
            )
            .background(
                selected
                    ? kmiFreeCyan
                    : kmiFreeCardSoft
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
                .stroke(
                    selected
                        ? kmiFreeBorderStrong
                        : kmiFreeBorder,
                    lineWidth: 1
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
            )
    }
}

// MARK: - Helpers

private func fmtSelectedDateHeb(_ date: Date) -> String {
    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "he_IL")
    fmt.calendar = Calendar(identifier: .gregorian)
    fmt.dateFormat = "EEEE · d.M.yyyy · HH:mm"
    return fmt.string(from: date)
}

private func mergeDateKeepingTime(_ date: Date, timeFrom source: Date) -> Date {
    let cal = Calendar(identifier: .gregorian)

    let dateComps = cal.dateComponents([.year, .month, .day], from: date)
    let timeComps = cal.dateComponents([.hour, .minute], from: source)

    var merged = DateComponents()
    merged.year = dateComps.year
    merged.month = dateComps.month
    merged.day = dateComps.day
    merged.hour = timeComps.hour
    merged.minute = timeComps.minute
    merged.second = 0

    return cal.date(from: merged) ?? date
}

private func mergeTimeIntoDate(_ date: Date, hour: Int, minute: Int) -> Date {
    let cal = Calendar(identifier: .gregorian)

    var comps = cal.dateComponents([.year, .month, .day], from: date)
    comps.hour = hour.coerceIn(0...23)
    comps.minute = minute.coerceIn(0...59)
    comps.second = 0

    return cal.date(from: comps) ?? date
}

private extension Comparable {
    func coerceIn(_ range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}


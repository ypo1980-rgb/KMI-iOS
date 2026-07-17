import Foundation
import Combine

// MARK: - VoiceCommandActions

/// הפעולות האמיתיות שמערכת הפקודות הקוליות רשאית להפעיל.
///
/// ContentView יחבר את הפעולות האלו ל-AppNavModel ולשירותים
/// הקיימים. כך מנגנון הדיבור נשאר נפרד ממנגנון הניווט.
@MainActor
struct VoiceCommandActions {

    var openHome: (() -> Void)?
    var openSettings: (() -> Void)?
    var openProgress: (() -> Void)?
    var openTrainings: (() -> Void)?
    var openTopics: (() -> Void)?
    var openBelts: (() -> Void)?
    var openSearch: (() -> Void)?
    var goBack: (() -> Void)?

    var openBelt: ((String) -> Void)?
    var openTopic: ((String) -> Void)?
    var findAndOpen: ((String) -> Void)?
    var explainExercise: ((String) -> Void)?
    var search: ((String) -> Void)?

    var openDrawerDestination:
        ((VoiceDrawerDestination) -> Void)?

    var handleUnknown:
        ((_ originalText: String) -> Void)?

    init(
        openHome: (() -> Void)? = nil,
        openSettings: (() -> Void)? = nil,
        openProgress: (() -> Void)? = nil,
        openTrainings: (() -> Void)? = nil,
        openTopics: (() -> Void)? = nil,
        openBelts: (() -> Void)? = nil,
        openSearch: (() -> Void)? = nil,
        goBack: (() -> Void)? = nil,
        openBelt: ((String) -> Void)? = nil,
        openTopic: ((String) -> Void)? = nil,
        findAndOpen: ((String) -> Void)? = nil,
        explainExercise: ((String) -> Void)? = nil,
        search: ((String) -> Void)? = nil,
        openDrawerDestination:
            ((VoiceDrawerDestination) -> Void)? = nil,
        handleUnknown:
            ((_ originalText: String) -> Void)? = nil
    ) {
        self.openHome = openHome
        self.openSettings = openSettings
        self.openProgress = openProgress
        self.openTrainings = openTrainings
        self.openTopics = openTopics
        self.openBelts = openBelts
        self.openSearch = openSearch
        self.goBack = goBack
        self.openBelt = openBelt
        self.openTopic = openTopic
        self.findAndOpen = findAndOpen
        self.explainExercise = explainExercise
        self.search = search
        self.openDrawerDestination =
            openDrawerDestination
        self.handleUnknown = handleUnknown
    }
}

// MARK: - VoiceCommandsCoordinator

/// מנהל חלון הפקודות הקוליות והעברת הפקודה
/// לפעולות האפליקציה.
///
/// אינו קשור ל-AiAssistantLogic ואינו מחזיק לוגיקה של העוזר.
@MainActor
final class VoiceCommandsCoordinator: ObservableObject {

    static let shared = VoiceCommandsCoordinator()

    @Published private(set) var isPresented = false
    @Published private(set) var lastSpokenText = ""
    @Published private(set) var lastCommand:
        VoiceAppCommand?

    private var actions = VoiceCommandActions()

    private init() {}

    func bind(
        actions: VoiceCommandActions
    ) {
        self.actions = actions
    }

    func unbind() {
        actions = VoiceCommandActions()
        dismiss()
    }

    func present() {
        guard !isPresented else {
            return
        }

        lastSpokenText = ""
        lastCommand = nil
        isPresented = true
    }

    func dismiss() {
        isPresented = false
    }

    func handle(
        command: VoiceAppCommand,
        spokenText: String
    ) {
        let cleanSpokenText =
            spokenText.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        lastSpokenText = cleanSpokenText
        lastCommand = command

        /*
         * סוגרים קודם את חלון המיקרופון ורק אחר כך
         * מפעילים ניווט. הדבר מונע התנגשות בין
         * אנימציית סגירת ה-sheet לבין NavigationStack.
         */
        isPresented = false

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.18
        ) { [weak self] in
            guard let self else {
                return
            }

            self.execute(command)
        }
    }

    private func execute(
        _ command: VoiceAppCommand
    ) {
        switch command {
        case .openHome:
            actions.openHome?()

        case .openSettings:
            actions.openSettings?()

        case .openProgress:
            actions.openProgress?()

        case .openTrainings:
            actions.openTrainings?()

        case .openTopics:
            actions.openTopics?()

        case .openBelts:
            actions.openBelts?()

        case .openSearch:
            actions.openSearch?()

        case .goBack:
            actions.goBack?()

        case .openBelt(let beltQuery):
            actions.openBelt?(beltQuery)

        case .openTopic(let topicQuery):
            actions.openTopic?(topicQuery)

        case .findAndOpen(let query):
            actions.findAndOpen?(query)

        case .explainExercise(let query):
            actions.explainExercise?(query)

        case .search(let query):
            actions.search?(query)

        case .openDrawerItem(let destination):
            actions.openDrawerDestination?(
                destination
            )

        case .unknown(let originalText):
            actions.handleUnknown?(
                originalText
            )
        }
    }
}

// MARK: - VoiceCommandsBridge

/// גשר קטן המקביל ל-VoiceCommandsBridge באנדרואיד.
///
/// KmiTopBar יכול לבקש לפתוח את חלון הפקודות
/// בלי להכיר את ContentView או את AppNavModel.
@MainActor
enum VoiceCommandsBridge {

    @discardableResult
    static func open() -> Bool {
        VoiceCommandsCoordinator.shared.present()
        return true
    }

    static func close() {
        VoiceCommandsCoordinator.shared.dismiss()
    }

    static var isPresented: Bool {
        VoiceCommandsCoordinator.shared.isPresented
    }
}

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct CoachTraineesView: View {

    @EnvironmentObject private var auth: AuthViewModel

    @State private var trainees: [CoachTraineeProfile] = []
    @State private var selectedId: String? = nil
    @State private var coachNotes: [String: String] = [:]
    @State private var isLoading = true

    private var isCoach: Bool {
        let role = UserDefaults.standard.string(forKey: "user_role")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if let role, !role.isEmpty {
            return role == "coach" || role == "trainer" || role == "מאמן"
        }

        let fallback = auth.userRole
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return fallback == "coach" || fallback == "trainer" || fallback == "מאמן"
    }

    private var selectedTrainee: CoachTraineeProfile? {
        trainees.first(where: { $0.id == selectedId }) ?? trainees.first
    }

    private var effectiveBranch: String {
        let fromAuth = auth.userBranch
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !fromAuth.isEmpty {
            return fromAuth
        }

        return UserDefaults.standard.string(forKey: "branch")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var effectiveGroupKey: String {
        let fromAuth = auth.userGroup
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !fromAuth.isEmpty {
            return fromAuth
        }

        return UserDefaults.standard.string(forKey: "group")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var effectiveBranchPrimary: String {
        effectiveBranch
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? effectiveBranch
    }

    private var branchLabel: String {
        effectiveBranch.isEmpty ? "(לא ידוע)" : effectiveBranch
    }

    private var branchPrimaryLabel: String {
        effectiveBranchPrimary.isEmpty ? "(לא ידוע)" : effectiveBranchPrimary
    }

    private var groupLabel: String {
        effectiveGroupKey.isEmpty ? "(לא ידוע)" : effectiveGroupKey
    }
    
    var body: some View {
        ZStack {

            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.03, blue: 0.03),
                    Color(red: 0.22, green: 0.05, blue: 0.05),
                    Color(red: 0.42, green: 0.08, blue: 0.08),
                    Color(red: 0.62, green: 0.11, blue: 0.11)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            if !isCoach {
                VStack(spacing: 12) {
                    Spacer()

                    Text("המסך זמין למאמנים בלבד")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(.white)

                    Spacer()
                }
                .padding(24)

            } else if isLoading {
                ProgressView("טוען מתאמנים...")
                    .tint(.white)
                    .foregroundStyle(.white)

            } else {
                ScrollView {
                    VStack(spacing: 12) {

                        Text("סניף: \(branchLabel) | בפועל: \(branchPrimaryLabel) | קבוצה: \(groupLabel)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        traineeListCard

                        traineeDetailsCard
                    }
                    .padding(12)
                }
            }
        }
        .onAppear {
            loadTrainees()
        }
        .onChange(of: auth.userBranch) { _ in
            if !effectiveBranch.isEmpty && !effectiveGroupKey.isEmpty {
                loadTrainees()
            }
        }
        .onChange(of: auth.userGroup) { _ in
            if !effectiveBranch.isEmpty && !effectiveGroupKey.isEmpty {
                loadTrainees()
            }
        }
        .onChange(of: trainees.map(\.id)) { _ in
            if selectedId == nil && !trainees.isEmpty {
                selectedId = trainees.first?.id
            } else if let selectedId, !trainees.contains(where: { $0.id == selectedId }) {
                self.selectedId = trainees.first?.id
            }
        }
    }

    private var traineeListCard: some View {
        VStack(spacing: 0) {
            Divider()

            if trainees.isEmpty {
                VStack(spacing: 8) {
                    if effectiveBranch.isEmpty || effectiveGroupKey.isEmpty {
                        Text("לא נבחרו סניף/קבוצה.")
                        Text("מוצגת רשימת כל המתאמנים.")
                    } else {
                        Text("עדיין לא הוגדרו מתאמנים לקבוצה זו.")
                    }
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(20)

            } else {
                ScrollView {
                    VStack(spacing: 0) {                        ForEach(trainees) { trainee in
                            Button {
                                selectedId = trainee.id
                            } label: {
                                HStack {
                                    if selectedId == trainee.id {
                                        Text("נבחר")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.blue)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(trainee.fullName)
                                            .font(.system(size: 17, weight: .bold))
                                            .foregroundStyle(.black)

                                        if !trainee.belt.isEmpty {
                                            Text(trainee.belt)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.gray)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)

                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 210)
            }
        }
        .background(Color.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var traineeDetailsCard: some View {
        VStack(alignment: .trailing, spacing: 12) {
            if let trainee = selectedTrainee {
                Text(trainee.fullName)
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Divider()

                labeledField("גיל", trainee.age > 0 ? "\(trainee.age)" : "—")
                labeledField("ותק", trainee.seniority.isEmpty ? "—" : trainee.seniority)
                labeledField("דרגה", trainee.belt.isEmpty ? "—" : trainee.belt)
                labeledField("אחוז נוכחות", trainee.attendancePct > 0 ? "\(trainee.attendancePct)%" : "—")

                VStack(alignment: .trailing, spacing: 6) {
                    Text("הערות מאמן")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.gray)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    TextEditor(
                        text: Binding(
                            get: { coachNotes[trainee.id] ?? "" },
                            set: { coachNotes[trainee.id] = $0 }
                        )
                    )
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    )
                }
            } else {
                Text("בחר מתאמן מהרשימה למעלה")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func labeledField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.gray)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text(value)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func loadTrainees() {
        print("TRAINEES auth.branch =", auth.userBranch)
        print("TRAINEES auth.group =", auth.userGroup)
        print("TRAINEES effective.branch =", effectiveBranch)
        print("TRAINEES effective.group =", effectiveGroupKey)

        guard isCoach else {
            isLoading = false
            return
        }

        isLoading = true

        let db = Firestore.firestore()
        let hasGroup = !effectiveGroupKey.isEmpty

        let query: Query = hasGroup
            ? db.collection("users")
                .whereField("groups", arrayContains: effectiveGroupKey)
                .whereField("role", isEqualTo: "trainee")
            : db.collection("users")
                .whereField("role", isEqualTo: "trainee")
        
        query.getDocuments { snapshot, error in
            isLoading = false

            guard let docs = snapshot?.documents else {
                trainees = []
                return
            }

            let rows: [CoachTraineeProfile] = docs.compactMap { doc in
                let data = doc.data()

                let fullName =
                    (data["fullName"] as? String) ??
                    (data["name"] as? String) ??
                    (data["displayName"] as? String) ??
                    ""

                if fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return nil
                }

                let beltRaw =
                    (data["belt"] as? String) ??
                    (data["beltId"] as? String) ??
                    ""

                let age = ageFromBirthDate(data["birthDate"] as? String)

                return CoachTraineeProfile(
                    id: doc.documentID,
                    fullName: fullName,
                    belt: beltHeb(beltRaw),
                    seniority: hasGroup ? "" : "ללא קבוצה נבחרת",
                    age: age,
                    attendancePct: 0
                )
            }
            .sorted { $0.fullName < $1.fullName }

            let unique = Dictionary(grouping: rows, by: { $0.id })
                .compactMap { $0.value.first }
                .sorted { $0.fullName < $1.fullName }

            trainees = unique

            if selectedId == nil {
                selectedId = rows.first?.id
            } else if let selectedId, !rows.contains(where: { $0.id == selectedId }) {
                self.selectedId = rows.first?.id
            }
        }
    }
    
    private func beltHeb(_ raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "white": return "לבנה"
        case "yellow": return "צהובה"
        case "orange": return "כתומה"
        case "green": return "ירוקה"
        case "blue": return "כחולה"
        case "brown": return "חומה"
        case "black": return "שחורה"
        default: return raw
        }
    }

    private func ageFromBirthDate(_ birthDate: String?) -> Int {
        guard let birthDate, !birthDate.isEmpty else { return 0 }
        guard let date = ISO8601DateFormatter().date(from: birthDate + "T00:00:00Z")
                ?? DateFormatter.kmiBirthFormatter.date(from: birthDate) else { return 0 }

        let components = Calendar.current.dateComponents([.year], from: date, to: Date())
        return components.year ?? 0
    }
}

private struct CoachTraineeProfile: Identifiable {
    let id: String
    let fullName: String
    let belt: String
    let seniority: String
    let age: Int
    let attendancePct: Int
}

private extension DateFormatter {
    static let kmiBirthFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}

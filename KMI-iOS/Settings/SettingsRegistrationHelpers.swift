import SwiftUI
import Foundation
import FirebaseAuth
import FirebaseFirestore

extension SettingsView {

    @MainActor
    func saveEditedRegistration(
        _ form: RegistrationFormState
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(
                domain: "KMI.ProfileSave",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "No signed-in user"
                ]
            )
        }

        guard form.hasCompleteBranchAssignments,
              !form.currentBeltId.isEmpty else {
            throw NSError(
                domain: "KMI.ProfileSave",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Incomplete registration assignments"
                ]
            )
        }

        var payload = form.toFirestoreDictionary(uid: uid)

        payload.removeValue(forKey: "createdAt")
        payload.removeValue(forKey: "uid")

        payload["branch"] = form.activeBranchFinal
        payload["active_branch"] = form.activeBranchFinal

        payload["group"] = form.activeGroupFinal
        payload["groupKey"] = form.activeGroupFinal
        payload["group_key"] = form.activeGroupFinal
        payload["active_group"] = form.activeGroupFinal
        payload["age_group"] = form.activeGroupFinal
        payload["ageGroup"] = form.activeGroupFinal

        payload["updatedAt"] = FieldValue.serverTimestamp()

        guard !Task.isCancelled,
              Auth.auth().currentUser?.uid == uid else {
            throw CancellationError()
        }

        try await Firestore.firestore()
            .collection("users")
            .document(uid)
            .updateData(payload)

        guard !Task.isCancelled,
              Auth.auth().currentUser?.uid == uid else {
            throw CancellationError()
        }

        saveRegistrationSnapshot(
            fullName: form.fullName,
            phone: form.phoneNormalized,
            email: form.emailTrimmed,
            region: form.region,
            belt: form.currentBeltId,
            isCoach: form.role == .coach,
            branches: form.branchesArray,
            groups: form.groupsArray,
            username: form.username,
            birthDay: form.birthDay,
            birthMonth: form.birthMonth,
            birthYear: form.birthYear,
            gender: form.gender,
            password: form.password,
            wantsSms: form.wantsSms,
            acceptsTerms: form.acceptsTerms,
            coachCode: form.coachCode,
            branchAssignments: form.normalizedBranchAssignments,
            activeBranch: form.activeBranchFinal,
            activeGroup: form.activeGroupFinal
        )
    }

    // MARK: - Registration Save Helpers
    func saveRegistrationSnapshot(
        fullName: String,
        phone: String,
        email: String,
        region: String,
        belt: String,
        isCoach: Bool,
        branches: [String],
        groups: [String],
        username: String,
        birthDay: String,
        birthMonth: String,
        birthYear: String,
        gender: String,
        password: String,
        wantsSms: Bool,
        acceptsTerms: Bool,
        coachCode: String,
        branchAssignments:
            [RegistrationFormState.BranchAssignment]? = nil,
        activeBranch: String? = nil,
        activeGroup: String? = nil
    ) {
        let defaults = UserDefaults.standard

        let cleanedFullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedGender = gender.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedCoachCode = coachCode.trimmingCharacters(in: .whitespacesAndNewlines)

        let resolvedRole = isCoach ? "coach" : "trainee"

        let codec = RegistrationFormState.BranchAssignmentsCodec.self

        let cleanedAssignments = branchAssignments.map {
            codec.sanitized($0)
        }

        let cleanedBranches: [String]
        let cleanedGroups: [String]

        if let cleanedAssignments {
            cleanedBranches = codec.flattenBranches(
                cleanedAssignments
            )
            cleanedGroups = codec.flattenGroups(
                cleanedAssignments
            )
        } else {
            cleanedBranches = branches
                .map {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
                .filter { !$0.isEmpty }
                .removingDuplicatesKeepingOrder()

            cleanedGroups = groups
                .map {
                    $0.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
                .filter { !$0.isEmpty }
                .removingDuplicatesKeepingOrder()
        }

        let requestedBranch = activeBranch?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""

        let firstBranch =
            cleanedBranches.contains(requestedBranch)
                ? requestedBranch
                : cleanedBranches.first ?? ""

        let availableActiveGroups: [String]

        if let cleanedAssignments {
            availableActiveGroups = cleanedAssignments
                .first { $0.branch == firstBranch }?
                .groups ?? []
        } else {
            availableActiveGroups = cleanedGroups
        }

        let requestedGroup = activeGroup?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""

        let firstGroup =
            availableActiveGroups.contains(requestedGroup)
                ? requestedGroup
                : availableActiveGroups.first ?? ""

        defaults.set(cleanedFullName, forKey: "fullName")
        defaults.set(cleanedFullName, forKey: "full_name")
        defaults.set(cleanedFullName, forKey: "kmi.user.fullName")

        defaults.set(cleanedPhone, forKey: "phone")
        defaults.set(cleanedPhone, forKey: "kmi.user.phone")

        defaults.set(cleanedEmail, forKey: "email")
        defaults.set(cleanedEmail, forKey: "kmi.user.email")

        defaults.set(cleanedRegion, forKey: "region")
        defaults.set(firstBranch, forKey: "branch")
        defaults.set(firstGroup, forKey: "group")

        defaults.set(resolvedRole, forKey: "user_role")
        defaults.set(cleanedUsername, forKey: "username")

        defaults.set(birthDay.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "birthDay")
        defaults.set(birthDay.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "birth_day")

        defaults.set(birthMonth.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "birthMonth")
        defaults.set(birthMonth.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "birth_month")

        defaults.set(birthYear.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "birthYear")
        defaults.set(birthYear.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "birth_year")

        defaults.set(cleanedGender, forKey: "gender")
        defaults.set(password, forKey: "password")

        defaults.set(cleanedBranches, forKey: "branches")
        defaults.set(cleanedGroups, forKey: "groups")

        if let cleanedAssignments {
            defaults.set(
                codec.encode(cleanedAssignments),
                forKey: codec.preferenceKey
            )
        }

        defaults.set(wantsSms, forKey: "wantsSms")
        defaults.set(wantsSms, forKey: "wants_sms")

        defaults.set(acceptsTerms, forKey: "acceptsTerms")
        defaults.set(acceptsTerms, forKey: "accepts_terms")

        defaults.set(cleanedCoachCode, forKey: "coachCode")
        defaults.set(cleanedCoachCode, forKey: "coach_code")

        saveRegionKeys(cleanedRegion, defaults: defaults)
        saveBranchKeys(firstBranch, defaults: defaults)
        saveGroupKeys(firstGroup, defaults: defaults)
        saveBeltKeys(from: belt, defaults: defaults)

        defaults.synchronize()

        DispatchQueue.main.async {
            self.fullName = cleanedFullName
            self.phone = cleanedPhone
            self.email = cleanedEmail
            self.region = cleanedRegion
            self.branch = firstBranch
            self.group = firstGroup
            self.userRole = resolvedRole
            self.currentBeltId = defaults.string(forKey: "current_belt") ?? self.currentBeltId
            self.currentBeltIdUser = defaults.string(forKey: "belt_current") ?? self.currentBeltIdUser
        }
    }
    
    func saveRegionKeys(_ value: String, defaults: UserDefaults) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)

        defaults.set(clean, forKey: "region")
        defaults.set(clean, forKey: "active_region")
        defaults.set(clean, forKey: "selected_region")
        defaults.set(clean, forKey: "current_region")
        defaults.set(clean, forKey: "kmi.user.region")
    }

    func saveBranchKeys(_ value: String, defaults: UserDefaults) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)

        defaults.set(clean, forKey: "branch")
        defaults.set(clean, forKey: "activeBranch")
        defaults.set(clean, forKey: "active_branch")
        defaults.set(clean, forKey: "selected_branch")
        defaults.set(clean, forKey: "current_branch")
        defaults.set(clean, forKey: "kmi.user.branch")
    }

    func saveGroupKeys(_ value: String, defaults: UserDefaults) {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)

        defaults.set(clean, forKey: "group")
        defaults.set(clean, forKey: "activeGroup")
        defaults.set(clean, forKey: "active_group")
        defaults.set(clean, forKey: "groupKey")
        defaults.set(clean, forKey: "group_key")
        defaults.set(clean, forKey: "primaryGroup")
        defaults.set(clean, forKey: "age_group")
        defaults.set(clean, forKey: "ageGroup")
        defaults.set(clean, forKey: "kmi.user.group")
    }

    func saveBeltKeys(from belt: String, defaults: UserDefaults) {
        let clean = belt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "חגורה", with: "")
            .replacingOccurrences(of: "belt", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let legacyAliases = [
            "לבן": "white",
            "צהוב": "yellow",
            "כתום": "orange",
            "ירוק": "green",
            "כחול": "blue",
            "חום": "brown",
            "שחור": "black"
        ]

        var form = RegistrationFormState()
        form.belt = legacyAliases[clean] ?? clean

        let beltId = form.currentBeltId

        guard !beltId.isEmpty else {
            return
        }

        defaults.set(beltId, forKey: "current_belt")
        defaults.set(beltId, forKey: "belt_current")
        defaults.set(beltId, forKey: "kmi.user.belt")
        defaults.set(beltId, forKey: "registered_belt")
        defaults.set(beltId, forKey: "rank")
        defaults.set(beltId, forKey: "rank_id")
    }
}

private extension Array where Element: Hashable {
    func removingDuplicatesKeepingOrder() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

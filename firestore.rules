rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // =========================
    // פונקציות עזר כלליות
    // =========================

    // משתמש מחובר?
    function isSignedIn() {
      return request.auth != null;
    }

    // זה הדוקומנט של המשתמש עצמו?
    // זה הדוקומנט של המשתמש עצמו?
    function isSelf(uid) {
      return isSignedIn()
        && request.auth.uid == uid;
    }

        // ✅ אדמין? נקבע לפי admins/{uid}.enabled == true
      function isAdmin() {
      return isSignedIn()
        && exists(/databases/$(database)/documents/admins/$(request.auth.uid))
        && get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.enabled == true;
    }

   // מאמן מורשה לפי מקור האמת המאובטח.
   // אין להסתמך כאן על role מתוך users או SharedPreferences.
function isAuthorizedCoach() {
  return isSignedIn()
    && exists(
      /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
    )
    && get(
      /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
    ).data.active == true
    && get(
      /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
    ).data.role == "coach";
}

function canViewTrainees() {
  return isAdmin()
    || (
      isAuthorizedCoach()
      && (
        get(
          /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
        ).data.canViewTrainees == true
        ||
        get(
          /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
        ).data.canManageTrainees == true
      )
    );
}

function canManageTrainees() {
  return isAdmin()
    || (
      isAuthorizedCoach()
      && get(
        /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
      ).data.canManageTrainees == true
    );
}

function canManageInternalExams() {
  return isAdmin()
    || (
      isAuthorizedCoach()
      && (
        get(
          /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
        ).data.canManageInternalExams == true
        ||
        get(
          /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
        ).data.canManageExams == true
      )
    );
}

    // יש למשתמש מסמך users/{uid}?
    function hasMyUserDoc() {
      return isSignedIn()
        && exists(/databases/$(database)/documents/users/$(request.auth.uid));
    }

    // נתוני המשתמש שלי
    function myUserData() {
      return get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
    }

    // האם המשתמש הוא מאמן / מנהל / אדמין לפי users
  function isCoachLike() {
  return isAdmin()
    || isAuthorizedCoach();
}

    // האם המשתמש שייך לסניף מסוים
    function userHasBranch(branch) {
      return branch is string
        && hasMyUserDoc()
        && (
          myUserData().branch == branch
          || myUserData().activeBranch == branch
          || myUserData().active_branch == branch
          || (myUserData().branches is list && branch in myUserData().branches)
        );
    }

    // מי רשאי לנהל נוכחות בסניף
    // Admin רשאי לכל הסניפים.
    // מאמן רשאי רק לסניפים שנשמרו עבורו
    // במקור האמת המאובטח authorizedCoaches/{uid}.
function canManageAttendanceBranch(branch) {
  return isAdmin()
    || (
      isAuthorizedCoach()

      && branch is string
      && branch.size() > 0

      && get(
        /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
      ).data.canManageAttendance == true

      && get(
        /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
      ).data.authorizedBranches is list

      && branch in get(
        /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
      ).data.authorizedBranches
    );
}

function canManageAttendanceBranchGroup(branch, groupKey) {
  return isAdmin()
    || (
      isAuthorizedCoach()

      && branch is string
      && branch.size() > 0

      && groupKey is string
      && groupKey.size() > 0

      && get(
        /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
      ).data.canManageAttendance == true

      && get(
        /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
      ).data.authorizedBranchGroups is list

      && (
        branch + "||" + groupKey
      ) in get(
        /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
      ).data.authorizedBranchGroups
    );
}

function canViewAttendanceBranchGroup(branch, groupKey) {
  return isAdmin()
    || (
      isAuthorizedCoach()

      && branch is string
      && branch.size() > 0

      && groupKey is string
      && groupKey.size() > 0

      && (
        get(
          /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
        ).data.canViewTrainees == true
        ||
        get(
          /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
        ).data.canManageTrainees == true
        ||
        get(
          /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
        ).data.canManageAttendance == true
      )

      && get(
        /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
      ).data.authorizedBranchGroups is list

      && (
        branch + "||" + groupKey
      ) in get(
        /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
      ).data.authorizedBranchGroups
    );
}

function isAuthorizedCoachForBranchGroup(branch, groupKey) {
  return isAdmin()
    || (
      isAuthorizedCoach()

      && branch is string
      && branch.size() > 0

      && groupKey is string
      && groupKey.size() > 0

      && get(
        /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
      ).data.authorizedBranchGroups is list

      && (
        branch + "||" + groupKey
      ) in get(
        /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
      ).data.authorizedBranchGroups
    );
}

function isAuthorizedCoachDisplayName(displayName) {
  return isAdmin()
    || (
      isAuthorizedCoach()

      && displayName is string

      && get(
        /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
      ).data.fullName is string

      && get(
        /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
      ).data.fullName.size() > 0

      && displayName == get(
        /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
      ).data.fullName
    );
}

function canViewAttendance() {
  return isAdmin()
    || canManageAttendanceBranch("")
    || canViewTrainees();
}

    // בדיקה לפי מסמך session אב עבור records
    function attendanceSessionExists(groupId, sessionId) {
      return exists(
        /databases/$(database)/documents/attendanceGroups/$(groupId)/sessions/$(sessionId)
      );
    }

    function attendanceParentGroupExists(groupId) {
      return exists(
        /databases/$(database)/documents/attendanceGroups/$(groupId)
      );
    }

    function attendanceParentGroupBranch(groupId) {
      return get(
        /databases/$(database)/documents/attendanceGroups/$(groupId)
      ).data.branch;
    }

    function attendanceParentGroupKey(groupId) {
      return get(
        /databases/$(database)/documents/attendanceGroups/$(groupId)
      ).data.groupKey;
    }

    function canManageAttendanceSession(groupId, sessionId) {
      return attendanceSessionExists(groupId, sessionId)
        && attendanceParentGroupExists(groupId)
        && canManageAttendanceBranchGroup(
          attendanceParentGroupBranch(groupId),
          attendanceParentGroupKey(groupId)
        );
    }

    // =========================
    // Admins – מאפשר בדיקת אדמין (רק המסמך של המשתמש עצמו)
    // admins/{uid}
    // =========================
    match /admins/{uid} {
      // כל משתמש מחובר יכול לקרוא רק את המסמך של עצמו
      // (אם לא קיים – פשוט יקבל "לא קיים")
      allow read: if isSignedIn() && request.auth.uid == uid;

      // כתיבה חסומה מהאפליקציה – רק דרך הקונסול
      allow write: if false;
    }

     // =========================
    // Authorized Coaches – מקור אמת להרשאת מאמן אחרי קישור UID
    // authorizedCoaches/{uid}
    // =========================
    match /authorizedCoaches/{uid} {

      // כל משתמש מחובר יכול לקרוא רק את מסמך ההרשאה של עצמו.
      // זה מאפשר למסך ההתחברות לבדוק:
      // active == true
      // role == "coach"
      allow get: if isSignedIn()
        && request.auth.uid == uid;

      // אין הרשאת list/query מהאפליקציה.
      // לכן לא מאפשרים whereEqualTo על האוסף הזה.
      allow list: if false;

      // יצירה / עדכון / מחיקה רק לאדמין פעיל.
      // בהמשך Cloud Function עם Admin SDK תוכל ליצור/לעדכן כאן אוטומטית.
      allow create, update, delete: if isAdmin();
    }

   // =========================
   // Training Overrides
   // ביטול או שינוי מופע אימון מסוים
   // trainingOverrides/{overrideId}
   // =========================
match /trainingOverrides/{overrideId} {

  /*
   * כל משתמש מחובר רשאי לקרוא שינויים באימונים.
   * כך מסך הבית, היומן, הארכיון והתזכורות
   * יכולים להתעדכן בזמן אמת.
   */
  allow get, list: if isSignedIn();

  /*
   * בדיקת שדות משותפים למסמך שינוי אימון.
   */
  function hasValidCommonOverrideData() {
    return request.resource.data.keys().hasOnly([
      "overrideId",
      "occurrenceKey",
      "type",

      "branch",
      "group",
      "place",
      "address",
      "coachName",

      "originalStartMillis",
      "originalEndMillis",

      "newStartMillis",
      "newEndMillis",

      "reason",

      "changedByUid",
      "changedByName",

      "isActive",

      "createdAt",
      "updatedAt",

      "notificationRequested",
      "notificationStatus",

      "restoredByUid",
      "restoredByName",
      "restoredAt",

      "source"
    ])

    && request.resource.data.keys().hasAll([
      "overrideId",
      "occurrenceKey",
      "type",

      "branch",
      "group",

      "originalStartMillis",
      "originalEndMillis",

      "reason",

      "changedByUid",
      "changedByName",

      "isActive",

      "createdAt",
      "updatedAt",

      "notificationRequested",
      "notificationStatus",

      "source"
    ])

    && request.resource.data.overrideId is string
    && request.resource.data.overrideId == overrideId
    && request.resource.data.overrideId.size() > 10
    && request.resource.data.overrideId.size() <= 128

    && request.resource.data.occurrenceKey is string
    && request.resource.data.occurrenceKey.size() > 5
    && request.resource.data.occurrenceKey.size() <= 1000

    && request.resource.data.type is string
    && request.resource.data.type in [
      "cancelled",
      "time_changed"
    ]

    && request.resource.data.branch is string
    && request.resource.data.branch.size() > 0
    && request.resource.data.branch.size() <= 200

    && request.resource.data.group is string
    && request.resource.data.group.size() > 0
    && request.resource.data.group.size() <= 200

    && request.resource.data.place is string
    && request.resource.data.place.size() <= 300

    && request.resource.data.address is string
    && request.resource.data.address.size() <= 500

    && request.resource.data.coachName is string
    && request.resource.data.coachName.size() <= 200

    && request.resource.data.originalStartMillis is int
    && request.resource.data.originalStartMillis > 0

    && request.resource.data.originalEndMillis is int
    && request.resource.data.originalEndMillis >
       request.resource.data.originalStartMillis

    && request.resource.data.reason is string
    && request.resource.data.reason.size() >= 3
    && request.resource.data.reason.size() <= 500

    && request.resource.data.changedByUid is string
    && request.resource.data.changedByUid.size() > 0

    && request.resource.data.changedByName is string
    && request.resource.data.changedByName.size() > 0
    && request.resource.data.changedByName.size() <= 200

    && request.resource.data.isActive is bool

    && request.resource.data.notificationRequested is bool
    && request.resource.data.notificationStatus is string
    && request.resource.data.notificationStatus in [
      "pending",
      "processing",
      "sent",
      "failed"
    ]

    && request.resource.data.source is string
    && request.resource.data.source ==
       "android_training_override";
  }

  /*
   * בביטול אימון אין חובה לשמור שעה חלופית.
   */
  function hasValidCancellationData() {
    return request.resource.data.type == "cancelled";
  }

  /*
   * בשינוי שעה חובה לשמור התחלה וסיום חדשים.
   */
  function hasValidTimeChangeData() {
    return request.resource.data.type == "time_changed"

      && request.resource.data.keys().hasAll([
        "newStartMillis",
        "newEndMillis"
      ])

      && request.resource.data.newStartMillis is int
      && request.resource.data.newStartMillis > 0

      && request.resource.data.newEndMillis is int
      && request.resource.data.newEndMillis >
         request.resource.data.newStartMillis;
  }

  /*
   * יצירת שינוי חדש:
   * רק מאמן מורשה או אדמין.
   */
  allow create: if
    isAuthorizedCoachForBranchGroup(
      request.resource.data.branch,
      request.resource.data.group
    )

    && hasValidCommonOverrideData()

    && (
      hasValidCancellationData()
      || hasValidTimeChangeData()
    )

    // מאמן יוצר שינוי רק בזהות המאומתת שלו.
    && (
      isAdmin()
      || (
        request.resource.data.changedByUid ==
          request.auth.uid

        && isAuthorizedCoachDisplayName(
          request.resource.data.changedByName
        )
      )
    )

    && request.resource.data.createdAt ==
       request.time

    && request.resource.data.updatedAt ==
       request.time

    && request.resource.data.isActive == true

    && request.resource.data.notificationRequested ==
       true

    && request.resource.data.notificationStatus ==
       "pending";

  /*
   * עדכון שינוי קיים:
   * המאמן שיצר את השינוי או אדמין.
   */
 allow update: if
   (
     isAdmin()
     || (
       isAuthorizedCoachForBranchGroup(
         resource.data.branch,
         resource.data.group
       )
       && resource.data.changedByUid ==
          request.auth.uid
     )
   )

   && hasValidCommonOverrideData()

    && (
      hasValidCancellationData()
      || hasValidTimeChangeData()
    )

    /*
     * זהות מופע האימון המקורי אינה משתנה.
     */
    && request.resource.data.overrideId ==
       resource.data.overrideId

    && request.resource.data.occurrenceKey ==
       resource.data.occurrenceKey

    && request.resource.data.branch ==
       resource.data.branch

    && request.resource.data.group ==
       resource.data.group

    && request.resource.data.place ==
       resource.data.place

    && request.resource.data.address ==
       resource.data.address

    && request.resource.data.coachName ==
       resource.data.coachName

    && request.resource.data.originalStartMillis ==
       resource.data.originalStartMillis

    && request.resource.data.originalEndMillis ==
       resource.data.originalEndMillis

    && request.resource.data.changedByUid ==
       resource.data.changedByUid

    && request.resource.data.changedByName ==
       resource.data.changedByName

    && request.resource.data.createdAt ==
       resource.data.createdAt

    && request.resource.data.source ==
       resource.data.source

    && request.resource.data.updatedAt ==
       request.time

    /*
     * כל שינוי חדש מבקש שוב עיבוד התראה.
     */
    && request.resource.data.notificationRequested ==
       true

    && request.resource.data.notificationStatus ==
       "pending"

    /*
     * כאשר מחזירים את האימון למצב המקורי,
     * חובה לשמור מי ביצע את ההחזרה ומתי.
     */
    && (
      request.resource.data.isActive == true
      || (
        request.resource.data.isActive == false

        && request.resource.data.keys().hasAll([
          "restoredByUid",
          "restoredByName",
          "restoredAt"
        ])

        && request.resource.data.restoredByUid is string
        && request.resource.data.restoredByUid.size() > 0

        && request.resource.data.restoredByName is string
        && request.resource.data.restoredByName.size() > 0

        && request.resource.data.restoredAt ==
           request.time

        && (
          isAdmin()
          || (
            request.resource.data.restoredByUid ==
              request.auth.uid

            && isAuthorizedCoachDisplayName(
              request.resource.data.restoredByName
            )
          )
        )
      )
    );

  /*
   * לא מוחקים מסמכים כדי לשמור היסטוריה.
   */
  allow delete: if false;
}

// =========================
// Training Occurrences
// מקור אמת לזמני מופעי אימון
// trainingOccurrences/{occurrenceId}
// =========================
match /trainingOccurrences/{occurrenceId} {

  /*
   * כל משתמש מחובר יכול לקרוא מופעי אימון.
   * מתאמנים לא יכולים ליצור או לשנות אותם.
   */
  allow read: if isSignedIn();

  /*
   * יצירת מופע אימון:
   * רק מאמן מורשה / אדמין.
   */
  allow create: if
    isAuthorizedCoachForBranchGroup(
      request.resource.data.branch,
      request.resource.data.group
    )

    && request.resource.data.keys().hasOnly([
      "occurrenceId",
      "occurrenceKey",
      "branch",
      "group",
      "place",
      "address",
      "coachName",
    "originalStartMillis",
"originalEndMillis",
"sessionDate",
"effectiveStartMillis",
      "effectiveEndMillis",
      "isCancelled",
      "updatedByUid",
      "source",
      "updatedAt"
    ])

 && request.resource.data.keys().hasAll([
  "occurrenceId",
  "occurrenceKey",
  "branch",
  "group",
  "originalStartMillis",
  "originalEndMillis",
  "sessionDate",
  "effectiveStartMillis",
  "effectiveEndMillis",
  "isCancelled",
  "updatedByUid",
  "source",
  "updatedAt"
])

    && request.resource.data.occurrenceId ==
       occurrenceId

    && request.resource.data.occurrenceKey is string
    && request.resource.data.occurrenceKey.size() > 5

    && request.resource.data.branch is string
    && request.resource.data.branch.size() > 0

    && request.resource.data.group is string
    && request.resource.data.group.size() > 0

    && request.resource.data.originalStartMillis is int
    && request.resource.data.originalStartMillis > 0

    && request.resource.data.originalEndMillis is int
    && request.resource.data.originalEndMillis >
       request.resource.data.originalStartMillis

&& request.resource.data.sessionDate is string
&& request.resource.data.sessionDate.size() == 10

    && request.resource.data.effectiveStartMillis is int
    && request.resource.data.effectiveStartMillis > 0

    && request.resource.data.effectiveEndMillis is int
    && request.resource.data.effectiveEndMillis >
       request.resource.data.effectiveStartMillis

    && request.resource.data.isCancelled is bool

    && request.resource.data.updatedByUid ==
       request.auth.uid

    && request.resource.data.source ==
       "android_training_occurrence"

    && request.resource.data.updatedAt ==
       request.time;

  /*
   * עדכון מופע קיים:
   * זהות האימון וזמן המקור אינם ניתנים לשינוי.
   *
   * רק הזמן האפקטיבי / ביטול / פרטי עדכון
   * יכולים להשתנות.
   */
 allow update: if
   isAuthorizedCoachForBranchGroup(
     resource.data.branch,
     resource.data.group
   )

   && request.resource.data.occurrenceId ==
      resource.data.occurrenceId

    && request.resource.data.occurrenceKey ==
       resource.data.occurrenceKey

    && request.resource.data.branch ==
       resource.data.branch

    && request.resource.data.group ==
       resource.data.group

    && request.resource.data.originalStartMillis ==
       resource.data.originalStartMillis

    && request.resource.data.originalEndMillis ==
       resource.data.originalEndMillis

&& request.resource.data.sessionDate ==
   resource.data.sessionDate

    && request.resource.data
        .diff(resource.data)
        .affectedKeys()
        .hasOnly([
          "effectiveStartMillis",
          "effectiveEndMillis",
          "isCancelled",
          "updatedByUid",
          "updatedAt"
        ])

    && request.resource.data.effectiveStartMillis is int
    && request.resource.data.effectiveStartMillis > 0

    && request.resource.data.effectiveEndMillis is int
    && request.resource.data.effectiveEndMillis >
       request.resource.data.effectiveStartMillis

    && request.resource.data.isCancelled is bool

    && request.resource.data.updatedByUid ==
       request.auth.uid

    && request.resource.data.source ==
       "android_training_occurrence"

    && request.resource.data.updatedAt ==
       request.time;

  /*
   * לא מוחקים מופעי אימון.
   * כך נשמר מקור אמת היסטורי.
   */
  allow delete: if false;
}

    // =========================
    // Coach Invites – הזמנות / פרופילים ראשוניים למאמנים
    // coachInvites/{phoneDigits}
    // =========================
    match /coachInvites/{phoneDigits} {

      // האפליקציה לא קוראת את רשימת המאמנים ישירות.
      // אימות וקישור מאמן יתבצעו דרך Cloud Function עם Admin SDK.
      allow get, list: if false;

      // ניהול רשימת מאמנים ידנית/אדמין בלבד.
      // אפשר להוסיף/לעדכן דרך Firebase Console או בעתיד ממסך אדמין מאובטח.
      allow create, update, delete: if isAdmin();
    }

      // =========================
    // אוסף users
    // =========================
    match /users/{uid} {
  // קריאה:
  // המשתמש רשאי לקרוא רק את המסמך של עצמו.
  // אדמין רשאי לקרוא את כלל המשתמשים.
  //
  // מאמנים אינם קוראים עוד users ישירות.
  // נתוני מתאמנים עבור מאמן מתקבלים דרך
  // Cloud Functions מאובטחות בלבד.
  allow read: if isSelf(uid)
          || isAdmin();

      // יצירה: המשתמש עצמו (או אדמין)
     allow create: if isAdmin()
              || (
                isSelf(uid)
                && request.resource.data.uid == uid
                && request.resource.data.role == "trainee"
              );

         // עדכון:
      // המשתמש עצמו או אדמין יכולים לעדכן הכל.
      // מאמן יכול לעדכן רק שדות מקצועיים של מתאמן:
      // תאריכי חגורות, השתלמויות, מחנות, הסמכות והערות מאמן.
   allow update: if (

       // =========================================
       // עדכון עצמי רגיל:
       // אסור לשנות שדות זהות / הרשאה / שיוך רגיש.
       // =========================================
     (
       isSelf(uid)
       && !request.resource.data
           .diff(resource.data)
           .affectedKeys()
           .hasAny([
             "uid",
             "role",
             "user_role",
             "userType",
             "isCoach",
             "roleLockedBy",
             "role_locked_by",
             "coachAuthorized",
             "coach_authorized",
             "branch",
             "activeBranch",
             "active_branch",
             "branches",
             "coachBranchAssignments"
           ])
     )

    ||

    // =========================================
    // השלמת טופס רישום ראשונית.
    //
    // מאפשרת למשתמש להשלים את הפרופיל שלו,
    // כולל role / branch / groups,
    // אבל אך ורק כמתאמן.
    // =========================================
    (
      isSelf(uid)

      // UID חייב להישאר זהה למשתמש המחובר.
      && request.resource.data.uid == uid

      // ברישום עצמי אי אפשר להעניק הרשאת מאמן.
      && request.resource.data.role == "trainee"
      && request.resource.data.user_role == "trainee"

      // חייב להיות רישום מהסכמה החדשה.
      && request.resource.data.registrationFormCompleted == true
      && request.resource.data.registrationSchemaVersion is int
      && request.resource.data.registrationSchemaVersion >= 3

      /*
       * משתמש מחובר רשאי להשלים או לרענן
       * את פרטי הרישום של עצמו גם אם קיים
       * מסמך ישן שסומן בעבר כרישום שהושלם.
       *
       * האבטחה נשמרת:
       * uid חייב להיות שלו,
       * role ו-user_role חייבים להישאר trainee,
       * ורק שדות הרישום המותרים ניתנים לשינוי.
       */

      // ניתן לשנות רק שדות ששייכים לטופס הרישום.
      && request.resource.data
          .diff(resource.data)
          .affectedKeys()
          .hasOnly([
            "uid",

            "role",
            "user_role",

            "fullName",

            "phone",
            "phoneNumber",
            "phoneRaw",

            "email",
            "emailLower",

            "authProvider",

            "region",
            "regions",
            "regionsCsv",

            "branch",
            "branches",
            "branchesCsv",
            "activeBranch",

            "groups",
            "groupsCsv",
            "primaryGroup",
            "activeGroup",
            "group",
            "age_group",

            "birthDate",
            "gender",

            "belt",
            "currentBelt",

            "profileCompleted",
            "registrationComplete",
            "profileCompletedAt",

            "registrationFormCompleted",
            "registrationSchemaVersion",
            "registrationCompletedBy",

            "subscribeSms",

            "isActive",
            "archived",

            "createdAt",
            "updatedAt"
          ])
    )

    ||

    isAdmin()
);

      // מחיקה: רק המשתמש עצמו או אדמין
      allow delete: if isSelf(uid) || isAdmin();

      // =========================
      // Training Summaries – סיכומי אימון של המשתמש
      // users/{uid}/training_summaries_TRAINEE/{summaryId}
      // users/{uid}/training_summaries_COACH/{summaryId}
      // =========================
      match /{summaryCollection}/{summaryId} {
        function isTrainingSummaryCollection() {
          return summaryCollection == "training_summaries_TRAINEE"
              || summaryCollection == "training_summaries_COACH";
        }

        allow read: if isTrainingSummaryCollection()
                    && (isSelf(uid) || isAdmin());

        allow create: if isTrainingSummaryCollection()
                      && (isSelf(uid) || isAdmin())
                      && request.resource.data.ownerUid == uid
                      && request.resource.data.dateIso is string
                      && request.resource.data.ownerRole is string;

        allow update: if isTrainingSummaryCollection()
                      && (isSelf(uid) || isAdmin())
                      && request.resource.data.ownerUid == uid
                      && resource.data.ownerUid == uid;

        allow delete: if isTrainingSummaryCollection()
                      && (isSelf(uid) || isAdmin());
      }
    }

      // =========================
    // פורום סניפים - מסלול ישן
    // branches/{branchId}/messages/{messageId}
    // =========================
    match /branches/{branchId}/messages/{messageId} {

      // קריאה – כל משתמש מחובר
      allow read: if isSignedIn();

      // יצירת הודעה – כל משתמש מחובר, רק בשם עצמו
      allow create: if isSignedIn()
        && request.resource.data.authorUid == request.auth.uid;

      // עדכון / מחיקה – רק מי שכתב את ההודעה או אדמין
      allow update, delete: if isSignedIn()
        && (
          request.auth.uid == resource.data.authorUid ||
          isAdmin()
        );
    }

    // =========================
    // פורום סניפים - מסלול חדש לפי חדרים
    // branches/{branchId}/forumRooms/{roomId}
    // branches/{branchId}/forumRooms/{roomId}/messages/{messageId}
    // =========================
match /branches/{branchId}/forumRooms/{roomId} {
  /*
   * כל גישת הלקוח לנתוני הפורום חסומה.
   *
   * קריאת חדרים / הודעות:
   * דרך Cloud Functions מאובטחות בלבד.
   *
   * יצירה / עריכה / מחיקה:
   * דרך Admin SDK בצד השרת בלבד.
   */
  allow read, create, update, delete: if false;

  match /messages/{messageId} {
    allow read, create, update, delete: if false;
  }
}

  // =========================
  // הודעות שידור למתאמנים
  // coachBroadcasts/{broadcastId}
  // coachBroadcasts/{broadcastId}/recipients/{uid}
  // =========================
match /coachBroadcasts/{broadcastId} {

  // =====================================================
  // מסמך שידור ראשי
  // =====================================================

  /*
   * קריאה:
   * - אדמין
   * - המאמן שיצר את השידור
   *
   * מתאמן אינו קורא את המסמך הראשי,
   * משום שהוא עשוי לכלול את רשימת היעד.
   */
  allow read: if isSignedIn()
    && (
      isAdmin()
      || request.auth.uid == resource.data.authorUid
    );

  /*
   * כל יצירה / שינוי / מחיקה של שידור ראשי
   * חסומים מהלקוח.
   *
   * יצירת שידור מתבצעת רק דרך:
   * createSecureCoachBroadcast
   *
   * Cloud Functions משתמשות ב-Admin SDK
   * ולכן אינן תלויות ב-Firestore Rules.
   */
  allow create, update, delete: if false;


  // =====================================================
  // רשומה אישית של נמען
  // coachBroadcasts/{broadcastId}/recipients/{uid}
  // =====================================================

  match /recipients/{uid} {

    /*
     * קריאה:
     * - הנמען עצמו
     * - אדמין
     * - המאמן שיצר את השידור
     */
    allow read: if isSignedIn()
      && (
        request.auth.uid == uid

        || isAdmin()

        || (
          isAuthorizedCoach()

          && exists(
            /databases/$(database)/documents/coachBroadcasts/$(broadcastId)
          )

          && get(
            /databases/$(database)/documents/coachBroadcasts/$(broadcastId)
          ).data.authorUid == request.auth.uid
        )
      );

    /*
     * יצירת recipient נעשית רק בשרת
     * ע"י onCoachBroadcastCreated.
     */
    allow create: if false;

    /*
     * המתאמן רשאי לשנות רק את מצב ההודעה האישי:
     * read / readAt / deleted / deletedAt.
     */
    allow update: if isSignedIn()

      && request.auth.uid == uid

      && resource.data.uid == uid
      && request.resource.data.uid == uid

      && resource.data.broadcastId == broadcastId
      && request.resource.data.broadcastId == broadcastId

      && request.resource.data
        .diff(resource.data)
        .affectedKeys()
        .hasOnly([
          "read",
          "readAt",
          "deleted",
          "deletedAt"
        ])

      && request.resource.data.read is bool
      && request.resource.data.deleted is bool;

    /*
     * מחיקה פיזית אינה מותרת מהאפליקציה.
     * משתמשים ב-soft delete.
     */
    allow delete: if false;
  }
}

  // =========================
  // Collection Group – recipients
  //
  // מאפשר למרכז ההודעות לבצע:
  // collectionGroup("recipients")
  // ולשלוף רק רשומות ששייכות למשתמש המחובר.
  // =========================
  match /{path=**}/recipients/{uid} {

    // מרכז ההודעות מבצע Collection Group Query
    // עם סינון לפי השדה uid.
    //
    // לכן הרשאת הקריאה חייבת להתאים
    // בדיוק לתנאי השאילתה בצד Android.
    allow read: if isSignedIn()
              && resource.data.uid == request.auth.uid;

    // הכתיבה ממשיכה להיות מנוהלת
    // על ידי ה-rule הספציפי של coachBroadcasts.
    allow create, delete: if false;

    // המשתמש רשאי לשנות רק את מצב ההודעה שלו.
    allow update: if isSignedIn()
               && request.auth.uid == uid

               && resource.data.uid == uid
               && request.resource.data.uid == uid

               && request.resource.data
                    .diff(resource.data)
                    .affectedKeys()
                    .hasOnly([
                      "read",
                      "readAt",
                      "deleted",
                      "deletedAt"
                    ])

               && request.resource.data.read is bool
               && request.resource.data.deleted is bool;
  }

    // =========================
    // רשימת מספרי טלפון מורשים
    // allowed_numbers/numbers
    // =========================
    match /allowed_numbers/{docId} {

      // קריאה: רק משתמש מחובר
      // (האפליקציה רק קוראת את הרשימה)
      allow read: if isSignedIn();

      // כתיבה: חסומה לחלוטין מהאפליקציה
      // (ניהול ידני בלבד דרך Firebase Console)
      allow write: if false;
    }

    // =========================
    // מספרים שכבר שימשו להתחברות
    // used_numbers/{phone}
    // =========================
match /used_numbers/{phone} {

  allow read: if isSignedIn();

  allow create: if isSignedIn()
    && request.resource.data.keys().hasOnly([
      "usedAt"
    ])
    && request.resource.data.usedAt != null;

  allow update, delete: if false;
}

    // =========================
    // AI Feedback – מסכי מנהל
    // =========================
    match /aiFeedback/{docId} {
      allow read: if isAdmin();
      allow write: if isSignedIn();
    }

     match /assistantFeedback/{docId} {
      allow read: if isAdmin();
      allow write: if isSignedIn();
    }

 // =========================
 // Free Sessions – אימונים חופשיים
 // כל הגישה מתבצעת דרך Cloud Functions מאובטחות.
 // =========================
 match /branches/{branch}/groups/{groupKey}/free_sessions/{sessionId} {

   // אין קריאה או כתיבה ישירה מהאפליקציה.
   allow read, create, update, delete: if false;
 }


 // =========================
 // Free Sessions Participants
 // כל הגישה מתבצעת דרך Cloud Functions מאובטחות.
 // =========================
 match /branches/{branch}/groups/{groupKey}/free_sessions/{sessionId}/participants/{uid} {

   // אין קריאה או כתיבה ישירה מהאפליקציה.
   allow read, create, update, delete: if false;
 }

      // =========================
    // Attendance – נוכחות קבוצות
    // פתוח למשתמשים מחוברים בשלב בדיקות,
    // כי הגישה למסכי נוכחות מוגבלת באפליקציה למאמנים בלבד.
    //
    // attendanceGroups/{groupId}
    // attendanceGroups/{groupId}/members/{memberId}
    // attendanceGroups/{groupId}/sessions/{sessionId}
    // attendanceGroups/{groupId}/sessions/{sessionId}/records/{recordId}
    // attendanceGroups/{groupId}/reports/{reportId}
    // =========================
 match /attendanceGroups/{groupId} {

  function attendanceGroupExists() {
    return exists(/databases/$(database)/documents/attendanceGroups/$(groupId));
  }

  function attendanceGroupBranch() {
    return get(
      /databases/$(database)/documents/attendanceGroups/$(groupId)
    ).data.branch;
  }

  function attendanceGroupKey() {
    return get(
      /databases/$(database)/documents/attendanceGroups/$(groupId)
    ).data.groupKey;
  }

  function canManageThisAttendanceGroup() {
    return attendanceGroupExists()
      && canManageAttendanceBranchGroup(
        attendanceGroupBranch(),
        attendanceGroupKey()
      );
  }

  // מסמך הקבוצה עצמו
  // מאמן רואה רק קבוצה ששויכה אליו במקור האמת המאובטח.
  allow read: if
    attendanceGroupExists()
    && canViewAttendanceBranchGroup(
         attendanceGroupBranch(),
         attendanceGroupKey()
       );

  allow create: if isSignedIn()
    && request.resource.data.branch is string
    && request.resource.data.groupKey is string
    && canManageAttendanceBranchGroup(
         request.resource.data.branch,
         request.resource.data.groupKey
       );

  allow update: if isSignedIn()
    && resource.data.branch is string
    && resource.data.groupKey is string
    && request.resource.data.branch ==
       resource.data.branch
    && request.resource.data.groupKey ==
       resource.data.groupKey
    && canManageAttendanceBranchGroup(
         resource.data.branch,
         resource.data.groupKey
       );

  allow delete: if isAdmin();

  // מתאמנים בקבוצה
match /members/{memberId} {

  /*
   * מאמן / אדמין רשאים לקרוא חברים
   * רק בקבוצה המורשית המדויקת.
   *
   * מתאמן רשאי לקרוא רק את מסמך ה-member
   * שמקושר ל-Firebase UID שלו.
   */
  allow read: if
    (
      attendanceGroupExists()
      && canViewAttendanceBranchGroup(
           attendanceGroupBranch(),
           attendanceGroupKey()
         )
    )
    || (
      isSignedIn()
      && resource.data.authUid == request.auth.uid
    );

  /*
   * יצירה / שינוי / מחיקה של חברי הקבוצה
   * נשארים בשליטת מאמן / אדמין בלבד.
   */
  allow create, update, delete: if
    isSignedIn()
    && canManageThisAttendanceGroup();
}

// שיעורי נוכחות
match /sessions/{sessionId} {

  allow read: if
    attendanceGroupExists()
    && canViewAttendanceBranchGroup(
         attendanceGroupBranch(),
         attendanceGroupKey()
       );

  allow create: if isSignedIn()
    && request.resource.data.branch is string
    && canManageThisAttendanceGroup()
    && request.resource.data.branch ==
       attendanceGroupBranch();

  allow update: if isSignedIn()
    && resource.data.branch is string
    && request.resource.data.branch ==
       resource.data.branch
    && request.resource.data.branch ==
       attendanceGroupBranch()
    && canManageThisAttendanceGroup();

  allow delete: if isSignedIn()
    && canManageThisAttendanceGroup();

// סימוני נוכחות לכל מתאמן בשיעור
match /records/{recordId} {

  /*
   * האם recordId שייך ל-member של
   * המשתמש המחובר.
   *
   * אצלנו recordId == memberId,
   * ולכן אפשר לבדוק ישירות מול:
   *
   * attendanceGroups/{groupId}/members/{recordId}
   */
  function isOwnAttendanceRecord() {
    return isSignedIn()
      && exists(
        /databases/$(database)/documents/attendanceGroups/$(groupId)/members/$(recordId)
      )
      && get(
        /databases/$(database)/documents/attendanceGroups/$(groupId)/members/$(recordId)
      ).data.authUid == request.auth.uid;
  }

  /*
   * בדיקת מבנה הסימון העצמי של המתאמן.
   */
function isValidTraineeAttendanceData() {

  return isSignedIn()

    && request.resource.data.keys().hasAll([
      "id",
      "sessionId",
      "memberId",
      "status",
      "traineeUid",
      "markedBy",
      "trainingStartMillis",
      "occurrenceKey",
      "occurrenceId",
      "markedAtMillis",
      "updatedAtMillis",
      "updatedAt"
    ])

    && request.resource.data.status in [
      "PRESENT",
      "ABSENT"
    ]

    && request.resource.data.traineeUid ==
       request.auth.uid

    && request.resource.data.markedBy ==
       "trainee"

    /*
     * trainingStartMillis נשאר לצורכי תאימות בלבד.
     * הוא אינו מקור האמת לנעילה.
     */
    && request.resource.data.trainingStartMillis is int

    && request.resource.data.occurrenceKey is string
    && request.resource.data.occurrenceKey.size() > 5

    && request.resource.data.occurrenceId is string
    && request.resource.data.occurrenceId.size() > 10

    /*
     * חייב להיות מופע אימון מאומת ב-Firestore.
     */
    && exists(
      /databases/$(database)/documents/trainingOccurrences/$(request.resource.data.occurrenceId)
    )

    /*
     * occurrenceId חייב להצביע בדיוק
     * לאותו occurrenceKey שנשמר ברשומה.
     */
    && get(
      /databases/$(database)/documents/trainingOccurrences/$(request.resource.data.occurrenceId)
    ).data.occurrenceKey ==
       request.resource.data.occurrenceKey

    /*
     * המופע חייב להשתייך לאותו תאריך
     * של sessions/{sessionId}.
     */
    && get(
      /databases/$(database)/documents/trainingOccurrences/$(request.resource.data.occurrenceId)
    ).data.sessionDate ==
       sessionId

          /*
           * זהות המתאמן נבדקת מול מסמך ה-member.
           * מסמכי member ישנים אינם מחויבים להכיל
           * branch ו-groupKey ולכן לא משווים אליהם.
           */

    /*
     * אימון שבוטל אינו פתוח לסימון.
     */
    && get(
      /databases/$(database)/documents/trainingOccurrences/$(request.resource.data.occurrenceId)
    ).data.isCancelled == false

    /*
     * כאן נמצאת הנעילה האמיתית:
     * request.time הוא זמן שרת Firestore,
     * ו-effectiveStartMillis מגיע ממסמך
     * שהמתאמן אינו רשאי לערוך.
     */
    && request.time.toMillis() <
       get(
         /databases/$(database)/documents/trainingOccurrences/$(request.resource.data.occurrenceId)
       ).data.effectiveStartMillis

    /*
     * memberId חייב להשתייך למשתמש המחובר.
     */
    && request.resource.data.memberId ==
       get(
         /databases/$(database)/documents/attendanceGroups/$(groupId)/members/$(recordId)
       ).data.id;
}

  /*
   * קריאה:
   * מאמן רואה את כל הרשומות.
   * מתאמן רואה רק את הרשומה שלו.
   */
  allow read: if
    (
      attendanceGroupExists()
      && canViewAttendanceBranchGroup(
           attendanceGroupBranch(),
           attendanceGroupKey()
         )
    )
    || isOwnAttendanceRecord();

   /*
    * יצירת בחירה ראשונה על ידי המתאמן.
    *
    * מותר ליצור רק רשומה אישית, עבור מופע אימון
    * מאומת שעדיין לא התחיל ושייך לאותה קבוצה.
    */
   allow create: if
     (
       isSignedIn()
       && canManageAttendanceSession(
            groupId,
            sessionId
          )
     )
     ||
     (
       isOwnAttendanceRecord()

       && request.resource.data.memberId ==
          get(
            /databases/$(database)/documents/attendanceGroups/$(groupId)/members/$(recordId)
          ).data.id

       && request.resource.data.traineeUid ==
          request.auth.uid

       && request.resource.data.markedBy ==
          "trainee"

       && request.resource.data.status in [
         "PRESENT",
         "ABSENT"
       ]

       && request.resource.data.traineeStatus in [
         "PRESENT",
         "ABSENT"
       ]

       && request.resource.data.occurrenceId is string
       && request.resource.data.occurrenceKey is string

       && exists(
         /databases/$(database)/documents/trainingOccurrences/$(request.resource.data.occurrenceId)
       )

       && get(
         /databases/$(database)/documents/trainingOccurrences/$(request.resource.data.occurrenceId)
       ).data.occurrenceKey ==
          request.resource.data.occurrenceKey

       && get(
         /databases/$(database)/documents/trainingOccurrences/$(request.resource.data.occurrenceId)
       ).data.sessionDate ==
          sessionId

       /*
        * תאימות למסמכי member ישנים שאינם כוללים
        * את השדות branch ו-groupKey.
        */

       && get(
         /databases/$(database)/documents/trainingOccurrences/$(request.resource.data.occurrenceId)
       ).data.isCancelled == false

       && request.time.toMillis() <
          get(
            /databases/$(database)/documents/trainingOccurrences/$(request.resource.data.occurrenceId)
          ).data.effectiveStartMillis
     );

  /*
   * שינוי בחירה קיימת.
   *
   * המאמן ממשיך לעבוד בדיוק כמו קודם.
   * המתאמן יכול לשנות רק שדות שקשורים
   * לבחירה העצמית שלו.
   */
  allow update: if
    (
      isSignedIn()
      && canManageAttendanceSession(
           groupId,
           sessionId
         )
    )
    ||
    (
      isOwnAttendanceRecord()

      && isValidTraineeAttendanceData()

      && request.resource.data
          .diff(resource.data)
          .affectedKeys()
              .hasOnly([
          "status",
          "traineeStatus",
          "traineeUid",
          "markedBy",
          "trainingStartMillis",
          "occurrenceKey",
          "occurrenceId",
          "markedAtMillis",
          "updatedAtMillis",
          "updatedAt"
        ])

      /*
       * אסור למתאמן להעביר את הרשומה
       * ל-member/session אחרים.
       */
      && request.resource.data.id ==
         resource.data.id

      && request.resource.data.sessionId ==
         resource.data.sessionId

      && request.resource.data.memberId ==
         resource.data.memberId
    );

  /*
   * מתאמן לא מוחק רשומות.
   * מחיקה נשארת רק למאמן / אדמין.
   */
  allow delete: if
    isSignedIn()
    && canManageAttendanceSession(
         groupId,
         sessionId
       );
}
  }

 // דוחות נוכחות שמורים
match /reports/{reportId} {
  allow read: if
    attendanceGroupExists()
    && canViewAttendanceBranchGroup(
         attendanceGroupBranch(),
         attendanceGroupKey()
       );

  allow create, update, delete: if isSignedIn()
    && canManageThisAttendanceGroup();
}
}

      // =========================
    // Internal Exam – מבחן פנימי
    // internalExamDrafts/{draftId}
    // internalExamResults/{resultId}
    // internalExamCoachState/{coachUid}
    // internalExamRecentTrainees/{coachUid}/trainees/{traineeKey}
    // =========================

   match /internalExamDrafts/{draftId} {

     // יצירת טיוטה:
     // המאמן חייב להיות מורשה למבחנים,
     // המסמך חייב להיות שלו,
     // והסניף + קבוצה חייבים להיות בתחום ההרשאה שלו.
     allow create: if
       isAdmin()
       || (
         canManageInternalExams()

         && request.resource.data.coachUid ==
            request.auth.uid

         && isAuthorizedCoachForBranchGroup(
              request.resource.data.branch,
              request.resource.data.group
            )
       );

     // עדכון טיוטה:
     // אי אפשר להעביר את הטיוטה למאמן אחר
     // או לשנות לה סניף / קבוצה לאחר שנוצרה.
     allow update: if
       isAdmin()
       || (
         canManageInternalExams()

         && resource.data.coachUid ==
            request.auth.uid

         && request.resource.data.coachUid ==
            resource.data.coachUid

         && request.resource.data.branch ==
            resource.data.branch

         && request.resource.data.group ==
            resource.data.group

         && isAuthorizedCoachForBranchGroup(
              resource.data.branch,
              resource.data.group
            )
       );

     // קריאה ומחיקה:
     // רק המאמן שיצר את הטיוטה ובתחום ההרשאה הנוכחי שלו.
     allow read, delete: if
       isAdmin()
       || (
         canManageInternalExams()

         && resource.data.coachUid ==
            request.auth.uid

         && isAuthorizedCoachForBranchGroup(
              resource.data.branch,
              resource.data.group
            )
       );
   }

   match /internalExamResults/{resultId} {

     // יצירת תוצאה סופית.
     allow create: if
       isAdmin()
       || (
         canManageInternalExams()

         && request.resource.data.coachUid ==
            request.auth.uid

         && isAuthorizedCoachForBranchGroup(
              request.resource.data.branch,
              request.resource.data.group
            )
       );

     // עדכון תוצאה קיימת:
     // זהות המאמן והשיוך הארגוני אינם ניתנים לשינוי.
     allow update: if
       isAdmin()
       || (
         canManageInternalExams()

         && resource.data.coachUid ==
            request.auth.uid

         && request.resource.data.coachUid ==
            resource.data.coachUid

         && request.resource.data.branch ==
            resource.data.branch

         && request.resource.data.group ==
            resource.data.group

         && isAuthorizedCoachForBranchGroup(
              resource.data.branch,
              resource.data.group
            )
       );

     // קריאה ומחיקה של תוצאה קיימת.
     allow read, delete: if
       isAdmin()
       || (
         canManageInternalExams()

         && resource.data.coachUid ==
            request.auth.uid

         && isAuthorizedCoachForBranchGroup(
              resource.data.branch,
              resource.data.group
            )
       );
   }

match /internalExamCoachState/{coachUid} {
  allow read, write: if canManageInternalExams()
    && request.auth.uid == coachUid;
}

match /internalExamRecentTrainees/{coachUid} {

  // מסמך האב אינו מכיל מידע שנדרש לאפליקציה.
  // הגישה בפועל מתבצעת רק דרך תת־האוסף trainees.
  allow read, write: if false;

  match /trainees/{traineeDocId} {

    // יצירת נבחן אחרון:
    // רק המאמן עצמו ורק עבור סניף + קבוצה שמורשים לו.
    allow create: if
      isAdmin()
      || (
        canManageInternalExams()

        && request.auth.uid == coachUid

        && request.resource.data.coachUid ==
           request.auth.uid

        && request.resource.data.branch is string
        && request.resource.data.group is string

        && isAuthorizedCoachForBranchGroup(
             request.resource.data.branch,
             request.resource.data.group
           )
      );

    // עדכון:
    // אסור להעביר רשומה למאמן / סניף / קבוצה אחרים.
    allow update: if
      isAdmin()
      || (
        canManageInternalExams()

        && request.auth.uid == coachUid

        && resource.data.coachUid ==
           request.auth.uid

        && request.resource.data.coachUid ==
           resource.data.coachUid

        && request.resource.data.branch ==
           resource.data.branch

        && request.resource.data.group ==
           resource.data.group

        && isAuthorizedCoachForBranchGroup(
             resource.data.branch,
             resource.data.group
           )
      );

    // קריאה:
    // Query חייב להחזיר רק מסמכים מתוך
    // branch + group המורשים למאמן.
    allow read: if
      isAdmin()
      || (
        canManageInternalExams()

        && request.auth.uid == coachUid

        && resource.data.coachUid ==
           request.auth.uid

        && isAuthorizedCoachForBranchGroup(
             resource.data.branch,
             resource.data.group
           )
      );

    // מחיקה:
    // רק מתוך הקבוצה המורשית של המאמן.
    allow delete: if
      isAdmin()
      || (
        canManageInternalExams()

        && request.auth.uid == coachUid

        && resource.data.coachUid ==
           request.auth.uid

        && isAuthorizedCoachForBranchGroup(
             resource.data.branch,
             resource.data.group
           )
      );
  }
}

        // =========================
    // Membership Payments – דמי חבר / דוח תשלומים
    // membershipPayments/{paymentId}
    // membershipPayments/{paymentId}/history/{historyId}
    // =========================
    match /membershipPayments/{paymentId} {

      // קריאה:
      // אדמין / מאמן / מנהל יכולים לקרוא את דוח התשלומים.
      // משתמש רגיל יכול לקרוא רק מסמך תשלום ששייך אליו.
   allow read: if isSignedIn()
     && (
       isAdmin()

       || paymentId == request.auth.uid

       || resource.data.traineeId == request.auth.uid

       || resource.data.userDocId == request.auth.uid

       || resource.data.uid == request.auth.uid

       || resource.data.authUid == request.auth.uid
     );

      // יצירה / עדכון:
      // בשלב הנוכחי מסך דוח התשלומים מאפשר למנהל/מאמן לעדכן תשלום ידני.
      // משתמש רגיל לא כותב ישירות לכאן.
     allow create, update: if isSignedIn()
  && (
    isAdmin()
    || (
      isAuthorizedCoach()
      && get(
        /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
      ).data.canManagePayments == true
    )
  );

      // מחיקה רק לאדמין
      allow delete: if isAdmin();

      match /history/{historyId} {

        // קריאת היסטוריה למנהלים/מאמנים/אדמין
    allow read: if isSignedIn()
  && (
    isAdmin()
    || (
      isAuthorizedCoach()
      && (
        get(
          /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
        ).data.canViewPaymentReports == true
        ||
        get(
          /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
        ).data.canManagePayments == true
      )
    )
  );

        // כתיבת היסטוריה כשמעדכנים תשלום ידני
     allow create, update: if isSignedIn()
  && (
    isAdmin()
    || (
      isAuthorizedCoach()
      && get(
        /databases/$(database)/documents/authorizedCoaches/$(request.auth.uid)
      ).data.canManagePayments == true
    )
  );

        allow delete: if isAdmin();
      }
    }

   // =========================
// User Progress – סיכום התקדמות אישי לפי משתמש + חגורה
// userProgress/{uid}__{beltId}
// =========================
match /userProgress/{progressId} {

  /*
   * קריאה:
   * - משתמש רשאי לקרוא רק את נתוני ההתקדמות שלו.
   * - אדמין רשאי לקרוא את כלל הנתונים.
   *
   * השוואות בין משתמשים וסטטיסטיקות קבוצתיות
   * מתבצעות רק דרך Cloud Functions מאובטחות.
   */
  allow read: if isSignedIn()
    && (
      isAdmin()
      || resource.data.uid == request.auth.uid
    );

  /*
   * המשתמש רשאי ליצור או לעדכן רק מסמך ששייך אליו.
   *
   * שם המסמך החדש בנוי כך:
   *     {uid}__{beltId}
   *
   * בנוסף בודקים שה-uid שבתוכן המסמך הוא באמת
   * ה-UID של המשתמש המחובר.
   */
    allow create, update: if isSignedIn()
    && request.resource.data.keys().hasOnly([
      "uid",
      "beltId",
      "knownPercent",
      "knownCount",
      "totalCount",
      "bucket",
      "updatedAt"
    ])
    && request.resource.data.keys().hasAll([
      "uid",
      "beltId",
      "knownPercent",
      "knownCount",
      "totalCount",
      "bucket",
      "updatedAt"
    ])
    && progressId == request.auth.uid + "__" + request.resource.data.beltId
    && request.resource.data.uid == request.auth.uid
    && request.resource.data.beltId is string
    && request.resource.data.beltId.size() > 0
    && request.resource.data.beltId.size() <= 50
    && request.resource.data.knownPercent is int
    && request.resource.data.knownCount is int
    && request.resource.data.totalCount is int
    && request.resource.data.bucket is int
    && request.resource.data.knownPercent >= 0
    && request.resource.data.knownPercent <= 100
    && request.resource.data.knownCount >= 0
    && request.resource.data.totalCount >= 0
    && request.resource.data.knownCount <= request.resource.data.totalCount
    && request.resource.data.bucket in [
      0,
      10,
      20,
      30,
      40,
      50,
      60,
      70,
      80,
      90,
      100
    ];

  // מחיקה רק לאדמין.
  allow delete: if isAdmin();
}

// =========================
// Belt Stats – סטטיסטיקה מצטברת לפי חגורה
// // beltStats/{beltId}
// =========================
match /beltStats/{beltId} {
  // כל משתמש מחובר יכול לקרוא נתונים מצטברים בלבד.
  allow read: if isSignedIn();

  // האפליקציה לא כותבת לכאן.
  // הכתיבה מתבצעת רק דרך Cloud Function עם Admin SDK.
  allow write: if false;
}

// =========================
// Admin Logs – מרכז בקרה ולוגים
// adminLogs/{logId}
// =========================
match /adminLogs/{logId} {

  // יצירת לוג במבנה מוגדר בלבד.
  allow create: if isSignedIn()
    && request.resource.data.keys().hasOnly([
      "createdAt",
      "level",
      "source",
      "action",
      "message",
      "uid",
      "email",
      "metadata"
    ])
    && request.resource.data.createdAt != null
    && request.resource.data.level is string
    && request.resource.data.source is string
    && request.resource.data.action is string
    && request.resource.data.message is string
    && request.resource.data.uid == request.auth.uid;

  // קריאה רק לאדמין.
  allow read: if isAdmin();

  // אין עריכה או מחיקה מהאפליקציה.
  allow update, delete: if false;
}

// =========================
// Google Auth Diagnostics – אבחון התחברות Google
// google_auth_diagnostics/{docId}
// =========================
match /google_auth_diagnostics/{docId} {

  allow create: if request.resource.data.keys().hasOnly([
      "createdAt",
      "stage",
      "message",

      "applicationId",
      "versionName",
      "versionCode",

      "defaultWebClientId",
      "googleAppId",

      "deviceManufacturer",
      "deviceModel",
      "androidRelease",
      "androidSdk",

      "firebaseUid",
      "firebaseEmail",
      "firebaseIsAnonymous",

      "errorClass",
      "errorMessage",
      "apiStatusCode",

      "source"
    ])
    && request.resource.data.createdAt != null
    && request.resource.data.stage is string
    && request.resource.data.message is string
    && request.resource.data.applicationId is string
    && request.resource.data.versionName is string
    && request.resource.data.versionCode is int
    && request.resource.data.source == "android_google_auth";

  allow read: if isAdmin();

  allow update, delete: if false;
}

// =========================
// Screen Views – סטטיסטיקת צפיות במסכים
// screen_views/{screenId}
// =========================
match /screen_views/{screenId} {

  allow read: if isAdmin();

  allow create: if isSignedIn()
    && request.resource.data.keys().hasOnly([
      "screenId",
      "count",
      "lastViewedAt",
      "updatedBy"
    ])
    && request.resource.data.screenId == screenId
    && request.resource.data.count is int
    && request.resource.data.count >= 1
    && request.resource.data.updatedBy == request.auth.uid
    && request.resource.data.lastViewedAt != null;

  allow update: if isSignedIn()
    && request.resource.data.diff(resource.data).affectedKeys().hasOnly([
      "count",
      "lastViewedAt",
      "updatedBy"
    ])
    && request.resource.data.screenId == resource.data.screenId
    && request.resource.data.count is int
    && request.resource.data.count >= resource.data.count
    && request.resource.data.updatedBy == request.auth.uid
    && request.resource.data.lastViewedAt != null;

  allow delete: if isAdmin();
}

    // =========================
    // ברירת מחדל – הכל חסום
    // =========================
    match /{document=**} {
      allow read, write: if false;
            }

  }
}

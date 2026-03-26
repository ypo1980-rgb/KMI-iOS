import SwiftUI

struct AdminGateView: View {
    @State private var isLoading = true
    @State private var isAdmin = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("בודק הרשאות...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isAdmin {
                AdminUsersView()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(.red)

                    Text("אין לך הרשאת מנהל")
                        .font(.system(size: 22, weight: .bold))

                    Text("המסך הזה זמין רק למנהלים מורשים.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await checkAdminAccess()
        }
    }

    @MainActor
    private func checkAdminAccess() async {
        isLoading = true
        isAdmin = await AdminAccessService.isCurrentUserAdmin()
        isLoading = false
    }
}

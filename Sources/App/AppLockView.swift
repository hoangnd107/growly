import SwiftUI
import LocalAuthentication

struct AppLockView: View {
  @Binding var unlocked: Bool
  @State private var didFail = false

  var body: some View {
    VStack(spacing: DLSpace.lg) {
      Spacer()
      Image(systemName: "lock.shield.fill")
        .font(.system(size: 56))
        .foregroundStyle(.tint)
      Text("Your journal is private")
        .font(.dl(.title2, weight: .bold))
        .foregroundStyle(DLColor.textPrimary)
      Text("Unlock with Face ID to continue.")
        .font(.dl(.subheadline))
        .foregroundStyle(DLColor.textSecondary)
      Spacer()
      Button(action: authenticate) {
        Label("Unlock", systemImage: "faceid")
          .font(.dl(.headline, weight: .semibold))
          .frame(maxWidth: .infinity)
          .padding()
          .background(.tint, in: RoundedRectangle(cornerRadius: DLRadius.small))
          .foregroundStyle(.white)
      }
      .padding(.horizontal, DLSpace.lg)
      .padding(.bottom, DLSpace.xl)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(DLColor.background)
    .onAppear(perform: authenticate)
  }

  private func authenticate() {
    let context = LAContext()
    var error: NSError?
    if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
      context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your private journal") { success, _ in
        Task { @MainActor in
          if success { unlocked = true } else { didFail = true }
        }
      }
    } else {
      // No biometrics/passcode available — don't lock the user out.
      unlocked = true
    }
  }
}

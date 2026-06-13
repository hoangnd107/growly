import SwiftUI

struct PrimaryButton: View {
  let title: String
  var systemImage: String?
  var isEnabled: Bool = true
  let action: () -> Void

  init(_ title: String, systemImage: String? = nil, isEnabled: Bool = true, action: @escaping () -> Void) {
    self.title = title
    self.systemImage = systemImage
    self.isEnabled = isEnabled
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: DLSpace.sm) {
        if let systemImage { Image(systemName: systemImage) }
        Text(title).font(.dl(.headline, weight: .semibold))
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 16)
      .background(
        isEnabled ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(DLColor.separator),
        in: RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
      )
      .foregroundStyle(isEnabled ? Color.white : DLColor.textSecondary)
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
  }
}

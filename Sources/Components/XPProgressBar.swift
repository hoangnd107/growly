import SwiftUI

struct XPProgressBar: View {
  /// 0...1
  let value: Double
  var height: CGFloat = 10

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule().fill(DLColor.separator)
        Capsule()
          .fill(
            LinearGradient(
              colors: [DLColor.xpGold, Color(hex: 0xFF9F0A)],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .frame(width: max(0, min(1, value)) * geo.size.width)
      }
    }
    .frame(height: height)
  }
}

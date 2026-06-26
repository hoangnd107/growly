import SwiftUI

/// Shared color presets for the habit, mood, and finance-category pickers, so the
/// palette is identical everywhere a color is chosen. Hex strings (no "#"), curated
/// across the spectrum with the app violet first.
enum ColorPaletteOption {
  static let presets: [String] = [
    "7E5BEF", "4C5FD5", "2D9CDB", "5AC8FA", "30B0C7",
    "2EC4B6", "34C759", "8CCF4D", "FFC83D", "FF9F0A",
    "FF7849", "E5484D", "FF5C8A", "C640E0", "AF52DE", "8E8E93",
  ]
}

/// A compact color field: a swatch button that opens a popover with the shared
/// preset swatches — drawn in their TRUE colors — plus a native `ColorPicker` for
/// any custom color.
///
/// Replaces the previous `Menu`-based pickers, where SwiftUI tinted every menu
/// item's icon with the app accent, so all the "color" dots looked identical
/// regardless of their hex. The popover draws real `Circle` swatches (no mis-tint)
/// and the `ColorPicker` adds fully custom colors beyond the presets.
struct ColorSwatchPicker: View {
  @Binding var hex: String
  var presets: [String] = ColorPaletteOption.presets
  /// Called after the bound hex changes (persist + haptics live here).
  var onChange: () -> Void = {}

  @State private var showPalette = false

  private let columns = Array(repeating: GridItem(.fixed(34), spacing: DLSpace.sm), count: 5)

  private var colorBinding: Binding<Color> {
    Binding(
      get: { Color(hexString: hex) },
      set: { newColor in
        hex = newColor.toHexString()
        onChange()
      }
    )
  }

  var body: some View {
    Button {
      showPalette = true
    } label: {
      Circle()
        .fill(Color(hexString: hex))
        .frame(width: 26, height: 26)
        .overlay(Circle().strokeBorder(DLColor.separator, lineWidth: 1))
        .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(L("Color"))
    .popover(isPresented: $showPalette) {
      paletteContent
        .presentationCompactAdaptation(.popover)
    }
  }

  private var paletteContent: some View {
    VStack(alignment: .leading, spacing: DLSpace.md) {
      LazyVGrid(columns: columns, spacing: DLSpace.sm) {
        ForEach(presets, id: \.self) { preset in
          swatch(preset)
        }
      }
      Divider().overlay(DLColor.separator)
      ColorPicker(selection: colorBinding, supportsOpacity: false) {
        Text(L("Custom color"))
          .font(.dl(.subheadline, weight: .medium))
          .foregroundStyle(DLColor.textPrimary)
      }
    }
    .padding(DLSpace.md)
    .frame(width: 240)
  }

  private func swatch(_ preset: String) -> some View {
    let selected = hex.caseInsensitiveCompare(preset) == .orderedSame
    return Button {
      hex = preset
      onChange()
      showPalette = false
    } label: {
      ZStack {
        Circle()
          .fill(Color(hexString: preset))
          .frame(width: 28, height: 28)
        if selected {
          Circle()
            .strokeBorder(DLColor.textPrimary, lineWidth: 2)
            .frame(width: 34, height: 34)
        }
      }
      .frame(width: 34, height: 34)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
  }
}

import SwiftUI
import SwiftData
import UIKit

/// App preferences: appearance theme, Face ID lock, accent display, data export,
/// and an About section. Toggles bind directly to `UserProgress` via `@Bindable`.
struct SettingsView: View {
  @Environment(\.modelContext) private var context
  @Bindable var progress: UserProgress

  /// Entries used to build the export payload.
  let entries: [Entry]

  @State private var exportConfirmed = false

  var body: some View {
    ZStack {
      DLColor.background.ignoresSafeArea()
      ScrollView {
        VStack(spacing: DLSpace.lg) {
          appearanceCard
          securityCard
          dataCard
          aboutCard
        }
        .padding(DLSpace.md)
      }
    }
    .navigationTitle("Settings")
    .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: Appearance

  private var appearanceCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        sectionHeader("Appearance", systemImage: "paintbrush.fill", tint: progress.accentColor)

        VStack(alignment: .leading, spacing: DLSpace.sm) {
          Text("Theme")
            .font(.dl(.subheadline, weight: .medium))
            .foregroundStyle(DLColor.textPrimary)
          Picker("Theme", selection: themeBinding) {
            ForEach(ThemePreference.allCases) { theme in
              Text(theme.label).tag(theme)
            }
          }
          .pickerStyle(.segmented)
        }

        Divider().overlay(DLColor.separator)

        HStack(spacing: DLSpace.sm) {
          Circle()
            .fill(progress.accentColor)
            .frame(width: 28, height: 28)
            .overlay(Circle().strokeBorder(DLColor.separator, lineWidth: 1))
          Text("Accent color")
            .font(.dl(.body))
            .foregroundStyle(DLColor.textPrimary)
          Spacer()
          Text("#\(progress.accentColorHex.uppercased())")
            .font(.dl(.subheadline, weight: .medium))
            .foregroundStyle(DLColor.textSecondary)
            .monospacedDigit()
        }
        Text("Change your accent in Customize on the Me tab.")
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
      }
    }
  }

  /// Routes through the computed `theme` property so the raw string stays valid.
  private var themeBinding: Binding<ThemePreference> {
    Binding(
      get: { progress.theme },
      set: {
        progress.theme = $0
        try? context.save()
        Haptics.selection()
      }
    )
  }

  // MARK: Security

  private var securityCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        sectionHeader("Security", systemImage: "lock.shield.fill", tint: DLColor.success)
        Toggle(isOn: faceIDBinding) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Require Face ID")
              .font(.dl(.body))
              .foregroundStyle(DLColor.textPrimary)
            Text("Lock the app behind Face ID when it opens.")
              .font(.dl(.caption2))
              .foregroundStyle(DLColor.textSecondary)
          }
        }
        .tint(progress.accentColor)
      }
    }
  }

  private var faceIDBinding: Binding<Bool> {
    Binding(
      get: { progress.faceIDEnabled },
      set: {
        progress.faceIDEnabled = $0
        try? context.save()
        Haptics.selection()
      }
    )
  }

  // MARK: Data

  private var dataCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        sectionHeader("Data", systemImage: "tray.full.fill", tint: DLColor.xpGold)
        Button(action: exportEntries) {
          HStack(spacing: DLSpace.sm) {
            Image(systemName: exportConfirmed ? "checkmark.circle.fill" : "doc.on.clipboard")
              .font(.system(size: 20))
              .foregroundStyle(exportConfirmed ? DLColor.success : progress.accentColor)
            VStack(alignment: .leading, spacing: 2) {
              Text(exportConfirmed ? "Copied to clipboard" : "Export entries")
                .font(.dl(.body, weight: .medium))
                .foregroundStyle(DLColor.textPrimary)
              Text("Copy a JSON summary of all \(entries.count) entries.")
                .font(.dl(.caption2))
                .foregroundStyle(DLColor.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(DLColor.textTertiary)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Export entries as JSON to the clipboard")
      }
    }
  }

  private func exportEntries() {
    UIPasteboard.general.string = exportJSON()
    Haptics.success()
    withAnimation(DLAnim.quick) { exportConfirmed = true }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      withAnimation(DLAnim.quick) { exportConfirmed = false }
    }
  }

  /// Builds a stable, human-readable JSON summary of all entries.
  private func exportJSON() -> String {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withFullDate]

    let payload: [[String: Any]] = entries
      .sorted { $0.day > $1.day }
      .map { entry in
        [
          "day": iso.string(from: entry.day),
          "win": entry.win,
          "mistake": entry.mistake,
          "lesson": entry.lesson,
          "adjustment": entry.adjustment,
          "adjustmentDone": entry.adjustmentDone,
          "mood": entry.mood.label,
          "energy": entry.energy,
          "morningIntention": entry.morningIntention,
          "tags": entry.tags,
          "xpAwarded": entry.xpAwarded,
          "wordCount": entry.wordCount
        ]
      }

    let root: [String: Any] = [
      "app": "Daily Loop",
      "exportedAt": ISO8601DateFormatter().string(from: Date()),
      "entryCount": entries.count,
      "entries": payload
    ]

    guard
      JSONSerialization.isValidJSONObject(root),
      let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]),
      let string = String(data: data, encoding: .utf8)
    else {
      return "{\"app\":\"Daily Loop\",\"entries\":[]}"
    }
    return string
  }

  // MARK: About

  private var aboutCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        sectionHeader("About", systemImage: "info.circle.fill", tint: DLColor.textSecondary)
        infoRow("Version", value: appVersion)
        Divider().overlay(DLColor.separator)
        infoRow("Made for", value: "Daily reflection")
        Divider().overlay(DLColor.separator)
        Text("Daily Loop turns a daily Win · Mistake · Lesson · Adjustment review into momentum.")
          .font(.dl(.caption))
          .foregroundStyle(DLColor.textSecondary)
      }
    }
  }

  private var appVersion: String {
    let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    return "\(short) (\(build))"
  }

  private func infoRow(_ title: String, value: String) -> some View {
    HStack {
      Text(title)
        .font(.dl(.body))
        .foregroundStyle(DLColor.textPrimary)
      Spacer()
      Text(value)
        .font(.dl(.subheadline))
        .foregroundStyle(DLColor.textSecondary)
    }
  }

  // MARK: Helpers

  private func sectionHeader(_ title: String, systemImage: String, tint: Color) -> some View {
    Label(title, systemImage: systemImage)
      .font(.dl(.headline, weight: .semibold))
      .foregroundStyle(tint)
  }
}

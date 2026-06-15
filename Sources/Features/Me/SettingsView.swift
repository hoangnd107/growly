import SwiftUI
import SwiftData
import UIKit

/// App preferences and data tools. Pushed from `ProfileView`'s `NavigationStack`,
/// so this view does NOT create its own. Controls bind directly to `UserProgress`
/// via `@Bindable` and persist through `modelContext.save()` with haptics on every
/// change. Sections: gradient themes, appearance, language, security, reminders,
/// testing unlocks, data & export (PDF / JSON / backup / restore), reset by
/// category, and About.
///
/// Keep `init(progress:entries:)` exactly — it is called as
/// `SettingsView(progress:entries:)` from `ProfileView`.
struct SettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @Bindable var progress: UserProgress

  /// Entries used to build the export payloads (PDF + JSON).
  let entries: [Entry]

  // Data tools
  @State private var exportConfirmed = false
  @State private var backupConfirmed = false
  @State private var showRestoreDialog = false
  @State private var lastBackupDisplay: Date?

  /// Wraps a temporary file URL so it can drive `.sheet(item:)`.
  private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
  }
  @State private var shareItem: ShareItem?

  // Reset
  @State private var pendingReset: ResetService.Kind?

  var body: some View {
    ScrollView {
      VStack(spacing: DLSpace.lg) {
        appearanceCard
        languageCard
        securityCard
        remindersCard
        testingCard
        dataCard
        resetCard
        aboutCard
      }
      .padding(DLSpace.md)
      .frame(maxWidth: 640)
      .frame(maxWidth: .infinity)
    }
    .themedBackground(progress.gradientTheme)
    .navigationTitle(L("Settings"))
    .navigationBarTitleDisplayMode(.inline)
    .onAppear { lastBackupDisplay = progress.lastBackupAt ?? BackupService.lastModified }
    .sheet(item: $shareItem) { item in
      ShareSheet(items: [item.url])
    }
    .confirmationDialog(
      L("Restore from backup"),
      isPresented: $showRestoreDialog,
      titleVisibility: .visible
    ) {
      Button(L("Restore from backup"), role: .destructive, action: restoreBackup)
      Button(L("Cancel"), role: .cancel) {}
    } message: {
      Text(L("This replaces all current data with the last backup."))
    }
    .confirmationDialog(
      pendingReset.map { L($0.title) } ?? L("Reset data"),
      isPresented: resetDialogBinding,
      titleVisibility: .visible
    ) {
      if let kind = pendingReset {
        Button(L("Confirm"), role: .destructive) { performReset(kind) }
      }
      Button(L("Cancel"), role: .cancel) { pendingReset = nil }
    } message: {
      Text(L("Back up first — this cannot be undone."))
    }
  }

  // MARK: 1. Appearance

  private var appearanceCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        sectionHeader(L("Appearance"), systemImage: "circle.lefthalf.filled", tint: progress.accentColor)

        VStack(alignment: .leading, spacing: DLSpace.sm) {
          Text(L("Theme"))
            .font(.dl(.subheadline, weight: .medium))
            .foregroundStyle(DLColor.textPrimary)
          Picker(L("Theme"), selection: themeBinding) {
            ForEach(ThemePreference.allCases) { theme in
              Image(systemName: theme.icon)
                .accessibilityLabel(L(theme.label))
                .tag(theme)
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
          Text(L("Accent color"))
            .font(.dl(.body))
            .foregroundStyle(DLColor.textPrimary)
          Spacer()
          Text("#\(progress.accentColorHex.uppercased())")
            .font(.dl(.subheadline, weight: .medium))
            .foregroundStyle(DLColor.textSecondary)
            .monospacedDigit()
        }
      }
    }
  }

  /// Routes through the computed `theme` property so the raw string stays valid.
  private var themeBinding: Binding<ThemePreference> {
    Binding(
      get: { progress.theme },
      set: {
        progress.theme = $0
        save()
        Haptics.selection()
      }
    )
  }

  // MARK: 3. Language

  private var languageCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        sectionHeader(L("Language"), systemImage: "globe", tint: progress.accentColor)
        Picker(L("Language"), selection: languageBinding) {
          ForEach(AppLanguage.allCases) { lang in
            Text("\(lang.flag)  \(lang.displayName)").tag(lang)
          }
        }
        .pickerStyle(.menu)
        .tint(progress.accentColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        Text(L("The app re-localizes instantly when you change this."))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
      }
    }
  }

  /// Reads/writes the stored `languageCode` as a strongly-typed `AppLanguage`.
  /// The active bundle is switched synchronously and the locale environment
  /// change re-runs the visible views' bodies, so the UI re-localizes in place
  /// without resetting navigation — the user stays here in Settings.
  private var languageBinding: Binding<AppLanguage> {
    Binding(
      get: { AppLanguage(rawValue: progress.languageCode) ?? .system },
      set: {
        progress.languageCode = $0.rawValue
        LocalizationManager.shared.code = $0.rawValue
        save()
        Haptics.selection()
      }
    )
  }

  // MARK: 4. Security

  private var securityCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        sectionHeader(L("Security"), systemImage: "lock.shield.fill", tint: DLColor.success)
        Toggle(isOn: faceIDBinding) {
          VStack(alignment: .leading, spacing: 2) {
            Text(L("Require Face ID"))
              .font(.dl(.body))
              .foregroundStyle(DLColor.textPrimary)
            Text(L("Lock the app behind Face ID when it opens."))
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
        save()
        Haptics.selection()
      }
    )
  }

  // MARK: 5. Reminders

  private var remindersCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        sectionHeader(L("Reminders"), systemImage: "bell.badge.fill", tint: DLColor.warning)

        Toggle(isOn: reminderEnabledBinding) {
          VStack(alignment: .leading, spacing: 2) {
            Text(L("Daily reminder"))
              .font(.dl(.body))
              .foregroundStyle(DLColor.textPrimary)
            Text(L("Get a nudge to close today's loop."))
              .font(.dl(.caption2))
              .foregroundStyle(DLColor.textSecondary)
          }
        }
        .tint(progress.accentColor)

        if progress.reminderEnabled {
          Divider().overlay(DLColor.separator)
          DatePicker(
            L("Reminder time"),
            selection: reminderTimeBinding,
            displayedComponents: .hourAndMinute
          )
          .font(.dl(.body))
          .foregroundStyle(DLColor.textPrimary)
          .tint(progress.accentColor)
        }
      }
    }
  }

  private var reminderEnabledBinding: Binding<Bool> {
    Binding(
      get: { progress.reminderEnabled },
      set: { enabled in
        progress.reminderEnabled = enabled
        save()
        Haptics.selection()
        if enabled {
          Task {
            _ = await NotificationService.requestAuthorization()
            NotificationService.sync(
              enabled: true,
              hour: progress.reminderHour,
              minute: progress.reminderMinute
            )
          }
        } else {
          NotificationService.cancelDailyReminder()
        }
      }
    )
  }

  /// Bridges the stored hour/minute components to a `Date` for the picker, writing
  /// hour/minute back and re-syncing the schedule on change.
  private var reminderTimeBinding: Binding<Date> {
    Binding(
      get: {
        var components = DateComponents()
        components.hour = progress.reminderHour
        components.minute = progress.reminderMinute
        return Calendar.current.date(from: components) ?? Date()
      },
      set: { date in
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        progress.reminderHour = components.hour ?? progress.reminderHour
        progress.reminderMinute = components.minute ?? progress.reminderMinute
        save()
        Haptics.selection()
        NotificationService.sync(
          enabled: progress.reminderEnabled,
          hour: progress.reminderHour,
          minute: progress.reminderMinute
        )
      }
    )
  }

  // MARK: 6. Testing

  private var testingCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        sectionHeader(L("Testing"), systemImage: "wrench.and.screwdriver.fill", tint: DLColor.textSecondary)
        Toggle(isOn: debugUnlockBinding) {
          VStack(alignment: .leading, spacing: 2) {
            Text(L("Unlock everything (testing)"))
              .font(.dl(.body))
              .foregroundStyle(DLColor.textPrimary)
            Text(L("Temporarily unlock all accents and content."))
              .font(.dl(.caption2))
              .foregroundStyle(DLColor.textSecondary)
          }
        }
        .tint(progress.accentColor)
      }
    }
  }

  private var debugUnlockBinding: Binding<Bool> {
    Binding(
      get: { progress.debugUnlockAll },
      set: {
        progress.debugUnlockAll = $0
        save()
        Haptics.selection()
      }
    )
  }

  // MARK: 7. Data & export

  private var dataCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        sectionHeader(L("Data"), systemImage: "tray.full.fill", tint: DLColor.xpGold)

        // Export PDF
        Button(action: exportPDF) {
          dataRow(
            systemImage: "doc.richtext",
            tint: progress.accentColor,
            title: L("Export PDF"),
            subtitle: Lf("Share a formatted PDF of all %d entries.", entries.count)
          )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("Export PDF"))

        Divider().overlay(DLColor.separator)

        // Export entries (JSON to clipboard)
        Button(action: exportEntries) {
          dataRow(
            systemImage: exportConfirmed ? "checkmark.circle.fill" : "doc.on.clipboard",
            tint: exportConfirmed ? DLColor.success : progress.accentColor,
            title: exportConfirmed ? L("Copied to clipboard") : L("Export entries (JSON)"),
            subtitle: Lf("Copy a JSON summary of all %d entries.", entries.count)
          )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("Export entries (JSON)"))

        Divider().overlay(DLColor.separator)

        // Back up now
        Button(action: backupNow) {
          dataRow(
            systemImage: backupConfirmed ? "checkmark.circle.fill" : "arrow.up.doc.fill",
            tint: backupConfirmed ? DLColor.success : progress.accentColor,
            title: backupConfirmed ? L("Backup complete") : L("Back up now"),
            subtitle: backupSubtitle
          )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("Back up now"))

        Divider().overlay(DLColor.separator)

        // Restore from backup
        Button { showRestoreDialog = true } label: {
          dataRow(
            systemImage: "arrow.down.doc.fill",
            tint: BackupService.backupExists ? progress.accentColor : DLColor.textTertiary,
            title: L("Restore from backup"),
            subtitle: BackupService.backupExists
              ? L("Replace current data with the last backup.")
              : L("No backup available yet.")
          )
        }
        .buttonStyle(.plain)
        .disabled(!BackupService.backupExists)
        .accessibilityLabel(L("Restore from backup"))
      }
    }
  }

  private var backupSubtitle: String {
    if let date = lastBackupDisplay {
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .short
      formatter.locale = LocalizationManager.shared.locale ?? .current
      return "\(L("Last backup")): \(formatter.string(from: date))"
    }
    return L("Save a JSON snapshot of all your data.")
  }

  private func dataRow(systemImage: String, tint: Color, title: String, subtitle: String) -> some View {
    HStack(spacing: DLSpace.sm) {
      Image(systemName: systemImage)
        .font(.system(size: 20))
        .foregroundStyle(tint)
        .frame(width: 24)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.dl(.body, weight: .medium))
          .foregroundStyle(DLColor.textPrimary)
        Text(subtitle)
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: DLSpace.sm)
      Image(systemName: "chevron.right")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(DLColor.textTertiary)
    }
    .contentShape(Rectangle())
  }

  private func exportPDF() {
    guard let url = PDFExporter.export(entries: entries, progress: progress) else {
      Haptics.warning()
      return
    }
    Haptics.success()
    shareItem = ShareItem(url: url)
  }

  private func backupNow() {
    let date = BackupService.export(context: modelContext)
    lastBackupDisplay = date ?? progress.lastBackupAt ?? BackupService.lastModified
    Haptics.success()
    withAnimation(DLAnim.quick) { backupConfirmed = true }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      withAnimation(DLAnim.quick) { backupConfirmed = false }
    }
  }

  private func restoreBackup() {
    if BackupService.restore(context: modelContext) {
      Haptics.success()
    } else {
      Haptics.light()
    }
    lastBackupDisplay = progress.lastBackupAt ?? BackupService.lastModified
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
      "app": "Growly",
      "exportedAt": ISO8601DateFormatter().string(from: Date()),
      "entryCount": entries.count,
      "entries": payload
    ]

    guard
      JSONSerialization.isValidJSONObject(root),
      let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]),
      let string = String(data: data, encoding: .utf8)
    else {
      return "{\"app\":\"Growly\",\"entries\":[]}"
    }
    return string
  }

  // MARK: 8. Reset data

  private var resetCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        sectionHeader(L("Reset data"), systemImage: "trash.fill", tint: DLColor.streakEnd)

        Text(L("Back up first — this cannot be undone."))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)

        VStack(spacing: 0) {
          ForEach(Array(ResetService.Kind.allCases.enumerated()), id: \.element.id) { index, kind in
            if index > 0 { Divider().overlay(DLColor.separator) }
            Button { pendingReset = kind } label: {
              resetRow(kind)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L(kind.title))
          }
        }
      }
    }
  }

  private func resetRow(_ kind: ResetService.Kind) -> some View {
    let destructive = kind == .everything
    let tint = destructive ? DLColor.streakEnd : DLColor.textSecondary
    return HStack(spacing: DLSpace.sm) {
      Image(systemName: kind.systemImage)
        .font(.system(size: 18))
        .foregroundStyle(tint)
        .frame(width: 24)
      Text(L(kind.title))
        .font(.dl(.body, weight: destructive ? .semibold : .regular))
        .foregroundStyle(destructive ? DLColor.streakEnd : DLColor.textPrimary)
      Spacer(minLength: DLSpace.sm)
      Image(systemName: "chevron.right")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(DLColor.textTertiary)
    }
    .padding(.vertical, 10)
    .contentShape(Rectangle())
  }

  /// Drives the reset confirmation dialog off the pending kind.
  private var resetDialogBinding: Binding<Bool> {
    Binding(
      get: { pendingReset != nil },
      set: { if !$0 { pendingReset = nil } }
    )
  }

  private func performReset(_ kind: ResetService.Kind) {
    ResetService.reset(kind, context: modelContext)
    Haptics.warning()
    lastBackupDisplay = progress.lastBackupAt ?? BackupService.lastModified
    pendingReset = nil
  }

  // MARK: 9. About

  private var aboutCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        sectionHeader(L("About"), systemImage: "info.circle.fill", tint: DLColor.textSecondary)
        infoRow(L("Version"), value: appVersion)
        Divider().overlay(DLColor.separator)
        infoRow(L("Made for"), value: L("Daily reflection"))
        Divider().overlay(DLColor.separator)
        infoRow(L("Author"), value: "Nguyen Duy Hoang")
        Divider().overlay(DLColor.separator)
        Text(L("Growly turns a daily Win · Mistake · Lesson · Adjustment review into momentum."))
          .font(.dl(.caption))
          .foregroundStyle(DLColor.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
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

  private func save() {
    try? modelContext.save()
  }

  private func sectionHeader(_ title: String, systemImage: String, tint: Color) -> some View {
    Label(title, systemImage: systemImage)
      .font(.dl(.headline, weight: .semibold))
      .foregroundStyle(tint)
  }
}

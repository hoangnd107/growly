import SwiftUI
import SwiftData

/// SMART goals: Specific (title) · Measurable (current/target + unit) ·
/// Relevant (detail) · Time-bound (deadline). Presented via NavigationLink from
/// Insights, so it owns no NavigationStack — only a `.navigationTitle`.
///
/// Each goal renders as a glassy card with a color stripe, a progress bar,
/// +/- adjustment, and a "Mark complete" toggle. A sheet form creates new goals.
/// Swipe-to-delete removes them. Reads the per-user gradient theme so the
/// backdrop matches the rest of the app and persists every change immediately.
struct GoalsView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @Query(sort: \SmartGoal.createdAt, order: .reverse) private var goals: [SmartGoal]
  @Query private var progressList: [UserProgress]

  @State private var showAddSheet = false

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  private var animate: Bool { !reduceMotion }

  // MARK: Body

  var body: some View {
    Group {
      if goals.isEmpty {
        emptyState
      } else {
        goalList
      }
    }
    .themedBackground(theme)
    .navigationTitle(L("Goals"))
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          Haptics.light()
          showAddSheet = true
        } label: {
          Image(systemName: "plus")
        }
        .tint(theme.accent)
        .accessibilityLabel(L("New goal"))
      }
    }
    .sheet(isPresented: $showAddSheet) {
      GoalEditorSheet(theme: theme)
    }
  }

  // MARK: Empty state

  private var emptyState: some View {
    ScrollView {
      VStack(spacing: DLSpace.lg) {
        MiraView(size: 110, quote: L("What are we working toward?"))
          .padding(.top, DLSpace.xl)
        VStack(spacing: DLSpace.sm) {
          Text(L("No goals yet"))
            .font(.dl(.title3, weight: .bold))
            .foregroundStyle(DLColor.textPrimary)
          Text(L("Set a SMART goal — something Specific, Measurable, and Time-bound — and watch the progress add up."))
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        PrimaryButton(L("New goal"), systemImage: "plus.circle.fill") {
          Haptics.light()
          showAddSheet = true
        }
      }
      .padding(DLSpace.lg)
      .frame(maxWidth: .infinity)
    }
  }

  // MARK: Goal list

  private var goalList: some View {
    List {
      Section {
        ForEach(goals) { goal in
          GoalCard(goal: goal, accent: theme.accent, animate: animate) { save() }
            .listRowInsets(EdgeInsets(top: DLSpace.xs, leading: DLSpace.md, bottom: DLSpace.xs, trailing: DLSpace.md))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .onDelete(perform: deleteGoals)
      } footer: {
        Text(L("Swipe a goal left to delete it."))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
          .padding(.horizontal, DLSpace.xs)
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
  }

  // MARK: Actions

  private func deleteGoals(at offsets: IndexSet) {
    for index in offsets {
      context.delete(goals[index])
    }
    save()
    Haptics.medium()
  }

  private func save() {
    try? context.save()
  }
}

// MARK: - Goal card

/// A single SMART goal card. Binds directly to the `@Bindable` goal and calls
/// `onChange` after each mutation so the parent can persist.
private struct GoalCard: View {
  @Bindable var goal: SmartGoal
  let accent: Color
  let animate: Bool
  let onChange: () -> Void

  /// How much one tap of +/- moves the value. Scales with the target so big
  /// goals (e.g. 10,000 steps) step in sensible increments.
  private var step: Double {
    let magnitude = max(goal.targetValue, 1)
    if magnitude >= 1_000 { return 100 }
    if magnitude >= 100 { return 10 }
    if magnitude >= 20 { return 1 }
    return 1
  }

  private var stripeColor: Color {
    goal.colorHex.map { Color(hexString: $0, fallback: 0x7E5BEF) } ?? accent
  }

  var body: some View {
    GlassCard {
      HStack(alignment: .top, spacing: DLSpace.md) {
        // Color stripe
        Capsule()
          .fill(stripeColor)
          .frame(width: 5)
          .frame(maxHeight: .infinity)
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: DLSpace.sm) {
          header
          if !goal.detail.isEmpty {
            Text(goal.detail)
              .font(.dl(.subheadline))
              .foregroundStyle(DLColor.textSecondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          progressBlock
          if goal.deadline != nil {
            deadlineRow
          }
          controls
        }
      }
    }
    .fixedSize(horizontal: false, vertical: true)
    .accessibilityElement(children: .contain)
  }

  // MARK: Header

  private var header: some View {
    HStack(alignment: .firstTextBaseline, spacing: DLSpace.sm) {
      Text(goal.title)
        .font(.dl(.headline, weight: .semibold))
        .foregroundStyle(goal.isCompleted ? DLColor.textSecondary : DLColor.textPrimary)
        .strikethrough(goal.isCompleted, color: DLColor.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
      if goal.isCompleted {
        Image(systemName: "checkmark.seal.fill")
          .foregroundStyle(DLColor.success)
          .accessibilityHidden(true)
      }
    }
  }

  // MARK: Progress

  private var progressBlock: some View {
    VStack(alignment: .leading, spacing: DLSpace.xs) {
      ProgressView(value: goal.progress)
        .tint(stripeColor)
        .animation(animate ? DLAnim.standard : nil, value: goal.progress)

      HStack {
        Text(progressText)
          .font(.dl(.caption, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
          .monospacedDigit()
        Spacer()
        Text("\(Int((goal.progress * 100).rounded()))%")
          .font(.dl(.caption, weight: .semibold))
          .foregroundStyle(stripeColor)
          .monospacedDigit()
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Lf("Progress: %@, %d percent", progressText, Int((goal.progress * 100).rounded())))
  }

  /// "3 / 10 books" — drops the unit when blank, formats whole numbers cleanly.
  private var progressText: String {
    let current = formatted(goal.currentValue)
    let target = formatted(goal.targetValue)
    let unit = goal.unit.trimmingCharacters(in: .whitespacesAndNewlines)
    if unit.isEmpty {
      return "\(current) / \(target)"
    }
    return "\(current) / \(target) \(unit)"
  }

  private func formatted(_ value: Double) -> String {
    if value == value.rounded() {
      return String(format: "%.0f", value)
    }
    return String(format: "%.1f", value)
  }

  // MARK: Deadline

  private var deadlineRow: some View {
    HStack(spacing: DLSpace.xs) {
      Image(systemName: "calendar")
        .font(.system(size: 12))
        .foregroundStyle(deadlineTint)
      if let deadline = goal.deadline {
        Text(deadline, format: .dateTime.month(.abbreviated).day().year())
          .font(.dl(.caption, weight: .medium))
          .foregroundStyle(DLColor.textSecondary)
      }
      if let days = goal.daysRemaining {
        Text("·")
          .font(.dl(.caption))
          .foregroundStyle(DLColor.textTertiary)
        Text(daysRemainingText(days))
          .font(.dl(.caption, weight: .semibold))
          .foregroundStyle(deadlineTint)
          .monospacedDigit()
      }
    }
    .accessibilityElement(children: .combine)
  }

  /// Warn (orange) when overdue or due within 3 days, otherwise secondary.
  private var deadlineTint: Color {
    guard let days = goal.daysRemaining, !goal.isCompleted else { return DLColor.textSecondary }
    return days <= 3 ? DLColor.warning : DLColor.textSecondary
  }

  private func daysRemainingText(_ days: Int) -> String {
    if days < 0 {
      return Lf("%d days overdue", -days)
    } else if days == 0 {
      return L("Due today")
    } else if days == 1 {
      return L("1 day left")
    }
    return Lf("%d days left", days)
  }

  // MARK: Controls

  private var controls: some View {
    HStack(spacing: DLSpace.md) {
      // +/- adjuster for currentValue, clamped at >= 0.
      HStack(spacing: 0) {
        adjustButton(systemImage: "minus", disabled: goal.currentValue <= 0) {
          adjust(by: -step)
        }
        Divider()
          .frame(height: 22)
          .overlay(DLColor.separator)
        adjustButton(systemImage: "plus", disabled: false) {
          adjust(by: step)
        }
      }
      .background(
        RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
          .fill(.ultraThinMaterial)
      )
      .overlay(
        RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
          .strokeBorder(DLColor.separator.opacity(0.6), lineWidth: 1)
      )

      Spacer(minLength: 0)

      Button {
        Haptics.success()
        withAnimation(animate ? DLAnim.standard : nil) {
          goal.isCompleted.toggle()
        }
        onChange()
      } label: {
        HStack(spacing: DLSpace.xs) {
          Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
          Text(goal.isCompleted ? L("Completed") : L("Mark complete"))
            .font(.dl(.subheadline, weight: .semibold))
        }
        .foregroundStyle(goal.isCompleted ? DLColor.success : stripeColor)
        .padding(.horizontal, DLSpace.sm)
        .padding(.vertical, DLSpace.xs)
        .background(
          Capsule().fill((goal.isCompleted ? DLColor.success : stripeColor).opacity(0.14))
        )
      }
      .buttonStyle(.plain)
      .bounceTap()
      .accessibilityLabel(goal.isCompleted ? L("Mark goal incomplete") : L("Mark goal complete"))
    }
  }

  private func adjustButton(systemImage: String, disabled: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(disabled ? DLColor.textTertiary : stripeColor)
        .frame(width: 48, height: 40)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(disabled)
    .accessibilityLabel(systemImage == "plus" ? L("Increase progress") : L("Decrease progress"))
  }

  private func adjust(by delta: Double) {
    Haptics.selection()
    let next = max(0, goal.currentValue + delta)
    withAnimation(animate ? DLAnim.standard : nil) {
      goal.currentValue = next
    }
    onChange()
  }
}

// MARK: - New goal editor

/// Sheet form capturing a SMART goal. Inserts and saves on "Add".
private struct GoalEditorSheet: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  let theme: GradientTheme

  @State private var title = ""
  @State private var detail = ""
  @State private var unit = ""
  @State private var targetText = ""
  @State private var hasDeadline = false
  @State private var deadline = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()

  private var trimmedTitle: String {
    title.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Parsed target; defaults to 1 when blank or unparseable.
  private var targetValue: Double {
    let cleaned = targetText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let value = Double(cleaned), value > 0 else { return 1 }
    return value
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField(L("What do you want to achieve?"), text: $title, axis: .vertical)
            .font(.dl(.body))
            .textInputAutocapitalization(.sentences)
        } header: {
          Text(L("Specific"))
        } footer: {
          Text(L("Name the goal in a sentence — e.g. \"Read 10 books this year\"."))
            .font(.dl(.caption2))
        }

        Section {
          TextField(L("Why does this matter? (optional)"), text: $detail, axis: .vertical)
            .font(.dl(.body))
            .textInputAutocapitalization(.sentences)
            .lineLimit(1...4)
        } header: {
          Text(L("Relevant"))
        }

        Section {
          HStack {
            Text(L("Target"))
              .font(.dl(.body))
              .foregroundStyle(DLColor.textPrimary)
            Spacer()
            TextField(L("Amount"), text: $targetText)
              .font(.dl(.body, weight: .semibold))
              .keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing)
              .monospacedDigit()
              .frame(maxWidth: 120)
          }
          HStack {
            Text(L("Unit"))
              .font(.dl(.body))
              .foregroundStyle(DLColor.textPrimary)
            Spacer()
            TextField(L("e.g. books, km"), text: $unit)
              .font(.dl(.body))
              .multilineTextAlignment(.trailing)
              .frame(maxWidth: 160)
          }
        } header: {
          Text(L("Measurable"))
        } footer: {
          Text(L("How will you know you got there? Set a number to count toward."))
            .font(.dl(.caption2))
        }

        Section {
          Toggle(isOn: $hasDeadline.animation(DLAnim.standard)) {
            Text(L("Set a deadline"))
              .font(.dl(.body))
              .foregroundStyle(DLColor.textPrimary)
          }
          .tint(theme.accent)

          if hasDeadline {
            DatePicker(
              L("Deadline"),
              selection: $deadline,
              displayedComponents: .date
            )
            .font(.dl(.body))
            .tint(theme.accent)
          }
        } header: {
          Text(L("Time-bound"))
        }
      }
      .scrollContentBackground(.hidden)
      .themedBackground(theme)
      .navigationTitle(L("New goal"))
      .navigationBarTitleDisplayMode(.inline)
      .keyboardDismissButton()
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(L("Cancel")) {
            Haptics.light()
            dismiss()
          }
          .tint(theme.accent)
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button(L("Add")) {
            addGoal()
          }
          .font(.dl(.body, weight: .semibold))
          .tint(theme.accent)
          .disabled(trimmedTitle.isEmpty)
        }
      }
    }
    .presentationDetents([.large])
  }

  private func addGoal() {
    let name = trimmedTitle
    guard !name.isEmpty else { return }
    let goal = SmartGoal(
      title: name,
      detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
      unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
      targetValue: targetValue,
      deadline: hasDeadline ? Calendar.current.startOfDay(for: deadline) : nil,
      colorHex: theme.accentHexString
    )
    context.insert(goal)
    try? context.save()
    Haptics.success()
    dismiss()
  }
}

#Preview {
  NavigationStack {
    GoalsView()
  }
  .modelContainer(for: [SmartGoal.self, UserProgress.self], inMemory: true)
}

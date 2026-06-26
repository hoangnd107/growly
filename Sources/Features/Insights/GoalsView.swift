import SwiftUI
import SwiftData

/// SMART goals: Specific (title) · Measurable (current/target + unit) ·
/// Relevant (detail) · Time-bound (deadline). Presented via NavigationLink from
/// Insights, so it owns no NavigationStack — only a `.navigationTitle`.
///
/// Goals can be filtered (all/active/completed), grouped by category, edited,
/// reused once completed, and soft-deleted into a Trash (restorable). Reads the
/// per-user gradient theme and persists every change immediately.
struct GoalsView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @Query(sort: \SmartGoal.createdAt, order: .reverse) private var goals: [SmartGoal]
  @Query private var progressList: [UserProgress]

  @State private var showAddSheet = false
  @State private var editingGoal: SmartGoal?
  @State private var showTrash = false
  @State private var goalFilter: GoalFilter = .all
  @State private var categoryFilter: String?

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  private var animate: Bool { !reduceMotion }

  private enum GoalFilter: String, CaseIterable, Identifiable {
    case all, active, completed
    var id: String { rawValue }
    var label: String {
      switch self {
      case .all: return L("All")
      case .active: return L("Active")
      case .completed: return L("Completed")
      }
    }
  }

  // MARK: - Derived

  private var activeGoals: [SmartGoal] { goals.filter { $0.deletedAt == nil } }
  private var trashedGoals: [SmartGoal] { goals.filter { $0.deletedAt != nil } }

  private var categories: [String] {
    var seen = Set<String>()
    var ordered: [String] = []
    for goal in activeGoals {
      if let category = goal.category?.trimmingCharacters(in: .whitespacesAndNewlines),
         !category.isEmpty, !seen.contains(category) {
        seen.insert(category)
        ordered.append(category)
      }
    }
    return ordered.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  private var matched: [SmartGoal] {
    activeGoals.filter { goal in
      switch goalFilter {
      case .all: break
      case .active: if goal.isCompleted { return false }
      case .completed: if !goal.isCompleted { return false }
      }
      if let categoryFilter, goal.category != categoryFilter { return false }
      return true
    }
  }

  private var isFiltering: Bool { goalFilter != .all || categoryFilter != nil }

  // MARK: - Body

  var body: some View {
    Group {
      if activeGoals.isEmpty {
        emptyState
      } else {
        goalList
      }
    }
    .themedBackground(theme)
    .navigationTitle(L("Goals"))
    .navigationBarTitleDisplayMode(.large)
    .toolbar { toolbarContent }
    .sheet(isPresented: $showAddSheet) {
      GoalEditorSheet(theme: theme, goal: nil, existingCategories: categories)
    }
    .sheet(item: $editingGoal) { goal in
      GoalEditorSheet(theme: theme, goal: goal, existingCategories: categories)
    }
    .sheet(isPresented: $showTrash) {
      GoalsTrashView()
    }
  }

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    if !activeGoals.isEmpty {
      ToolbarItem(placement: .topBarLeading) { filterMenu }
    }
    if !trashedGoals.isEmpty {
      ToolbarItem(placement: .topBarTrailing) { trashButton }
    }
    ToolbarItem(placement: .topBarTrailing) { addButton }
  }

  private var addButton: some View {
    Button {
      Haptics.light()
      showAddSheet = true
    } label: {
      Image(systemName: "plus")
    }
    .tint(theme.accent)
    .accessibilityLabel(L("New goal"))
  }

  private var trashButton: some View {
    Button { showTrash = true } label: {
      Image(systemName: "trash")
        .font(.system(size: 17, weight: .semibold))
    }
    .tint(theme.accent)
    .accessibilityLabel(L("Recently deleted"))
  }

  private var filterMenu: some View {
    Menu {
      Picker(L("Filter"), selection: $goalFilter) {
        ForEach(GoalFilter.allCases) { filter in
          Text(filter.label).tag(filter)
        }
      }
      if isFiltering {
        Divider()
        Button(role: .destructive) {
          goalFilter = .all
          categoryFilter = nil
          Haptics.light()
        } label: {
          Label(L("Clear filters"), systemImage: "xmark.circle")
        }
      }
    } label: {
      Image(systemName: isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        .font(.system(size: 17, weight: .semibold))
    }
    .tint(theme.accent)
    .accessibilityLabel(L("Filter goals"))
  }

  // MARK: - Empty state

  private var emptyState: some View {
    ScrollView {
      VStack(spacing: DLSpace.lg) {
        EmptyGlyph(systemImage: "target", size: 110, tint: theme.accent)
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

  // MARK: - Goal list

  private var goalList: some View {
    List {
      if !categories.isEmpty {
        Section {
          categoryChips
            .listRowInsets(EdgeInsets(top: DLSpace.sm, leading: DLSpace.md, bottom: DLSpace.xs, trailing: DLSpace.md))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
      }

      Section {
        if matched.isEmpty {
          Text(L("No goals match the filter."))
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else {
          ForEach(matched) { goal in
            GoalCard(goal: goal, accent: theme.accent, animate: animate,
                     onEdit: { Haptics.light(); editingGoal = goal },
                     onChange: { save() })
              .listRowInsets(EdgeInsets(top: DLSpace.xs, leading: DLSpace.md, bottom: DLSpace.xs, trailing: DLSpace.md))
              .listRowBackground(Color.clear)
              .listRowSeparator(.hidden)
              // Swipe-left (trailing) = edit, plus reuse when completed; swipe-right
              // (leading) = delete only (round 5, item 8). Tapping the card also edits.
              .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button { editingGoal = goal } label: {
                  Label(L("Edit"), systemImage: "pencil")
                }
                .tint(Color(hex: 0x0A84FF))
                if goal.isCompleted {
                  Button { reuse(goal) } label: {
                    Label(L("Reuse"), systemImage: "arrow.counterclockwise")
                  }
                  .tint(DLColor.success)
                }
              }
              .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button(role: .destructive) { softDelete(goal) } label: {
                  Label(L("Delete"), systemImage: "trash")
                }
              }
              .contextMenu { goalContextMenu(goal) }
          }
        }
      } footer: {
        Text(L("Tap a goal to edit, or swipe to delete or reuse."))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
          .padding(.horizontal, DLSpace.xs)
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .animation(animate ? DLAnim.standard : nil, value: goalFilter)
    .animation(animate ? DLAnim.standard : nil, value: categoryFilter)
  }

  @ViewBuilder
  private func goalContextMenu(_ goal: SmartGoal) -> some View {
    Button { editingGoal = goal } label: {
      Label(L("Edit"), systemImage: "pencil")
    }
    if goal.isCompleted {
      Button { reuse(goal) } label: {
        Label(L("Reuse"), systemImage: "arrow.counterclockwise")
      }
    }
    Divider()
    Button(role: .destructive) { softDelete(goal) } label: {
      Label(L("Delete"), systemImage: "trash")
    }
  }

  // MARK: - Category chips

  private var categoryChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: DLSpace.sm) {
        categoryChip(label: L("All"), category: nil, isSelected: categoryFilter == nil)
        ForEach(categories, id: \.self) { category in
          categoryChip(label: category, category: category, isSelected: categoryFilter == category)
        }
      }
      .padding(.vertical, 2)
    }
  }

  private func categoryChip(label: String, category: String?, isSelected: Bool) -> some View {
    Button {
      withAnimation(animate ? DLAnim.quick : nil) {
        categoryFilter = (categoryFilter == category) ? nil : category
      }
      Haptics.selection()
    } label: {
      HStack(spacing: 4) {
        if category != nil {
          Image(systemName: "folder.fill").font(.system(size: 11))
        }
        Text(label)
          .font(.dl(.subheadline, weight: .medium))
          .lineLimit(1)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(
        isSelected ? theme.accent.opacity(0.22) : DLColor.surfaceElevated,
        in: Capsule()
      )
      .overlay(
        Capsule().strokeBorder(isSelected ? theme.accent : Color.clear, lineWidth: 1.5)
      )
      .foregroundStyle(isSelected ? theme.accent : DLColor.textSecondary)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  // MARK: - Actions

  private func softDelete(_ goal: SmartGoal) {
    let category = goal.category
    withAnimation(animate ? DLAnim.standard : nil) {
      goal.deletedAt = Date()
      goal.updatedAt = Date()
    }
    if let active = categoryFilter, active == category,
       !activeGoals.contains(where: { $0.category == active }) {
      categoryFilter = nil
    }
    save()
    Haptics.warning()
  }

  /// Re-open a completed goal as a fresh active goal (progress reset).
  private func reuse(_ goal: SmartGoal) {
    withAnimation(animate ? DLAnim.standard : nil) {
      goal.isCompleted = false
      goal.completedAt = nil
      goal.currentValue = 0
      goal.updatedAt = Date()
    }
    save()
    Haptics.success()
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
  /// Tapping the card's text area opens the editor (round 5, item 8).
  let onEdit: () -> Void
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
          // The textual area is a tap-to-edit button; the +/- and complete
          // controls below stay their own buttons so they keep working.
          Button(action: onEdit) {
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
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
      if let category = goal.category, !category.isEmpty {
        Text(category)
          .font(.dl(.caption2, weight: .semibold))
          .foregroundStyle(accent)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(accent.opacity(0.14), in: Capsule())
          .lineLimit(1)
      }
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
          goal.completedAt = goal.isCompleted ? Date() : nil
          goal.updatedAt = Date()
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
    goal.updatedAt = Date()
    onChange()
  }
}

// MARK: - Goal editor (create + edit)

/// Sheet form capturing a SMART goal. Creates a new goal when `goal` is nil, or
/// edits the passed goal in place. Reused by the Progress day detail to edit a
/// goal due that day (round 5, item 9).
struct GoalEditorSheet: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  let theme: GradientTheme
  let goal: SmartGoal?
  let existingCategories: [String]

  @State private var title: String
  @State private var detail: String
  @State private var unit: String
  @State private var targetText: String
  @State private var currentText: String
  @State private var category: String
  @State private var hasDeadline: Bool
  @State private var deadline: Date

  init(theme: GradientTheme, goal: SmartGoal?, existingCategories: [String]) {
    self.theme = theme
    self.goal = goal
    self.existingCategories = existingCategories
    _title = State(initialValue: goal?.title ?? "")
    _detail = State(initialValue: goal?.detail ?? "")
    _unit = State(initialValue: goal?.unit ?? "")
    _targetText = State(initialValue: goal.map { Self.numberString($0.targetValue) } ?? "")
    _currentText = State(initialValue: goal.map { Self.numberString($0.currentValue) } ?? "")
    _category = State(initialValue: goal?.category ?? "")
    _hasDeadline = State(initialValue: goal?.deadline != nil)
    _deadline = State(initialValue: goal?.deadline ?? (Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()))
  }

  private var isEditing: Bool { goal != nil }

  private var trimmedTitle: String {
    title.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Parsed target; defaults to 1 when blank or unparseable.
  private var targetValue: Double {
    let cleaned = targetText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let value = Double(cleaned), value > 0 else { return 1 }
    return value
  }

  /// Parsed current value; defaults to 0.
  private var currentValue: Double {
    let cleaned = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
    return max(0, Double(cleaned) ?? 0)
  }

  private static func numberString(_ value: Double) -> String {
    value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
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
            Text(L("Current"))
              .font(.dl(.body))
              .foregroundStyle(DLColor.textPrimary)
            Spacer()
            TextField(L("Amount"), text: $currentText)
              .font(.dl(.body, weight: .semibold))
              .keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing)
              .monospacedDigit()
              .frame(maxWidth: 120)
          }
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
          HStack {
            Text(L("Category"))
              .font(.dl(.body))
              .foregroundStyle(DLColor.textPrimary)
            Spacer()
            TextField(L("e.g. Health"), text: $category)
              .font(.dl(.body))
              .multilineTextAlignment(.trailing)
              .frame(maxWidth: 180)
          }
          if !existingCategories.isEmpty {
            Menu {
              ForEach(existingCategories, id: \.self) { option in
                Button(option) { category = option }
              }
            } label: {
              Label(L("Choose existing"), systemImage: "folder")
                .font(.dl(.subheadline))
            }
            .tint(theme.accent)
          }
        } header: {
          Text(L("Category"))
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
      .navigationTitle(isEditing ? L("Edit goal") : L("New goal"))
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
          Button(isEditing ? L("Save") : L("Add")) {
            saveGoal()
          }
          .font(.dl(.body, weight: .semibold))
          .tint(theme.accent)
          .disabled(trimmedTitle.isEmpty)
        }
      }
    }
    .presentationDetents([.large])
  }

  private func saveGoal() {
    let name = trimmedTitle
    guard !name.isEmpty else { return }
    let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolvedCategory = trimmedCategory.isEmpty ? nil : trimmedCategory
    let resolvedDeadline = hasDeadline ? Calendar.current.startOfDay(for: deadline) : nil

    if let goal {
      goal.title = name
      goal.detail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
      goal.unit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
      goal.targetValue = targetValue
      goal.currentValue = currentValue
      goal.deadline = resolvedDeadline
      goal.category = resolvedCategory
      goal.updatedAt = Date()
    } else {
      let new = SmartGoal(
        title: name,
        detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
        unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
        targetValue: targetValue,
        currentValue: currentValue,
        deadline: resolvedDeadline,
        colorHex: theme.accentHexString
      )
      new.category = resolvedCategory
      context.insert(new)
    }
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

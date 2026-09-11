import AppKit
import SwiftUI

enum V5TaskCompletionSourceSection: Equatable {
    case overdue
    case active
    case completed
}

struct V5TaskCompletionSourceSlot: Equatable, Identifiable {
    let id: UUID
    let section: V5TaskCompletionSourceSection
    let insertionIndex: Int
    let height: CGFloat
}

struct CalendarWorkbenchV5Sidebar: View {
    @ObservedObject var model: CalendarWorkbenchV5Model
    let appearance: V5AppearancePreference
    let onSelectAppearance: (V5AppearancePreference) -> Void
    let completingTaskIDs: Set<UUID>
    let completionSourceSlot: V5TaskCompletionSourceSlot?
    let taskInteractionLocked: Bool
    let revealedTaskID: UUID?
    let onToggleTask: (UUID) -> Void
    let onTaskDragChanged: (UUID, CGPoint, CGPoint) -> Void
    let onTaskDragEnded: (UUID, CGPoint) -> Void
    let onTextInputFocusChange: (Bool) -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.controlActiveState) private var controlActiveState
    @FocusState private var composerFocused: Bool
    @State private var hoveredTaskID: UUID?
    @State private var rightMouseMonitor: Any?
    @State private var completedExpanded = false

    var body: some View {
        Group {
            if let editingID = model.editingTaskID, let task = model.task(id: editingID) {
                V5FocusedTaskEditor(task: task, model: model, onClose: onClose)
            } else {
                listPane
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 15)
        .onAppear {
            DispatchQueue.main.async { composerFocused = false }
            if rightMouseMonitor == nil {
                rightMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { event in
                    if let hoveredTaskID {
                        composerFocused = false
                        model.selectTask(id: hoveredTaskID)
                    }
                    return event
                }
            }
        }
        .onDisappear {
            onTextInputFocusChange(false)
            if let rightMouseMonitor {
                NSEvent.removeMonitor(rightMouseMonitor)
                self.rightMouseMonitor = nil
            }
        }
        .onChange(of: controlActiveState) { _, state in
            guard state == .inactive else { return }
            composerFocused = false
            model.clearTaskSelection()
        }
        .onChange(of: model.selectedDate) { _, _ in
            completedExpanded = false
        }
    }

    private var listPane: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    composerFocused = false
                    model.clearTaskSelection()
                }

            VStack(alignment: .leading, spacing: 13) {
                header
                quickComposer

                if hasNoVisibleTasks {
                    V5QuietEmptyState()
                } else {
                    ScrollView(.vertical,
                               showsIndicators: V5TaskListOverflowPresentation.showsNativeScrollIndicator) {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            if !overdueListItems.isEmpty {
                                V5TaskSectionHeader(
                                    title: "逾期",
                                    count: overdueListItems.count,
                                    symbolName: "exclamationmark.circle.fill",
                                    tint: .orange
                                )
                                ForEach(overdueListItems) { item in
                                    listItem(item)
                                }
                            }

                            if !activeListItems.isEmpty {
                                V5TaskSectionHeader(
                                    title: model.isTodaySelected ? "今天的待办" : "待办",
                                    count: activeListItems.count,
                                    symbolName: "circle",
                                    tint: .secondary
                                )
                                ForEach(activeListItems) { item in
                                    listItem(item)
                                }
                            }

                            if !completedListItems.isEmpty {
                                V5TaskSectionHeader(
                                    title: model.isTodaySelected ? "今天已完成" : "已完成",
                                    count: completedListItems.count,
                                    symbolName: "checkmark.circle.fill",
                                    tint: .secondary
                                )
                                ForEach(completedListItems) { item in
                                    listItem(item)
                                }
                                if inlinePresentation.showsCompletedDisclosure {
                                    Button(inlinePresentation.completedDisclosureTitle) {
                                        withAnimation(rowAnimation) { completedExpanded.toggle() }
                                    }
                                    .buttonStyle(.plain)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .padding(.top, 2)
                                    .accessibilityIdentifier("v5-completed-disclosure")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, V5TaskListOverflowPresentation.contentVerticalInset)
                        .background(V5ScrollViewConfigurator())
                    }
                    .scrollIndicators(.hidden)
                    .scrollClipDisabled(V5TaskListOverflowPresentation.disablesScrollClipping)
                    .mask {
                        VStack(spacing: 0) {
                            LinearGradient(colors: [.clear, .black],
                                           startPoint: .top, endPoint: .bottom)
                                .frame(height: V5TaskListOverflowPresentation.edgeFadeHeight)
                            Rectangle().fill(.black)
                            LinearGradient(colors: [.black, .clear],
                                           startPoint: .top, endPoint: .bottom)
                                .frame(height: V5TaskListOverflowPresentation.edgeFadeHeight)
                        }
                    }
                }

                footer
            }
        }
    }

    private var inlinePresentation: V5InlineTaskSectionsPresentation {
        V5InlineTaskSectionsPresentation(
            activeCount: model.activeTasks.count,
            overdueCount: model.shouldShowOverdueSection ? model.overdueTasks.count : 0,
            completedCount: model.completedTasks.count,
            completedExpanded: completedExpanded
        )
    }

    private var visibleCompletedTasks: [CalendarWorkbenchV5Task] {
        Array(model.completedTasks.prefix(inlinePresentation.visibleCompletedCount))
    }

    private var overdueListItems: [V5TaskListItem] {
        guard model.shouldShowOverdueSection else { return [] }
        return listItems(model.overdueTasks, section: .overdue)
    }

    private var activeListItems: [V5TaskListItem] {
        listItems(model.activeTasks, section: .active)
    }

    private var completedListItems: [V5TaskListItem] {
        listItems(visibleCompletedTasks, section: .completed)
    }

    private func listItems(
        _ tasks: [CalendarWorkbenchV5Task],
        section: V5TaskCompletionSourceSection
    ) -> [V5TaskListItem] {
        var items = tasks
            .filter { !completingTaskIDs.contains($0.id) }
            .map(V5TaskListItem.task)
        if let completionSourceSlot, completionSourceSlot.section == section {
            items.insert(
                .sourceSlot(completionSourceSlot),
                at: min(max(0, completionSourceSlot.insertionIndex), items.count)
            )
        }
        return items
    }

    private var hasNoVisibleTasks: Bool {
        overdueListItems.isEmpty && activeListItems.isEmpty && completedListItems.isEmpty
    }

    @ViewBuilder
    private func listItem(_ item: V5TaskListItem) -> some View {
        switch item {
        case let .task(task):
            taskRow(task)
        case let .sourceSlot(slot):
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: slot.height)
                .accessibilityHidden(true)
        }
    }

    private func taskRow(_ task: CalendarWorkbenchV5Task) -> some View {
        V5QuietTaskRow(
            task: task,
            model: model,
            isSelected: model.selectedTaskID == task.id,
            isLanding: revealedTaskID == task.id,
            reduceMotion: reduceMotion,
            onSelect: {
                composerFocused = false
                model.selectTask(id: task.id)
            },
            onEdit: {
                composerFocused = false
                model.beginEditing(task)
            },
            onToggle: {
                composerFocused = false
                onToggleTask(task.id)
            },
            onDelete: {
                withAnimation(rowAnimation) { model.permanentlyDeleteCompleted(id: task.id) }
            },
            onHoverChange: { hovering in
                if hovering {
                    hoveredTaskID = task.id
                } else if hoveredTaskID == task.id {
                    hoveredTaskID = nil
                }
            }
        )
        .modifier(V5TaskDragModifier(
            taskID: task.id,
            reduceMotion: reduceMotion,
            onChanged: onTaskDragChanged,
            onEnded: onTaskDragEnded
        ))
        .allowsHitTesting(!taskInteractionLocked)
        .background {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .named("v5-workbench"))
                Color.clear.preference(
                    key: V5DragWorkbenchPointsPreferenceKey.self,
                    value: {
                        var value = V5DragWorkbenchPoints()
                        value.taskFrames[task.id] = frame
                        return value
                    }()
                )
            }
        }
        .id(V5TaskRowIdentity.value(taskID: task.id, isCompleted: task.legacy.isCompleted))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.selectionTitle).font(.headline.weight(.semibold))
                Text(model.isTodaySelected ? "逾期优先 · 今天的待办与已完成" : "这一天的待办与已完成")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            V5AppearanceSelector(selection: appearance, reduceMotion: reduceMotion,
                                 onSelect: onSelectAppearance)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭工作台")
        }
    }

    private var quickComposer: some View {
        HStack(spacing: 9) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 17))
                .foregroundStyle(composerFocused ? Color.accentColor : Color.secondary.opacity(0.72))
            TextField("添加待办，回车确认", text: $model.draftTitle)
                .textFieldStyle(.plain)
                .focused($composerFocused)
                .onChange(of: composerFocused) { _, focused in
                    if focused { model.beginComposing() }
                    onTextInputFocusChange(focused)
                }
                .onSubmit {
                    guard !model.draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    withAnimation(rowAnimation) { model.addDraft() }
                    composerFocused = false
                }
                .accessibilityIdentifier("v5-quick-add")
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(quietSurface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(composerFocused ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.09), lineWidth: 1)
        }
        .onTapGesture { model.beginComposing() }
        .animation(.easeOut(duration: 0.12), value: composerFocused)
    }

    private var footer: some View {
        let buildIdentity = AppBuildIdentity.current
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Label(model.isPreviewData ? "隔离预览" : "本地数据", systemImage: "externaldrive.badge.checkmark")
                    .font(.caption)
                Text(buildIdentity.compactLabel)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .textSelection(.enabled)
            }
            .foregroundStyle(.secondary)
            Spacer()
            Text(inlinePresentation.footerSummary)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .transaction { $0.animation = nil }
                .accessibilityIdentifier("v5-inline-task-summary")
        }
    }

    private var quietSurface: Color {
        Color.white.opacity(colorScheme == .dark ? 0.055 : 0.34)
    }

    private var rowAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.1) : .interactiveSpring(response: 0.24, dampingFraction: 0.86)
    }

}

private enum V5TaskListItem: Identifiable {
    case task(CalendarWorkbenchV5Task)
    case sourceSlot(V5TaskCompletionSourceSlot)

    var id: String {
        switch self {
        case let .task(task):
            return "task-\(task.id.uuidString)"
        case let .sourceSlot(slot):
            return "completion-source-slot-\(slot.id.uuidString)"
        }
    }
}

private struct V5ScrollViewConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> V5ScrollViewConfigurationView {
        V5ScrollViewConfigurationView()
    }

    func updateNSView(_ nsView: V5ScrollViewConfigurationView, context: Context) {
        nsView.scheduleConfiguration()
    }
}

private final class V5ScrollViewConfigurationView: NSView {
    private var configurationScheduled = false

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        scheduleConfiguration()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        scheduleConfiguration()
    }

    override func layout() {
        super.layout()
        scheduleConfiguration()
    }

    func scheduleConfiguration() {
        guard !configurationScheduled else { return }
        configurationScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.configurationScheduled = false
            guard let scrollView = self.enclosingScrollView else { return }
            if V5ScrollViewPolicy.apply(to: scrollView) {
                scrollView.tile()
            }
        }
    }
}

private struct V5TaskSectionHeader: View {
    let title: String
    let count: Int
    let symbolName: String
    let tint: Color

    var body: some View {
        Label {
            Text("\(title) \(count)")
        } icon: {
            Image(systemName: symbolName)
                .font(.system(size: 10, weight: .semibold))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.top, 3)
        .padding(.leading, 2)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct V5QuietEmptyState: View {

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "checklist")
                .font(.system(size: 22, weight: .regular)).foregroundStyle(.tertiary)
            Text("暂无待办")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            Text("输入一句话，回车即可添加")
                .font(.caption).foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct V5QuietTaskRow: View {
    let task: CalendarWorkbenchV5Task
    @ObservedObject var model: CalendarWorkbenchV5Model
    let isSelected: Bool
    let isLanding: Bool
    let reduceMotion: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onHoverChange: (Bool) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private let revealPresentation = V5TaskRowRevealPresentation.value
    private let selectionPresentation = V5TaskSelectionPresentation.value

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggle) {
                Image(systemName: task.legacy.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(task.legacy.isCompleted ? Color.accentColor : Color.secondary)
                    .frame(width: 24, height: 30)
                    .background {
                        GeometryReader { proxy in
                            let frame = proxy.frame(in: .named("v5-workbench"))
                            Color.clear.preference(
                                key: V5DragWorkbenchPointsPreferenceKey.self,
                                value: {
                                    var value = V5DragWorkbenchPoints()
                                    value.taskSources[task.id] = V5TaskDragAnchorGeometry.center(of: frame)
                                    return value
                                }()
                            )
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.legacy.isCompleted ? "恢复待办" : "完成待办")

            HStack(spacing: 7) {
                Button(action: onSelect) {
                    HStack(spacing: 7) {
                        V5TaskDateBadge(
                            model: model,
                            taskID: task.id,
                            colorScheme: colorScheme,
                            reduceMotion: reduceMotion
                        )
                        Text(task.legacy.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(task.legacy.isCompleted ? .secondary : .primary)
                            .strikethrough(task.legacy.isCompleted)
                            .lineLimit(1)
                        if let reminder = task.metadata.reminderAt {
                            Image(systemName: V5TaskReminderPlanner.isSchedulable(reminder) ? "bell.fill" : "bell.slash")
                                .font(.system(size: 10))
                                .foregroundStyle(V5TaskReminderPlanner.isSchedulable(reminder)
                                                 ? Color.orange.opacity(0.8) : Color.secondary)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    TapGesture(count: 2).onEnded { onEdit() }
                )
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(rowFill)
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.accentColor.opacity(0.30),
                                Color.accentColor.opacity(0.12),
                                Color.accentColor.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 190
                        )
                    )
                    .scaleEffect(isLanding ? 1.08 : 0.72)
                    .opacity(isLanding ? 1 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? Color.accentColor.opacity(selectionPresentation.borderOpacity)
                        : Color.primary.opacity(isHovered ? 0.11 : 0.06),
                    lineWidth: isSelected ? selectionPresentation.borderWidth : 1
                )
        }
        .shadow(
            color: Color.accentColor.opacity(
                isSelected ? selectionPresentation.primaryGlowOpacity : 0
            ),
            radius: isSelected ? selectionPresentation.primaryGlowRadius : 0
        )
        .shadow(
            color: Color.accentColor.opacity(
                isSelected ? selectionPresentation.secondaryGlowOpacity : 0
            ),
            radius: isSelected ? selectionPresentation.secondaryGlowRadius : 0
        )
        .scaleEffect(revealPresentation.cardScale)
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .onHover { hovering in
            onHoverChange(hovering)
            withAnimation(.easeOut(duration: 0.1)) { isHovered = hovering }
        }
        .contextMenu {
            if task.legacy.isCompleted {
                Button("编辑", action: onEdit)
                Button("标记为未完成", action: onToggle)
                Divider()
                Button("删除", role: .destructive, action: onDelete)
            } else {
                Button("编辑", action: onEdit)
                Button("标记为完成", action: onToggle)
            }
        }
        .animation(reduceMotion ? .linear(duration: 0.05) : .easeOut(duration: 0.08), value: isSelected)
        .animation(
            reduceMotion ? .easeOut(duration: 0.10) : .timingCurve(
                0.16, 0.78, 0.24, 1,
                duration: revealPresentation.innerBloomDuration
            ),
            value: isLanding
        )
    }

    private var rowFill: Color {
        if isSelected {
            return Color.accentColor.opacity(
                colorScheme == .dark
                    ? selectionPresentation.darkFillOpacity
                    : selectionPresentation.lightFillOpacity
            )
        }
        if isHovered { return Color.primary.opacity(colorScheme == .dark ? 0.075 : 0.045) }
        return Color.white.opacity(colorScheme == .dark ? 0.04 : 0.28)
    }
}

private struct V5TaskDateBadge: View {
    @ObservedObject var model: CalendarWorkbenchV5Model
    let taskID: UUID
    let colorScheme: ColorScheme
    let reduceMotion: Bool
    @State private var flipDegrees = 0.0
    @State private var labelOpacity = 1.0

    var body: some View {
        let status = model.task(id: taskID).map {
            V5TaskRowStatusPresentation.resolve(
                task: $0,
                today: model.today,
                calendar: model.calendar
            )
        } ?? V5TaskRowStatusPresentation(dateText: "未排期", isOverdue: false)

        ZStack {
            Capsule()
                .fill(
                    (status.isOverdue ? Color.orange : Color.primary)
                        .opacity(status.isOverdue
                                 ? (colorScheme == .dark ? 0.14 : 0.10)
                                 : (colorScheme == .dark ? 0.08 : 0.055))
                )
            Text(status.dateText)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(status.isOverdue ? Color.orange : Color.secondary)
                .rotation3DEffect(
                    .degrees(flipDegrees),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .bottom,
                    perspective: V5TaskDateFlipPresentation.perspective
                )
                .opacity(labelOpacity)
            .clipped()
        }
        .frame(width: 48, height: 20)
        .contentShape(Capsule())
        .compositingGroup()
        .onChange(of: status.dateText) { _, _ in
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                flipDegrees = reduceMotion ? 0 : -V5TaskDateFlipPresentation.tiltDegrees
                labelOpacity = reduceMotion ? 0.45 : 0.30
            }
            DispatchQueue.main.async {
                withAnimation(
                    reduceMotion
                        ? .easeOut(duration: V5TaskDateFlipPresentation.reducedMotionDuration)
                        : .timingCurve(0.20, 0.72, 0.24, 1,
                                       duration: V5TaskDateFlipPresentation.duration)
                ) {
                    flipDegrees = 0
                    labelOpacity = 1
                }
            }
        }
    }
}

private struct V5TaskDragModifier: ViewModifier {
    let taskID: UUID
    let reduceMotion: Bool
    let onChanged: (UUID, CGPoint, CGPoint) -> Void
    let onEnded: (UUID, CGPoint) -> Void

    @GestureState private var isGestureActive = false

    func body(content: Content) -> some View {
        content
            .opacity(isGestureActive ? 0.18 : 1)
            .scaleEffect(isGestureActive ? 0.985 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.06) :
                        .interactiveSpring(response: 0.28, dampingFraction: 0.84),
                       value: isGestureActive)
            .simultaneousGesture(
                DragGesture(
                    minimumDistance: V5TaskDragGesturePolicy.minimumDistance,
                    coordinateSpace: .named("v5-workbench")
                )
                    .updating($isGestureActive) { _, isGestureActive, _ in
                        isGestureActive = true
                    }
                    .onChanged { value in
                        onChanged(taskID, value.location, value.startLocation)
                    }
                    .onEnded { value in
                        onEnded(taskID, value.location)
                    }
            )
    }
}

private struct V5AppearanceSelector: View {
    let selection: V5AppearancePreference
    let reduceMotion: Bool
    let onSelect: (V5AppearancePreference) -> Void

    @Namespace private var liquidSelection

    var body: some View {
        HStack(spacing: 2) {
            ForEach(V5AppearancePreference.allCases, id: \.rawValue) { option in
                Button {
                    onSelect(option)
                } label: {
                    ZStack {
                        if selection == option {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.primary.opacity(0.095))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.8)
                                }
                                .matchedGeometryEffect(id: "v5-appearance-liquid", in: liquidSelection)
                        }
                        Image(systemName: option.symbolName)
                            .font(.system(size: 11, weight: selection == option ? .semibold : .regular))
                            .foregroundStyle(selection == option ? Color.primary : Color.secondary)
                    }
                    .frame(width: 27, height: 26)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(option.title)
                .accessibilityLabel("外观：\(option.title)")
                .accessibilityIdentifier("v5-appearance-\(option.rawValue)")
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 0.8)
        }
    }
}

private struct V5FocusedTaskEditor: View {
    let task: CalendarWorkbenchV5Task
    @ObservedObject var model: CalendarWorkbenchV5Model
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var title: String
    @State private var details: String
    @State private var date: Date
    @State private var reminderEnabled: Bool
    @State private var reminder: Date

    init(task: CalendarWorkbenchV5Task, model: CalendarWorkbenchV5Model, onClose: @escaping () -> Void) {
        self.task = task
        self.model = model
        self.onClose = onClose
        let draft = model.editDraft(for: task)
        _title = State(initialValue: draft.title)
        _details = State(initialValue: draft.details)
        _date = State(initialValue: draft.date)
        _reminderEnabled = State(initialValue: draft.reminderEnabled)
        _reminder = State(initialValue: draft.reminder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button { model.endEditing() } label: {
                    Image(systemName: "chevron.left").frame(width: 26, height: 26)
                }
                .buttonStyle(.plain).accessibilityLabel("返回待办列表")
                Text("编辑待办").font(.headline.weight(.semibold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).frame(width: 28, height: 28)
                        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            fieldSection("内容") {
                TextField("待办内容", text: $title).textFieldStyle(.plain).padding(.horizontal, 11).frame(height: 38).background(fieldFill, in: RoundedRectangle(cornerRadius: 9))
            }

            fieldSection("描述") {
                TextField("简短描述（可选）", text: $details).textFieldStyle(.plain).padding(.horizontal, 11).frame(height: 38).background(fieldFill, in: RoundedRectangle(cornerRadius: 9))
            }

            fieldSection("日期") {
                V5FullDatePicker(date: $date, calendar: model.calendar)
            }

            VStack(alignment: .leading, spacing: 10) {
                Toggle("提醒", isOn: $reminderEnabled).toggleStyle(.checkbox)
                if reminderEnabled {
                    DatePicker("提醒时间", selection: $reminder, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.field).frame(maxWidth: 230, alignment: .leading)
                    if reminderIsInvalid {
                        Text("提醒时间必须晚于现在")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Spacer()

            HStack {
                Button("取消") { model.discardEditDraft(for: task.id) }.buttonStyle(.bordered)
                Spacer()
                Button("保存") {
                    model.update(
                        id: task.id,
                        title: title,
                        details: details,
                        date: date,
                        reminderEnabled: reminderEnabled,
                        reminder: combinedReminder
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || reminderIsInvalid)
            }
        }
        .onChange(of: title) { _, _ in persistDraft() }
        .onChange(of: details) { _, _ in persistDraft() }
        .onChange(of: date) { _, newDate in
            if reminderEnabled {
                let time = model.calendar.dateComponents([.hour, .minute], from: reminder)
                reminder = model.calendar.date(
                    bySettingHour: time.hour ?? 9,
                    minute: time.minute ?? 0,
                    second: 0,
                    of: newDate
                ) ?? reminder
            }
            persistDraft()
        }
        .onChange(of: reminderEnabled) { _, enabled in
            if enabled && !V5TaskReminderPlanner.isSchedulable(combinedReminder) {
                reminder = V5TaskReminderPlanner.defaultReminder(forDueDate: date)
            }
            persistDraft()
        }
        .onChange(of: reminder) { _, _ in
            persistDraft()
        }
    }

    private func fieldSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private var fieldFill: Color { Color.white.opacity(colorScheme == .dark ? 0.07 : 0.42) }

    private var combinedReminder: Date {
        let time = model.calendar.dateComponents([.hour, .minute], from: reminder)
        return model.calendar.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: 0, of: date) ?? date
    }

    private var reminderIsInvalid: Bool {
        reminderEnabled && !V5TaskReminderPlanner.isSchedulable(combinedReminder)
    }

    private func persistDraft() {
        model.storeEditDraft(
            V5TaskEditDraft(
                title: title,
                details: details,
                date: date,
                reminderEnabled: reminderEnabled,
                reminder: reminder
            ),
            for: task.id
        )
    }
}

private struct V5FullDatePicker: View {
    @Binding var date: Date
    let calendar: Calendar

    var body: some View {
        HStack(spacing: 8) {
            componentPicker(selection: yearBinding, values: Array((year - 5)...(year + 10))) { "\($0) 年" }
                .frame(width: 112)
            componentPicker(selection: monthBinding, values: Array(1...12)) { "\($0) 月" }
                .frame(width: 88)
            componentPicker(selection: dayBinding, values: Array(1...daysInMonth)) { "\($0) 日" }
                .frame(width: 88)
            Spacer(minLength: 0)
        }
    }

    private func componentPicker(selection: Binding<Int>, values: [Int], title: @escaping (Int) -> String) -> some View {
        Picker("", selection: selection) {
            ForEach(values, id: \.self) { value in Text(title(value)).tag(value) }
        }
        .labelsHidden().pickerStyle(.menu)
    }

    private var year: Int { calendar.component(.year, from: date) }
    private var month: Int { calendar.component(.month, from: date) }
    private var day: Int { calendar.component(.day, from: date) }
    private var daysInMonth: Int { calendar.range(of: .day, in: .month, for: date)?.count ?? 31 }

    private var yearBinding: Binding<Int> { Binding(get: { year }, set: { update(year: $0) }) }
    private var monthBinding: Binding<Int> { Binding(get: { month }, set: { update(month: $0) }) }
    private var dayBinding: Binding<Int> { Binding(get: { day }, set: { update(day: $0) }) }

    private func update(year newYear: Int? = nil, month newMonth: Int? = nil, day newDay: Int? = nil) {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.year = newYear ?? components.year
        components.month = newMonth ?? components.month
        components.day = 1
        guard let monthStart = calendar.date(from: components) else { return }
        let maxDay = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 31
        components.day = min(newDay ?? day, maxDay)
        if let updated = calendar.date(from: components) { date = updated }
    }
}

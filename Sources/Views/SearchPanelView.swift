import SwiftUI
import AppKit

private enum SearchScope: String, CaseIterable {
    case all = "全部"
    case skills = "Skill"
    case prompts = "提示词"
}

private enum UnifiedSearchResult: Identifiable {
    case prompt(PromptItem)
    case skill(SkillItem)

    var id: String {
        switch self {
        case .prompt(let prompt): return "prompt-\(prompt.id.uuidString)"
        case .skill(let skill): return "skill-\(skill.id)"
        }
    }
}

/// Keyboard-first search for both prompts and locally indexed Skills.
struct SearchPanelView: View {
    @ObservedObject var promptStore: PromptStore
    @ObservedObject var skillStore: SkillStore
    @ObservedObject var clipboard: ClipboardService
    @ObservedObject var feedback: FeedbackStore
    let actions: AppActions

    @State private var query = ""
    @State private var scope: SearchScope = .all
    @State private var category = "全部"
    @State private var favoritesOnly = false
    @State private var selectedIndex = 0
    @State private var keyboardScrollTarget: String?
    @FocusState private var searchFocused: Bool

    private var results: [UnifiedSearchResult] {
        let promptResults: [PromptItem]
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            promptResults = Array(promptStore.prompts.prefix(20))
        } else {
            promptResults = promptStore.prompts.filter {
                $0.title.localizedCaseInsensitiveContains(query)
                    || $0.content.localizedCaseInsensitiveContains(query)
                    || $0.group.localizedCaseInsensitiveContains(query)
            }
        }

        let skillResults: [SkillItem]
        skillResults = skillStore.matching(
            query: query,
            category: category == "全部" ? nil : category,
            favoritesOnly: favoritesOnly,
            limit: 40
        )

        switch scope {
        case .all:
            return skillResults.map(UnifiedSearchResult.skill)
                + promptResults.map(UnifiedSearchResult.prompt)
        case .skills:
            return skillResults.map(UnifiedSearchResult.skill)
        case .prompts:
            return promptResults.map(UnifiedSearchResult.prompt)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let hud = feedback.hudMessage {
                HUDView(message: hud)
                    .padding(.top, 8)
                    .transition(.opacity)
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.title3)
                TextField("搜索任务用途、Skill 或提示词...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($searchFocused)
                    .onSubmit { copySelected() }
                    .onChange(of: query) { _, _ in resetSelection() }
                if skillStore.isScanning {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Picker("范围", selection: $scope) {
                ForEach(SearchScope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            .onChange(of: scope) { _, _ in resetSelection() }

            HStack(spacing: 12) {
                Picker("分类", selection: $category) {
                    Text("全部分类").tag("全部")
                    ForEach(SkillCategories.all, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 180, alignment: .leading)
                .disabled(scope == .prompts)
                Toggle("仅收藏 Skill", isOn: $favoritesOnly)
                    .toggleStyle(.checkbox)
                    .disabled(scope == .prompts)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            .onChange(of: category) { _, _ in resetSelection() }
            .onChange(of: favoritesOnly) { _, _ in resetSelection() }

            Divider()

            if results.isEmpty {
                ContentUnavailableView(
                    query.isEmpty ? "暂无内容" : "没有匹配结果",
                    systemImage: "magnifyingglass",
                    description: Text(skillStore.isScanning ? "Skill 正在扫描，请稍候" : "尝试输入名称或用途关键词")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                                resultRow(result, index: index)
                                    .id(result.id)
                            }
                        }
                        .padding(6)
                    }
                    .id(resultSetID)
                    .scrollIndicators(.visible)
                    .scrollBounceBehavior(.basedOnSize)
                    .background(NativeScrollViewConfiguration())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .onChange(of: keyboardScrollTarget) { _, target in
                        guard let target else { return }
                        withAnimation(.easeOut(duration: 0.12)) {
                            proxy.scrollTo(target, anchor: .center)
                        }
                    }
                }
            }

            HStack {
                Text(skillStore.scanSummary)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Spacer()
                Text("Return 复制调用语句")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(.black.opacity(0.03))
        }
        .onAppear {
            searchFocused = true
            if skillStore.skills.isEmpty && !skillStore.isScanning { skillStore.scan() }
        }
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.escape) { actions.closeSearch(); return .handled }
        .animation(.easeInOut(duration: 0.16), value: feedback.hudMessage)
        .liquidGlass()
    }

    @ViewBuilder
    private func resultRow(_ result: UnifiedSearchResult, index: Int) -> some View {
        switch result {
        case .prompt(let prompt):
            Button {
                selectedIndex = index
                clipboard.copyPrompt(prompt)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "text.bubble")
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(prompt.title).fontWeight(.medium).lineLimit(1)
                        Text(prompt.content).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text(prompt.group.isEmpty ? "提示词" : prompt.group)
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(selectionBackground(index))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { if $0 { selectedIndex = index } }

        case .skill(let skill):
            HStack(spacing: 8) {
                Button {
                    selectedIndex = index
                    clipboard.copySkillInvocation(skill)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.blue)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(skill.callToken).fontWeight(.semibold).lineLimit(1)
                            Text(skill.displaySummary).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            Text(skill.invocation())
                                .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                        }
                        Spacer(minLength: 6)
                        Text(skill.category)
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button { clipboard.copySkillName(skill) } label: {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help("只复制 \(skill.callToken)")

                Button { skillStore.toggleFavorite(skill) } label: {
                    Image(systemName: skill.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(skill.isFavorite ? .yellow : .secondary)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help(skill.isFavorite ? "取消收藏" : "收藏")
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selectionBackground(index))
            .contentShape(Rectangle())
            .onHover { if $0 { selectedIndex = index } }
        }
    }

    private func selectionBackground(_ index: Int) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(index == selectedIndex ? Color.accentColor.opacity(0.14) : Color.clear)
    }

    private var resultSetID: String {
        "\(scope.rawValue)|\(category)|\(favoritesOnly)|\(query)"
    }

    private func moveSelection(by offset: Int) {
        guard !results.isEmpty else { return }
        let next = min(max(selectedIndex + offset, 0), results.count - 1)
        guard next != selectedIndex else { return }
        selectedIndex = next
        keyboardScrollTarget = results[next].id
    }

    private func resetSelection() {
        selectedIndex = 0
        keyboardScrollTarget = nil
    }

    private func copySelected() {
        guard results.indices.contains(selectedIndex) else { return }
        switch results[selectedIndex] {
        case .prompt(let prompt): clipboard.copyPrompt(prompt)
        case .skill(let skill): clipboard.copySkillInvocation(skill)
        }
    }
}

/// SwiftUI follows the user's global scroller and elasticity preferences.
/// Search results need a stable, explicit scrollbar and no whole-list bounce,
/// so configure only the enclosing native scroll view.
private struct NativeScrollViewConfiguration: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            var ancestor = view.superview
            while let current = ancestor {
                if let scrollView = current as? NSScrollView {
                    scrollView.hasVerticalScroller = true
                    scrollView.autohidesScrollers = false
                    scrollView.verticalScrollElasticity = .none
                    scrollView.horizontalScrollElasticity = .none
                    return
                }
                ancestor = current.superview
            }
        }
    }
}

/// Minimal floating text field for quick task entry.
struct QuickAddTaskView: View {
    @ObservedObject var taskStore: TaskStore
    let actions: AppActions
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill").foregroundStyle(.blue).font(.title3)
            TextField("快速添加任务...", text: $text)
                .textFieldStyle(.plain).font(.title3)
                .focused($focused)
                .onSubmit {
                    taskStore.addTask(text)
                    text = ""
                    actions.closeQuickAdd()
                }
        }
        .padding(16)
        .onAppear { focused = true }
        .onKeyPress(.escape) { actions.closeQuickAdd(); return .handled }
    }
}

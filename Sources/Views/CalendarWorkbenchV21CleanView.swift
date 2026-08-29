import SwiftUI
import AppKit

struct CalendarWorkbenchV21CleanView: View {
    @ObservedObject var model: CalendarWorkbenchV21CleanModel
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    private let columns = Array(repeating: GridItem(.fixed(82), spacing: 4), count: 7)
    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            calendarPane
                .frame(width: 650)

            Rectangle()
                .fill(separatorColor)
                .frame(width: 1)

            sidebar
                .frame(width: 409)
        }
        .frame(width: 1060, height: 660)
        .background(rootTint)
        .glassBorder(cornerRadius: 18)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear { model.refreshToday() }
        .onReceive(minuteTimer) { model.refreshToday(now: $0) }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            moveMonth(by: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            moveMonth(by: 1)
            return .handled
        }
    }

    private var calendarPane: some View {
        VStack(spacing: 0) {
            calendarHeader
                .frame(height: 38)
                .padding(.bottom, 13)

            HStack(spacing: 4) {
                ForEach(model.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 82)
                }
            }
            .padding(.bottom, 7)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(model.monthDays.enumerated()), id: \.offset) { _, date in
                    CalendarWorkbenchV21CleanDayCell(
                        date: date,
                        calendar: model.calendar,
                        today: model.today,
                        isInDisplayedMonth: model.calendar.isDate(
                            date,
                            equalTo: model.displayedMonth,
                            toGranularity: .month
                        ),
                        isSelected: model.selectedDate.map {
                            model.calendar.isDate(date, inSameDayAs: $0)
                        } ?? false,
                        itemCount: model.itemCount(on: date),
                        reduceMotion: reduceMotion
                    ) {
                        withAnimation(selectionAnimation) { model.select(date) }
                    }
                }
            }
            .id(model.displayedMonth)
            .transition(.opacity)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 19)
        .padding(.bottom, 17)
    }

    private var calendarHeader: some View {
        HStack(spacing: 9) {
            Text(model.monthTitle)
                .font(.system(size: 20, weight: .semibold))
                .monospacedDigit()

            CalendarWorkbenchV21CleanDragRegion()
                .frame(minWidth: 96, maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)

            monthButton(systemImage: "chevron.left", label: "上个月") {
                moveMonth(by: -1)
            }

            Button("今天") {
                withAnimation(selectionAnimation) { model.jumpToToday() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            monthButton(systemImage: "chevron.right", label: "下个月") {
                moveMonth(by: 1)
            }
        }
    }

    private func monthButton(systemImage: String, label: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 40, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(CalendarWorkbenchV21CleanPressStyle(reduceMotion: reduceMotion))
        .accessibilityLabel(label)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.selectionTitle)
                        .font(.headline.weight(.semibold))
                    Text(model.selectedDate == nil ? "隔离视觉预览" : "已按日期筛选")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if model.selectedDate != nil {
                    Button("全部") {
                        withAnimation(selectionAnimation) { model.showAll() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 28, height: 28)
                        .background(
                            Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .keyboardShortcut("w", modifiers: .command)
                .accessibilityLabel("关闭日历工作台")
            }

            Divider().opacity(0.42)

            if model.visibleItems.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                    Text("这一天还没有安排")
                        .font(.subheadline.weight(.semibold))
                    Text("当前版本只验证日历视觉与日期选择，不会写入任何数据。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(cardBorder)
            } else {
                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(model.visibleItems) { item in
                            CalendarWorkbenchV21CleanItemRow(
                                item: item,
                                dateText: relativeDate(item.date),
                                reduceMotion: reduceMotion,
                                fill: cardFill,
                                borderColor: cardBorderColor
                            )
                        }
                    }
                    .padding(.horizontal, 1)
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }

            Spacer(minLength: 0)

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(Color.accentColor)
                Text("当前为内存预览：不读取任务，不安排通知，不修改设置。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(footerFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .padding(.horizontal, 20)
        .padding(.top, 19)
        .padding(.bottom, 18)
    }

    private var selectionAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : .interactiveSpring(response: 0.23, dampingFraction: 0.94, blendDuration: 0.04)
    }

    private func moveMonth(by value: Int) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.10) : .easeInOut(duration: 0.15)) {
            model.moveMonth(by: value)
        }
    }

    private func relativeDate(_ date: Date) -> String {
        if model.calendar.isDateInToday(date) { return "今天" }
        if model.calendar.isDateInTomorrow(date) { return "明天" }
        let days = model.calendar.dateComponents(
            [.day], from: model.today, to: model.calendar.startOfDay(for: date)
        ).day ?? 0
        if days > 0 { return "\(days) 天后" }
        if days < 0 { return "\(abs(days)) 天前" }
        return "当天"
    }

    private var rootTint: Color {
        if reduceTransparency {
            return colorScheme == .dark
                ? Color(nsColor: .windowBackgroundColor)
                : Color(nsColor: .controlBackgroundColor)
        }
        return colorScheme == .dark
            ? Color(red: 0.025, green: 0.075, blue: 0.13).opacity(0.46)
            : Color.white.opacity(0.20)
    }

    private var separatorColor: Color {
        contrast == .increased ? Color.primary.opacity(0.34) : Color.primary.opacity(0.12)
    }

    private var cardFill: Color {
        if reduceTransparency {
            return Color(nsColor: .controlBackgroundColor)
        }
        return Color.white.opacity(colorScheme == .dark ? 0.09 : 0.48)
    }

    private var cardBorderColor: Color {
        contrast == .increased
            ? Color.primary.opacity(0.42)
            : Color.white.opacity(colorScheme == .dark ? 0.16 : 0.72)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(cardBorderColor, lineWidth: contrast == .increased ? 1.5 : 1)
    }

    private var footerFill: Color {
        Color.accentColor.opacity(colorScheme == .dark ? 0.10 : 0.07)
    }
}

private struct CalendarWorkbenchV21CleanDayCell: View {
    let date: Date
    let calendar: Calendar
    let today: Date
    let isInDisplayedMonth: Bool
    let isSelected: Bool
    let itemCount: Int
    let reduceMotion: Bool
    let onSelect: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var isHovered = false

    private var isToday: Bool { calendar.isDate(date, inSameDayAs: today) }
    private var isTodaySelected: Bool { isToday && isSelected }
    private var showsHover: Bool { isHovered && !isSelected && !isToday }

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                stateContainer

                VStack(spacing: 3) {
                    Text(String(calendar.component(.day, from: date)))
                        .font(.system(size: 30, weight: isToday || isSelected ? .semibold : .medium))
                        .monospacedDigit()
                        .foregroundStyle(dayColor)
                    Text(lunarLabel)
                        .font(.system(size: 14, weight: isFestival ? .medium : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.92)
                        .foregroundStyle(lunarColor)
                }
                .opacity(isInDisplayedMonth ? 1 : (colorScheme == .dark ? 0.35 : 0.30))

                if isTodaySelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 9, height: 9)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.leading, 7)
                        .padding(.top, 6)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.72).combined(with: .opacity))
                }

                if itemCount > 0 && !isTodaySelected {
                    HStack(spacing: 3) {
                        Circle().fill(Color.accentColor).frame(width: 5, height: 5)
                        if itemCount > 1 {
                            Text("\(itemCount)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 3)
                }
            }
            .frame(width: 82, height: 78)
            .contentShape(Rectangle())
        }
        .buttonStyle(CalendarWorkbenchV21CleanPressStyle(reduceMotion: reduceMotion))
        .onHover { hovering in
            withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.10)) {
                isHovered = hovering
            }
        }
        .animation(stateAnimation, value: isSelected)
        .animation(stateAnimation, value: isTodaySelected)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var stateContainer: some View {
        if reduceMotion {
            ZStack {
                stateShape(radius: 36, width: 72, height: 72,
                           fill: todayFill, stroke: todayStroke, lineWidth: 1.8)
                    .opacity(isToday && !isSelected ? 1 : 0)
                stateShape(radius: 14, width: 82, height: 76,
                           fill: selectedFill, stroke: selectedStroke, lineWidth: 2.4)
                    .opacity(isSelected ? 1 : 0)
                stateShape(radius: 14, width: 82, height: 76,
                           fill: hoverFill, stroke: hoverStroke, lineWidth: 1.2)
                    .opacity(showsHover ? 1 : 0)
            }
        } else {
            stateShape(
                radius: isToday && !isSelected ? 36 : 14,
                width: isToday && !isSelected ? 72 : 82,
                height: isToday && !isSelected ? 72 : 76,
                fill: currentFill,
                stroke: currentStroke,
                lineWidth: isSelected ? 2.4 : (isToday ? 1.8 : 1.2)
            )
            .opacity(isToday || isSelected || showsHover ? 1 : 0)
            .scaleEffect(showsHover ? 1 : 0.98)
        }
    }

    private func stateShape(radius: CGFloat, width: CGFloat, height: CGFloat,
                            fill: Color, stroke: Color, lineWidth: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(fill)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: lineWidth)
            }
            .frame(width: width, height: height)
    }

    private var currentFill: Color {
        if isSelected { return selectedFill }
        if isToday { return todayFill }
        if showsHover { return hoverFill }
        return .clear
    }

    private var currentStroke: Color {
        if isSelected { return selectedStroke }
        if isToday { return todayStroke }
        if showsHover { return hoverStroke }
        return .clear
    }

    private var selectedFill: Color {
        Color.accentColor.opacity(colorScheme == .dark ? 0.15 : 0.09)
    }

    private var selectedStroke: Color {
        Color.accentColor.opacity(contrast == .increased ? 1 : 0.92)
    }

    private var todayFill: Color {
        Color.accentColor.opacity(colorScheme == .dark ? 0.09 : 0.045)
    }

    private var todayStroke: Color { Color.accentColor.opacity(0.62) }

    private var hoverFill: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.075 : 0.035)
    }

    private var hoverStroke: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.24 : 0.16)
    }

    private var dayColor: Color {
        if isFestival { return Color(nsColor: .systemRed) }
        if isToday { return Color.accentColor }
        return .primary
    }

    private var lunarColor: Color {
        if isFestival { return Color(nsColor: .systemRed) }
        if isToday { return Color.accentColor }
        return Color.primary.opacity(0.84)
    }

    private var lunarLabel: String { CalendarWorkbenchV21Lunar.label(for: date) }
    private var isFestival: Bool { CalendarWorkbenchV21Lunar.isFestival(date) }

    private var stateAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : .interactiveSpring(response: 0.23, dampingFraction: 0.94, blendDuration: 0.04)
    }

    private var accessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        let state = [isToday ? "今天" : nil, isSelected ? "已选中" : nil].compactMap { $0 }
        let suffix = state.isEmpty ? "" : "，\(state.joined(separator: "，"))"
        return "\(formatter.string(from: date))，农历\(lunarLabel)\(suffix)"
    }
}

private struct CalendarWorkbenchV21CleanItemRow: View {
    let item: CalendarWorkbenchV21CleanItem
    let dateText: String
    let reduceMotion: Bool
    let fill: Color
    let borderColor: Color

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: item.isImportant ? "star.fill" : "circle")
                .font(.system(size: item.isImportant ? 13 : 16, weight: .medium))
                .foregroundStyle(item.isImportant ? Color.accentColor : Color.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Label(dateText, systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isHovered ? Color.accentColor : Color.secondary)
        }
        .padding(.horizontal, 12)
        .frame(height: 66)
        .background(fill.opacity(isHovered ? 1 : 0.86), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isHovered ? Color.accentColor.opacity(0.45) : borderColor, lineWidth: 1)
        }
        .onHover { hovering in
            withAnimation(reduceMotion ? .easeOut(duration: 0.10) : .easeOut(duration: 0.09)) {
                isHovered = hovering
            }
        }
    }
}

private struct CalendarWorkbenchV21CleanPressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.98 : 1))
            .opacity(reduceMotion && configuration.isPressed ? 0.78 : 1)
            .animation(.easeOut(duration: 0.07), value: configuration.isPressed)
    }
}

private struct CalendarWorkbenchV21CleanDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

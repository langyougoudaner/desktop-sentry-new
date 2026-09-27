from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def section(source: str, start: str, end: str) -> str:
    return source[source.index(start):source.index(end, source.index(start))]


view = (ROOT / "Sources/Views/CalendarWorkbenchV5View.swift").read_text()
drag_commit = section(
    view,
    "    private func finishTaskDrag(",
    "    private func permittedDropDate(",
)
if "performTaskListMutation(for: .taskDateMoved)" not in drag_commit:
    raise SystemExit(
        "FAIL: a date drop is published outside the non-animated task-list transaction"
    )

sidebar = (ROOT / "Sources/Views/CalendarWorkbenchV5Sidebar.swift").read_text()
task_row = section(
    sidebar,
    "    private func taskRow(",
    "    private func taskRowIdentity(",
)
if "model: model" not in task_row or "taskID: task.id" not in task_row:
    raise SystemExit(
        "FAIL: the stable task row is not connected directly to the live task model"
    )

quiet_row = section(
    sidebar,
    "private struct V5QuietTaskRow: View {",
    "private struct V5TaskDateBadge: View {",
)
if "@ObservedObject var model: CalendarWorkbenchV5Model" not in quiet_row:
    raise SystemExit(
        "FAIL: a reused task card cannot observe a date move independently of its parent list"
    )
if "V5TaskRowStatusPresentation.resolve(" not in quiet_row:
    raise SystemExit(
        "FAIL: card date text and overdue color do not share the authoritative status resolver"
    )

sidebar_header = section(
    sidebar,
    "struct CalendarWorkbenchV5Sidebar: View {",
    "    @Environment(\\.accessibilityReduceMotion)",
)
for callback in (
    "let onToggleTask: (UUID) -> Void",
    "let onTaskDragChanged: (UUID, CGPoint, CGPoint) -> Void",
    "let onTaskDragEnded: (UUID, CGPoint) -> Void",
):
    if callback not in sidebar_header:
        raise SystemExit(
            "FAIL: task actions still carry a potentially stale rendered task snapshot"
        )

date_badge = section(
    sidebar,
    "private struct V5TaskDateBadge: View {",
    "private struct V5DatePageTurnModifier:",
)
if ".id(dateText)" in date_badge or ".transition(" in date_badge:
    raise SystemExit(
        "FAIL: the date badge retains an outgoing text layer over the new authoritative date"
    )

print("v5-task-date-rendering=passed")

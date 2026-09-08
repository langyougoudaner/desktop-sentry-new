#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODULE_CACHE_DIR="/private/tmp/DesktopSentryManagedCache"
RUN_DIR="$(mktemp -d /private/tmp/DesktopSentryValidation.XXXXXX)"
trap 'rm -rf "$RUN_DIR"' EXIT
cd "$SCRIPT_DIR"

compile_and_run() {
    local name="$1"
    shift
    swiftc -parse-as-library -module-cache-path "$MODULE_CACHE_DIR" "$@" \
        -o "$RUN_DIR/$name"
    "$RUN_DIR/$name"
}

compile_and_run notification \
    -framework UserNotifications -framework Combine \
    Sources/Models/TaskItem.swift \
    Sources/Models/CalendarWorkbenchV5Model.swift \
    Sources/Models/V5WorkbenchPresentation.swift \
    Sources/Models/V5TaskReminderPlanner.swift \
    Sources/Services/V5TaskNotificationScheduler.swift \
    Tests/V5TaskNotificationSchedulerSmoke/main.swift

compile_and_run persistence \
    -framework UserNotifications -framework Combine \
    Sources/Models/TaskItem.swift Sources/Models/SkillItem.swift \
    Sources/Models/AppData.swift Sources/Models/DeadlineItem.swift \
    Sources/Store/StorageManager.swift Sources/Store/DeadlineStorage.swift \
    Tests/PersistenceFlushSmoke/main.swift

compile_and_run state \
    -framework Combine \
    Sources/Models/TaskItem.swift Sources/Models/V5WorkbenchPresentation.swift \
    Sources/Models/V5TaskReminderPlanner.swift Sources/Models/CalendarWorkbenchV5Model.swift \
    Sources/Store/V5TaskMetadataStore.swift Tests/V5TaskStateMachineSmoke/main.swift

compile_and_run date-movement-adversarial \
    -framework Combine \
    Sources/Models/TaskItem.swift Sources/Models/V5WorkbenchPresentation.swift \
    Sources/Models/V5TaskReminderPlanner.swift Sources/Models/CalendarWorkbenchV5Model.swift \
    Tests/V5TaskDateMovementAdversarial/main.swift

compile_and_run calendar-model \
    -framework Combine \
    Sources/Models/TaskItem.swift Sources/Models/V5WorkbenchPresentation.swift \
    Sources/Models/V5TaskReminderPlanner.swift Sources/Models/CalendarWorkbenchV5Model.swift \
    Sources/Store/V5TaskMetadataStore.swift Tests/CalendarWorkbenchV5Smoke/main.swift

compile_and_run presentation \
    -framework Combine \
    Sources/Models/V5WorkbenchPresentation.swift Sources/Models/TaskItem.swift \
    Sources/Models/V5TaskReminderPlanner.swift Sources/Models/CalendarWorkbenchV5Model.swift \
    Tests/V5WorkbenchPresentationSmoke/main.swift

compile_and_run row-interaction \
    -framework Combine \
    Sources/Models/TaskItem.swift Sources/Models/V5TaskReminderPlanner.swift \
    Sources/Models/CalendarWorkbenchV5Model.swift Sources/Models/V5WorkbenchPresentation.swift \
    Tests/V5TaskRowInteractionSmoke/main.swift

compile_and_run reminder \
    -framework Combine \
    Sources/Models/TaskItem.swift Sources/Models/CalendarWorkbenchV5Model.swift \
    Sources/Models/V5TaskReminderPlanner.swift Sources/Models/V5WorkbenchPresentation.swift \
    Tests/TaskReminderSmoke/main.swift

compile_and_run preview-routing \
    Sources/App/DesktopSentryPreviewRouting.swift Tests/PreviewRoutingSmoke/main.swift

compile_and_run scroll-policy \
    -framework AppKit Sources/Views/Components/V5ScrollViewPolicy.swift \
    Tests/V5ScrollViewPolicySmoke/main.swift

echo "focused-checks=passed"

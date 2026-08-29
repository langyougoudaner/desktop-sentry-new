#!/bin/bash
# ──────────────────────────────────────────────
# Desktop Sentry — source build with traceable binary identity
# ──────────────────────────────────────────────
set -euo pipefail

APP_NAME="DesktopSentry"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# Release and validation workflows can place disposable products outside the
# repository instead of leaving a large build cache behind.
BUILD_DIR="${DESKTOP_SENTRY_BUILD_DIR:-${SCRIPT_DIR}/build}"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
MODULE_CACHE_DIR="${BUILD_DIR}/ModuleCache"

# ── Detect architecture ──
ARCH="$(uname -m)"
case "$ARCH" in
    arm64)  TARGET="arm64-apple-macos14.0" ;;
    x86_64) TARGET="x86_64-apple-macos14.0" ;;
    *)      echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "▶ Building $APP_NAME for $ARCH …"

# ── Recreate bundle structure ──
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# The currently installed CLT may expose a newer default SDK than its Swift
# module interfaces support. This app targets macOS 14 and uses no SDK-26-only
# APIs, so prefer the compatible 15.4 SDK when it is available.
SDK_PATH="$(xcrun --show-sdk-path)"
COMPATIBLE_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk"
if [[ -d "$COMPATIBLE_SDK" ]]; then
    SDK_PATH="$COMPATIBLE_SDK"
fi
mkdir -p "$MODULE_CACHE_DIR"

# ── Info.plist ──
cp "${SCRIPT_DIR}/Info.plist" "${CONTENTS_DIR}/Info.plist"

# Source builds are previews unless a release workflow explicitly opts in.
BUILD_CHANNEL="${DESKTOP_SENTRY_BUILD_CHANNEL:-preview}"
case "$BUILD_CHANNEL" in
    preview|release) ;;
    *) echo "Unsupported build channel: $BUILD_CHANNEL"; exit 1 ;;
esac

SOURCE_REVISION="$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || printf 'unknown')"
SOURCE_DIRTY=false
if [[ -n "$(git -C "$SCRIPT_DIR" status --porcelain --untracked-files=normal 2>/dev/null)" ]]; then
    SOURCE_DIRTY=true
fi

/usr/libexec/PlistBuddy -c "Add :DesktopSentryWorkbenchGeneration string V5" "${CONTENTS_DIR}/Info.plist"
/usr/libexec/PlistBuddy -c "Add :DesktopSentrySourceRevision string $SOURCE_REVISION" "${CONTENTS_DIR}/Info.plist"
/usr/libexec/PlistBuddy -c "Add :DesktopSentrySourceDirty bool $SOURCE_DIRTY" "${CONTENTS_DIR}/Info.plist"
/usr/libexec/PlistBuddy -c "Add :DesktopSentryBuildChannel string $BUILD_CHANNEL" "${CONTENTS_DIR}/Info.plist"

ICON_FILE="${SCRIPT_DIR}/Resources/AppIcon.icns"
if [[ ! -f "$ICON_FILE" ]]; then
    echo "Missing required app icon: $ICON_FILE"
    exit 1
fi
cp "$ICON_FILE" "${RESOURCES_DIR}/AppIcon.icns"

# ── PkgInfo ──
printf 'APPL????' > "${CONTENTS_DIR}/PkgInfo"

# ── Swift sources ──
SOURCES=(
    "${SCRIPT_DIR}/Sources/DesktopSentryApp.swift"
    "${SCRIPT_DIR}/Sources/Models/TaskItem.swift"
    "${SCRIPT_DIR}/Sources/Models/SkillItem.swift"
    "${SCRIPT_DIR}/Sources/Models/AppData.swift"
    "${SCRIPT_DIR}/Sources/Models/AppBuildIdentity.swift"
    "${SCRIPT_DIR}/Sources/Models/DeadlineItem.swift"
    "${SCRIPT_DIR}/Sources/Models/CalendarWorkbenchV2Model.swift"
    "${SCRIPT_DIR}/Sources/Models/CalendarWorkbenchV21PreviewModel.swift"
    "${SCRIPT_DIR}/Sources/Models/CalendarWorkbenchV21CleanModel.swift"
    "${SCRIPT_DIR}/Sources/Models/CalendarWorkbenchV5Model.swift"
    "${SCRIPT_DIR}/Sources/Models/V5WorkbenchPresentation.swift"
    "${SCRIPT_DIR}/Sources/Store/StorageManager.swift"
    "${SCRIPT_DIR}/Sources/Store/DeadlineStorage.swift"
    "${SCRIPT_DIR}/Sources/Store/DeadlineStore.swift"
    "${SCRIPT_DIR}/Sources/Store/TaskStore.swift"
    "${SCRIPT_DIR}/Sources/Store/V5TaskMetadataStore.swift"
    "${SCRIPT_DIR}/Sources/Store/PromptStore.swift"
    "${SCRIPT_DIR}/Sources/Store/SkillStore.swift"
    "${SCRIPT_DIR}/Sources/Store/SettingsStore.swift"
    "${SCRIPT_DIR}/Sources/Services/FeedbackStore.swift"
    "${SCRIPT_DIR}/Sources/Services/ClipboardService.swift"
    "${SCRIPT_DIR}/Sources/Services/TitleBuilder.swift"
    "${SCRIPT_DIR}/Sources/Services/HotKeyManager.swift"
    "${SCRIPT_DIR}/Sources/Services/DeadlineNotificationScheduler.swift"
    "${SCRIPT_DIR}/Sources/Services/SkillScanner.swift"
    "${SCRIPT_DIR}/Sources/App/AppCoordinator.swift"
    "${SCRIPT_DIR}/Sources/Panel/PanelFactory.swift"
    "${SCRIPT_DIR}/Sources/Panel/CalendarPanelPositioning.swift"
    "${SCRIPT_DIR}/Sources/StatusBar/StatusBarController.swift"
    "${SCRIPT_DIR}/Sources/Views/Components/GlassBackground.swift"
    "${SCRIPT_DIR}/Sources/Views/Components/V5ScrollViewPolicy.swift"
    "${SCRIPT_DIR}/Sources/Views/DeadlinePanelView.swift"
    "${SCRIPT_DIR}/Sources/Views/CalendarWorkbenchV2View.swift"
    "${SCRIPT_DIR}/Sources/Views/CalendarWorkbenchV21View.swift"
    "${SCRIPT_DIR}/Sources/Views/CalendarWorkbenchV21CleanView.swift"
    "${SCRIPT_DIR}/Sources/Views/CalendarWorkbenchV5View.swift"
    "${SCRIPT_DIR}/Sources/Views/CalendarWorkbenchV5Sidebar.swift"
    "${SCRIPT_DIR}/Sources/Views/HUDView.swift"
    "${SCRIPT_DIR}/Sources/Views/SearchPanelView.swift"
    "${SCRIPT_DIR}/Sources/Views/SettingsView.swift"
)

# ── Compile ──
swiftc -parse-as-library \
    -target "$TARGET" \
    -sdk "$SDK_PATH" \
    -module-cache-path "$MODULE_CACHE_DIR" \
    -framework SwiftUI -framework AppKit -framework ServiceManagement -framework Carbon \
    -framework UserNotifications \
    -O -whole-module-optimization \
    -o "${MACOS_DIR}/${APP_NAME}" \
    "${SOURCES[@]}"

# ── Ad-hoc code signing ──
codesign --force --deep --sign - "$APP_DIR"

echo "✅ Build complete!"
echo "   ${APP_DIR}"
echo ""
echo "Run:  open '${APP_DIR}'"

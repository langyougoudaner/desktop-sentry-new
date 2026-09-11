#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PREVIEW_DIR="/private/tmp/DesktopSentryManagedPreview"
MODULE_CACHE_DIR="/private/tmp/DesktopSentryManagedCache"
EXECUTABLE="${PREVIEW_DIR}/DesktopSentry.app/Contents/MacOS/DesktopSentry"

# A fixed preview path means every review replaces the previous disposable
# preview instead of leaving a new 177 MB app/cache pair behind.
while IFS= read -r pid; do
    [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
done < <(pgrep -f "$EXECUTABLE" || true)

DESKTOP_SENTRY_BUILD_DIR="$PREVIEW_DIR" \
DESKTOP_SENTRY_MODULE_CACHE_DIR="$MODULE_CACHE_DIR" \
"${SCRIPT_DIR}/build.sh"

if [[ "${1:-}" == "--open" ]]; then
    open -n "${PREVIEW_DIR}/DesktopSentry.app" \
        --args --calendar-workbench-v5-preview --calendar-workbench-v5-long-list
fi

echo "Managed calendar preview: ${PREVIEW_DIR}/DesktopSentry.app"

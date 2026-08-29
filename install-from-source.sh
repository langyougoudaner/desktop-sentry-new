#!/bin/bash
set -euo pipefail

APP_NAME="DesktopSentry"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${DESKTOP_SENTRY_INSTALL_DIR:-${HOME}/Applications}"
DESTINATION="${INSTALL_DIR}/${APP_NAME}.app"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Desktop Sentry requires macOS 14 or later." >&2
    exit 1
fi

if ! command -v swiftc >/dev/null 2>&1; then
    echo "Missing Xcode Command Line Tools. Run: xcode-select --install" >&2
    exit 1
fi

if [[ -e "$DESTINATION" ]]; then
    echo "Refusing to replace an existing app: $DESTINATION" >&2
    echo "Move the existing app aside or choose another DESKTOP_SENTRY_INSTALL_DIR." >&2
    exit 1
fi

bash "${PROJECT_DIR}/build.sh"
mkdir -p "$INSTALL_DIR"
ditto "${PROJECT_DIR}/build/${APP_NAME}.app" "$DESTINATION"
codesign --verify --deep --strict "$DESTINATION"

echo "Installed Desktop Sentry at: $DESTINATION"
if [[ "${DESKTOP_SENTRY_SKIP_OPEN:-0}" != "1" ]]; then
    open "$DESTINATION"
fi

#!/usr/bin/env bash
# Build Claude Usage.app and install it to /Applications.
#
# Signs with the Apple Development identity of the team in project.yml. A stable
# identity is what keeps the widget registered across rebuilds.
#
#   ./build.sh            build, install and launch
#   ./build.sh --no-install   build only; the app is left in .build-xcode
#
set -euo pipefail
cd "$(dirname "$0")"

command -v xcodegen >/dev/null || {
    echo "xcodegen is required:  brew install xcodegen" >&2
    exit 1
}

DERIVED=".build-xcode"
APP="$DERIVED/Build/Products/Release/Claude Usage.app"

VERSION_SETTINGS=$(scripts/version.sh)

xcodegen generate
xcodebuild build \
    -project ClaudeUsage.xcodeproj \
    -scheme ClaudeUsage \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    $VERSION_SETTINGS

echo
codesign --verify --deep --strict "$APP" && echo "Signature OK: $APP"
echo "Version: ${VERSION_SETTINGS:-from project.yml}"

[[ "${1:-}" == "--no-install" ]] && exit 0

# Must not be running, or the copy replaces a live bundle.
osascript -e 'quit app "Claude Usage"' 2>/dev/null || true
rm -rf "/Applications/Claude Usage.app"
cp -R "$APP" /Applications/

echo
echo "Installed /Applications/Claude Usage.app"
open "/Applications/Claude Usage.app"

sleep 3
echo
echo "Widget registration:"
pluginkit -m -p com.apple.widgetkit-extension 2>/dev/null | grep -i "se.frodlund.claude-usage.widget" \
    || echo "  Not registered yet. Open the widget gallery once; macOS registers on demand."

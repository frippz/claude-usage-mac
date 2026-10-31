#!/bin/sh
# Prints the xcodebuild settings that stamp the version, for build.sh and CI:
# the latest vX.Y.Z tag, with git describe's suffix on builds past it
# (0.2.0-3-gabc1234), and the commit count as the build number. Prints
# nothing outside a Git checkout, such as a release's source zip, which
# leaves project.yml's 0.0.0.
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
version=$(git describe --tags --match 'v[0-9]*.[0-9]*.[0-9]*' --dirty 2>/dev/null) \
  || version=0.0.0-$(git describe --always --dirty)
echo "MARKETING_VERSION=${version#v} CURRENT_PROJECT_VERSION=$(git rev-list --count HEAD)"

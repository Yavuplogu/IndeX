#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
build_dir=$(mktemp -d /tmp/index-private-moves.XXXXXX)
trap 'rm -rf "$build_dir"' EXIT
javac -encoding UTF-8 -d "$build_dir" \
  apps/index_windows/android/app/src/main/java/fr/index/app/PrivateFileMoves.java \
  tools/lot6/java/PrivateFileMovesTest.java
java -cp "$build_dir" fr.index.app.PrivateFileMovesTest

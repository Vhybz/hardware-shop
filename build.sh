#!/usr/bin/env bash
set -e

echo "=== Setting up Git Safe Directory ==="
git config --global --add safe.directory "*"

if [ ! -d "flutter" ]; then
  echo "=== Cloning Flutter SDK (stable) ==="
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter
fi

export PATH="$PATH:$(pwd)/flutter/bin"

echo "=== Flutter SDK Version ==="
flutter --version

echo "=== Installing Dependencies ==="
flutter pub get

echo "=== Building Flutter Web (Release) ==="
flutter build web --release --no-tree-shake-icons

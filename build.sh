#!/bin/bash
set -e

echo "=== Git Safe Directory ==="
git config --global --add safe.directory "*"

if [ ! -d "flutter" ]; then
  echo "=== Cloning Flutter SDK ==="
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 flutter
fi

export PATH="$PATH:$(pwd)/flutter/bin"

echo "=== Flutter SDK Version ==="
flutter --version

echo "=== Resolving Dependencies ==="
rm -f pubspec.lock
flutter pub get

echo "=== Building Flutter Web ==="
flutter build web --release --no-tree-shake-icons

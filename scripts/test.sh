#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
mkdir -p build/module-cache
xcrun swiftc -swift-version 5 -module-cache-path "$PROJECT_DIR/build/module-cache" Sources/KeyAtlas/Models.swift Sources/KeyAtlas/SystemReader.swift Sources/KeyAtlas/AppReader.swift Sources/KeyAtlas/AppAccess.swift Sources/KeyAtlas/SettingsReader.swift Tests/main.swift -o build/keyatlas-tests -framework AppKit
build/keyatlas-tests
xcrun swiftc -swift-version 5 -module-cache-path "$PROJECT_DIR/build/module-cache" Sources/KeyAtlas/Models.swift Sources/KeyAtlas/SystemReader.swift Sources/KeyAtlas/AppReader.swift Sources/KeyAtlas/AppAccess.swift Sources/KeyAtlas/SettingsReader.swift Sources/KeyAtlas/MenuReader.swift Sources/KeyAtlas/Store.swift Tests/StoreTests.swift -o build/keyatlas-store-tests -framework SwiftUI -framework AppKit
build/keyatlas-store-tests

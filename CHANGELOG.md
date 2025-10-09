## Unreleased

- Added version detection warnings for hot reload on Flutter stable ≤ 3.37.0
  - Updated `/debug-app`, `/create-app`, and `/modify` commands to warn users about hot reload limitations
  - Provides guidance to switch to Flutter main channel or manually restart apps when hot reload fails
  - Related to [#15](https://github.com/gemini-cli-extensions/flutter/issues/15)

## 0.3.0

- Removed the `flutter_launcher` MCP server because it has been integrated into
  the Dart MCP server in [dart-lang/ai#292](https://github.com/dart-lang/ai/pull/292)

## 0.2.2

- Fixes the executable path for the flutter_launcher MCP server.

## 0.2.1

- Bumping version number to match the release.

## 0.2.0

- Added the `flutter_launcher_mcp` package, an MCP server installed with the
  extension that allows launching and controlling Flutter apps.

## 0.1.0

- Initial version of the package.

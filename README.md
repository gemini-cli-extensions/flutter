# Flutter extension for Gemini CLI

Help Gemini CLI create, build, test, and run Flutter apps.

- **Status: Experimental** - This is an experimental project. Features and commands may change drastically. We welcome your feedback!

## ✨ Features

- **🚀 Project Bootstrapping**: Create new Flutter projects from scratch with built-in best practices, including linters, documentation, and design planning.
- **🔧 Guided Modifications**: Execute complex modification tasks with automated planning, git branch management, and step-by-step implementation guides for your approval.
- **✅ Automated Pre-Commit Checks**: Automatically format, analyze, and test your code before committing to maintain codebase quality.
- **✍️ Smart Commit Messaging**: Generate descriptive, conventional commit messages based on your staged changes.
- **🧠 Context Priming**: Initializes Gemini with specific rules and context for Dart and Flutter, ensuring high-quality, idiomatic code generation.

## 📋 Prerequisites

1.  **Gemini CLI 0.4.0+** installed and configured.
2.  **Flutter & Dart SDK** installed on your system.
3.  **Git** installed and available in your PATH.

## 🚀 Installation

### 1. Install from GitHub

Use the `gemini extensions install` terminal command to install directly from the source repository:

```bash
gemini extensions install https://github.com/gemini-cli-extensions/flutter.git --auto-update
```

The `--auto-update` is optional: if specified, it will update to new versions as they are released.

You can manage the extension with the following commands:

- Update to the latest version.

  ```bash
  gemini extensions update flutter
  ```

- Uninstall the extension.

  ```bash
  gemini extensions uninstall flutter
  ```

**Note for Windows users:** There is currently a [known issue](https://github.com/google-gemini/gemini-cli/issues/10616) with installing extensions on Gemini CLI for Windows. The workaround is as follows:

1. Follow instructions above to attempt to install the plugin (this will fail).

   ```bash
       gemini extensions install https://github.com/gemini-cli-extensions/flutter.git
   ```

2. In the command line, navigate to the folder in the home user's path where the code was downloaded (USER is the user's username)

   ```bash
       cd %TEMP%
   ```

3. Locate the folder for the downloaded extension. It will be the latest titled `gemini-extension<hash>` where `<hash>` is a 6 character string. Change into this directory.

   ```bash
       cd gemini-extension123456
   ```

4. There should be a zip file in this folder called "win32.flutter.zip". Unpack this file using `tar` (available in modern Windows versions) or by right-clicking it in File Explorer and selecting "Extract All...".

   ```bash
       tar xvf win32.flutter.zip
   ```

5. Use the path flag to gemini installation

   ```bash
       gemini extensions install --path %TEMP%\gemini-extension123456
   ```

### 2. Available Commands

The new commands will be available in new Gemini CLI sessions. The following commands will be available (with or without the `flutter:` prefix):

- `/create-app` - Guides you through bootstrapping a new Flutter project with best practices.
- `/create-package` - Guides you through bootstrapping a new Dart package with best practices.
- `/modify` - Manages a structured modification session with automated planning.
- `/commit` - Automates pre-commit checks and generates a descriptive commit message.

## 💡 Usage

This extension provides powerful commands to automate key phases of the development lifecycle.

### `/create-app`

Initiates a guided process to bootstrap a new Flutter application, ensuring your project starts with a solid foundation.

**Process:**

1.  Asks for the package's purpose, details, and desired location on your filesystem.
2.  Creates a new Flutter project with recommended settings and linter rules.
3.  Generates starter `pubspec.yaml`, `README.md`, and `CHANGELOG.md` files.
4.  Produces a `DESIGN.md` and `IMPLEMENTATION.md` for your review and approval before any code is written.

```bash
/create-app I want to create a trip planning app
```

### `/modify`

Starts a structured session to modify existing code. It helps you plan and execute changes safely and efficiently.

**Process:**

1.  Asks for your high-level modification goals and what you want to accomplish.
2.  Offers to create a new `git` branch for the modification work, isolating changes.
3.  Generates a `MODIFICATION_DESIGN.md` design document detailing the proposed changes.
4.  Creates a phased `MODIFICATION_IMPLEMENTATION.md` plan for your review and approval.

```bash
/modify
```

### `/commit`

Prepares your staged `git` changes for a clean, high-quality commit. It acts as an automated pre-commit hook and message generator.

**Process:**

1.  Runs `dart fix` and `dart format` to clean and format your code.
2.  Executes the Dart analyzer to check for static analysis issues.
3.  Runs your project's test suite to ensure all tests are passing.
4.  Generates a descriptive commit message based on the staged changes for you to review, edit, and approve.

```bash
/commit
```

## ⚙️ Coding Guidelines

This extension enforces a specific set of coding standards to ensure consistency and quality. These rules are defined in the extension's repository:

- **`flutter.md`**: Contains rules and best practices for writing Dart and Flutter code. These rules are opinionated, and we encourage you to review them to ensure they align with your style.

## Connecting to a running app

You can connect to an app by providing the Flutter extension with the URL for
the Dart Tooling Daemon:

1. **Run the app**: in VSCode on a target device (iOS, Android, macOS, or web)
2. **Execute the Copy DTD Uri action**: Open the VSCode Command Runner
   (Cmd+Shift+P, or Ctrl+Shift+P) and type "Copy DTD Uri to Clipboard" to copy the
   DTD URL to your clipboard
3. **Paste the URL into Gemini CLI**: Enter a prompt like "Connect to the
   Flutter app with this DTD URL: " and paste the URL from your clipboard. You
   should see a "Connection succeeded" message from the
   connect_dart_tooling_daemon MCP tool.

Alternatively, you can run from the command line with the `--print-dtd` flag:

```bash
$ flutter run --print-dtd
...
The Dart Tooling Daemon is available at: ws://127.0.0.1:52636/M3G9d1Q3hFk=
```

To learn more about the Dart and Flutter MCP server, see the
[Dart and Flutter MCP server](https://dart.dev/tools/mcp-server)
page on dart.dev or the
[dart_mcp_server README](https://github.com/dart-lang/ai/tree/main/pkgs/dart_mcp_server).

## Known issues

- Running a Flutter app from within Gemini CLI and then triggering a Hot Reload
  does not work in Flutter stable <= 3.37.0.
  Tracking issue: [gemini-cli-extensions/flutter#15](https://github.com/gemini-cli-extensions/flutter/issues/15)

## 🐛 Troubleshooting

### Common Issues

1.  **"Command not recognized"**: Ensure the extension is installed correctly and you have restarted the Gemini CLI. Verify the installation with `gemini extensions list`.

2.  **"Gemini CLI version error"**: This extension requires Gemini CLI version 0.4.0 or greater. Check your version with `gemini --version` and update if necessary.

3.  **"[WARN] Skipping extension MCP config for server with key "dart" as it already exists."**:
    This warning appears if you have manually configured the Dart MCP server in your `.gemini/settings.json` file.
    Since this extension manages the Dart MCP server, you can safely remove your manual configuration to resolve the warning.

### Filing Issues

If you have feedback, suggestions, or run into issues, please [file an issue on GitHub](https://github.com/gemini-cli-extensions/flutter/issues/new/choose).

## 🤝 Contributing

Contributions are welcome! Please see our [CONTRIBUTING.md](CONTRIBUTING.md) guide for more details on how to get started.

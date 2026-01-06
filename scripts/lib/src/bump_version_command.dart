// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'utils.dart';

/// A command that updates the extension version.
///
/// This command:
/// 1. Updates the "version" field in `gemini-extension.json`.
/// 2. Prepends a new version section to `CHANGELOG.md`.
class BumpVersionCommand {
  /// The script execution context.
  final ScriptContext context;

  /// The new version string (e.g., "1.0.1").
  final String newVersion;

  /// Creates a [BumpVersionCommand] with the given [context] and [newVersion].
  BumpVersionCommand(this.context, this.newVersion);

  /// Executes the version bump process.
  Future<void> run() async {
    if (newVersion.isEmpty) {
      throw ExitException('Usage: bump_version <new_version>');
    }

    final repoRoot = findRepoRoot(context);
    final repoPath = repoRoot.path;

    _updateExtensionJson(repoPath);
    _updateChangelog(repoPath);

    context.stdout.writeln('Version bumped to $newVersion');
  }

  void _updateExtensionJson(String repoPath) {
    final fs = context.fs;
    final jsonFile = fs.file(fs.path.join(repoPath, 'gemini-extension.json'));

    if (!jsonFile.existsSync()) {
      throw ExitException(
        'gemini-extension.json not found at ${jsonFile.path}',
      );
    }

    final String content = jsonFile.readAsStringSync();
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(content) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw ExitException(
        'Failed to parse gemini-extension.json: ${e.message}',
      );
    }

    if (!json.containsKey('version')) {
      throw ExitException(
        'Could not find "version" field in gemini-extension.json',
      );
    }

    json['version'] = newVersion;

    // Use an encoder with indentation for readability and add a trailing newline.
    const encoder = JsonEncoder.withIndent('  ');
    jsonFile.writeAsStringSync('${encoder.convert(json)}\n');
  }

  void _updateChangelog(String repoPath) {
    final fs = context.fs;
    final changelogFile = fs.file(fs.path.join(repoPath, 'CHANGELOG.md'));

    if (!changelogFile.existsSync()) {
      print('Warning: CHANGELOG.md not found.');
      return;
    }

    final changelogContent = changelogFile.readAsStringSync();
    if (changelogContent.contains('## $newVersion')) {
      // Version already exists, no need to add again.
      return;
    }

    print('Adding version $newVersion to CHANGELOG.md');

    final newSection =
        '## $newVersion\n\n- TODO: Describe the changes in this version.\n\n';

    int insertIndex = 0;

    // Strategy:
    // 1. Insert before the first `## Version` header.
    // 2. If no version headers, prepend to file.
    final firstHeaderMatch = RegExp(
      r'^##\s',
      multiLine: true,
    ).firstMatch(changelogContent);

    if (firstHeaderMatch != null) {
      insertIndex = firstHeaderMatch.start;
      changelogFile.writeAsStringSync(
        changelogContent.substring(0, insertIndex) +
            newSection +
            changelogContent.substring(insertIndex),
      );
    } else {
      // No existing version headers, so prepend to the file.
      changelogFile.writeAsStringSync(newSection + changelogContent);
    }
  }
}

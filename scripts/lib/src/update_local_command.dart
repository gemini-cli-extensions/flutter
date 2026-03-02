// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'build_release_command.dart';
import 'utils.dart';

/// A command that updates the local installation of the extension.
///
/// This command:
/// 1. Builds the release archive using [BuildReleaseCommand].
/// 2. Clears the local installation directory at `~/.gemini/extensions/flutter`.
/// 3. Extracts the new archive into the installation directory.
class UpdateLocalCommand {
  /// The script execution context.
  final ScriptContext context;

  /// Creates an [UpdateLocalCommand] with the given [context].
  UpdateLocalCommand(this.context);

  /// Executes the update process.
  Future<void> run() async {
    // 1. Build release
    print('Building the release...');
    final archivePath = await BuildReleaseCommand(context).run();

    final fs = context.fs;
    final platform = context.platform;

    // 2. Clear and install
    final home = platform.environment['HOME'] ?? platform.environment['USERPROFILE'];
    if (home == null || home.isEmpty) {
      throw ExitException(
          'Could not determine home directory. Please set HOME or USERPROFILE.');
    }
    final installDir = fs.path.join(
      home,
      '.gemini',
      'extensions',
      'flutter',
    );

    print('Clearing the installation directory ($installDir)...');

    final installDirectory = fs.directory(installDir);
    if (installDirectory.existsSync()) {
      installDirectory.deleteSync(recursive: true);
    }
    installDirectory.createSync(recursive: true);

    // 3. Extract
    print('Extracting the archive...');

    if (!fs.isFileSync(archivePath)) {
      throw ExitException('Archive not found at $archivePath after build.');
    }

    if (platform.isWindows) {
      await runProcess(context, [
        'powershell',
        '-command',
        'Expand-Archive -Path "$archivePath" -DestinationPath "$installDir" -Force'
      ]);
    } else {
      await runProcess(context, ['tar', '-xzf', archivePath, '-C', installDir]);
    }

    context.stdout.writeln('Installation complete.');
  }
}

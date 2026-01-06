import 'package:file/file.dart';

import 'utils.dart';

/// A command that builds a release archive for the Flutter extension.
///
/// This command:
/// 1. Detects the current OS and architecture (or uses GITHUB_MATRIX_OS if set).
/// 2. Identifies the repository root.
/// 3. Creates a `.tar.gz` (Linux/macOS) or `.zip` (Windows) archive of the
///    extension source.
/// 4. Sets the `ARCHIVE_NAME` environment variable for GitHub Actions.
class BuildReleaseCommand {
  /// The script execution context.
  final ScriptContext context;

  /// Creates a [BuildReleaseCommand] with the given [context].
  BuildReleaseCommand(this.context);

  /// Executes the build release process.
  ///
  /// Returns the path to the created archive.
  Future<String> run() async {
    final fs = context.fs;
    final platform = context.platform;

    final platformInfo = await getPlatformInfo(context);
    final os = platformInfo.os;
    final arch = platformInfo.arch;
    final ext = platformInfo.ext;

    final archiveName = '$os.$arch.flutter.$ext';

    // Find the repository root by looking for 'gemini-extension.json'.
    final repoRoot = findRepoRoot(context);
    final repoPath = repoRoot.path;
    print('Repository root: $repoPath');

    String tagName = (platform.environment['GITHUB_REF'] ?? 'refs/tags/HEAD');
    if (tagName.startsWith('refs/tags/')) {
      tagName = tagName.substring('refs/tags/'.length);
    }
    if (tagName.isEmpty) tagName = 'HEAD';

    if (fs.isFileSync(fs.path.join(repoPath, archiveName))) {
      fs.file(fs.path.join(repoPath, archiveName)).deleteSync();
    }

    print('Creating archive $archiveName from $tagName...');

    final filesToArchive = [
      'gemini-extension.json',
      'commands/',
      'LICENSE',
      'README.md',
      'flutter.md',
    ];

    if (os == 'windows') {
      await runProcess(context,
          [
            'git',
            'archive',
            '--format=zip',
            '-o',
            archiveName,
            tagName,
            ...filesToArchive
          ],
          workingDirectory: repoPath);
    } else {
      final tarName = '$os.$arch.flutter.tar';
      await runProcess(context,
          [
            'git',
            'archive',
            '--format=tar',
            '-o',
            tarName,
            tagName,
            ...filesToArchive
          ],
          workingDirectory: repoPath);

      await runProcess(context, [
        'gzip',
        '--force',
        tarName,
      ], workingDirectory: repoPath);
    }

    // Set output env var for GitHub Actions.
    final githubEnv = platform.environment['GITHUB_ENV'];
    if (githubEnv != null && fs.isFileSync(githubEnv)) {
      fs.file(githubEnv).writeAsStringSync('ARCHIVE_NAME=$archiveName\n',
          mode: FileMode.append);
    } else {
      context.stdout.writeln('Archive written to $archiveName');
    }

    return fs.path.join(repoPath, archiveName);
  }
}

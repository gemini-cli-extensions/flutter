// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Shared utilities for the Flutter extension scripts.
///
/// This library provides a standard [ScriptContext] for dependency injection
/// and a [runScript] runner for consistent error handling.
library;

import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:platform/platform.dart';
import 'package:process/process.dart';

/// An exception that indicates a controlled exit with a specific message and code.
///
/// This exception is caught by [runScript] to exit the process gracefully
/// without printing a stack trace.
class ExitException implements Exception {
  /// The error message to display to the user.
  final String message;

  /// The exit code to return to the shell (default is 1).
  final int exitCode;

  /// Creates a new [ExitException] with the given [message] and optional [exitCode].
  ExitException(this.message, {this.exitCode = 1});

  @override
  String toString() => message;
}

/// Provides the runtime context (filesystem, platform, process manager) for scripts.
///
/// This class enables dependency injection for easier testing by allowing
/// mock implementations of [FileSystem], [Platform], and [ProcessManager] to be
/// passed in.
class ScriptContext {
  /// The file system interface.
  final FileSystem fs;

  /// The platform interface (for environment variables, OS detection, etc.).
  final Platform platform;

  /// The process manager for spawning subprocesses.
  final ProcessManager pm;

  /// Creates a new [ScriptContext].
  ///
  /// Dependencies default to their local implementations ([LocalFileSystem],
  /// [LocalPlatform], [LocalProcessManager]) if not provided.
  ScriptContext({
    FileSystem? fs,
    Platform? platform,
    ProcessManager? pm,
  })  : fs = fs ?? const LocalFileSystem(),
        platform = platform ?? const LocalPlatform(),
        pm = pm ?? const LocalProcessManager();
}

/// Runs the [callback] with the given [context], handling [ExitException]s.
///
/// If the [callback] throws an [ExitException], this function prints the
/// exception's message to stderr and exits the process with the specified
/// exit code. Unexpected exceptions print the error and stack trace and exit
/// with code 1.
Future<void> runScript(
  Future<void> Function(ScriptContext context) callback, {
  ScriptContext? context,
}) async {
  try {
    await callback(context ?? ScriptContext());
  } on ExitException catch (e) {
    if (e.message.isNotEmpty) {
      io.stderr.writeln(e.message);
    }
    io.exit(e.exitCode);
  } catch (e, stack) {
    io.stderr.writeln('Unexpected error: $e\n$stack');
    io.exit(1);
  }
}

/// Finds the repository root by looking for `gemini-extension.json`.
///
/// Throws an [ExitException] if the repository root cannot be found.
Directory findRepoRoot(ScriptContext context) {
  final fs = context.fs;
  Directory? repoRoot = fs.currentDirectory;

  while (repoRoot != null) {
    if (fs.isFileSync(fs.path.join(repoRoot.path, 'gemini-extension.json'))) {
      return repoRoot;
    }
    if (repoRoot.path == repoRoot.parent.path) {
      break;
    }
    repoRoot = repoRoot.parent;
  }

  throw ExitException(
    'Could not find repository root (looked for gemini-extension.json)',
  );
}

/// Information about the platform and the archive extension.
typedef PlatformInfo = ({String os, String arch, String ext});

/// Determines the target platform information.
///
/// Checks `GITHUB_MATRIX_OS` first, then falls back to the current platform.
Future<PlatformInfo> getPlatformInfo(ScriptContext context) async {
  final platform = context.platform;

  String os;
  String arch;

  final githubMatrixOs = platform.environment['GITHUB_MATRIX_OS'];
  if (githubMatrixOs != null && githubMatrixOs.isNotEmpty) {
    if (githubMatrixOs.startsWith('macos')) {
      os = 'darwin';
    } else if (githubMatrixOs.startsWith('windows')) {
      os = 'windows';
    } else if (githubMatrixOs.startsWith('ubuntu')) {
      os = 'linux';
    } else {
      throw ExitException('Unknown GITHUB_MATRIX_OS: $githubMatrixOs');
    }

    if (os == 'windows') {
      arch = platform.environment['RUNNER_ARCH']?.toLowerCase() ?? 'x64';
    } else {
      var runnerArch = platform.environment['RUNNER_ARCH'];
      if (runnerArch != null && runnerArch.isNotEmpty) {
        arch = runnerArch.toLowerCase();
      } else {
        var unameM = await captureProcessOutput(context, ['uname', '-m']);
        arch = unameM.trim().toLowerCase();
      }
    }
  } else {
    os = platform.operatingSystem;
    if (os == 'macos') {
      os = 'darwin';
    }

    if (os == 'darwin' || os == 'linux') {
      var unameM = await captureProcessOutput(context, ['uname', '-m']);
      arch = unameM.trim().toLowerCase();
    } else if (os == 'windows') {
      arch = 'x64';
    } else {
      throw ExitException('Unknown OS: $os');
    }
  }

  final ext = os == 'windows' ? 'zip' : 'tar.gz';
  return (os: os, arch: arch, ext: ext);
}

/// Runs a command and streams its output to stdout/stderr.
Future<void> runProcess(
  ScriptContext context,
  List<String> command, {
  String? workingDirectory,
}) async {
  final pm = context.pm;
  final process = await pm.start(command, workingDirectory: workingDirectory);

  // We use io.stdout/stderr because we want to print to the real terminal
  // even if 'context.fs' is mocked?
  // Wait, `utils.dart` imports `dart:io` as `io`.
  // If we want to be testable we might need a `Logger` in context, but for now strict IO is what was there.

  process.stdout.transform(io.systemEncoding.decoder).listen(io.stdout.write);
  process.stderr.transform(io.systemEncoding.decoder).listen(io.stderr.write);

  final exitCode = await process.exitCode;
  if (exitCode != 0) {
    throw ExitException(
      'Command failed with exit code $exitCode: ${command.join(" ")}',
    );
  }
}

/// Runs a command and returns its stdout trimmed.
Future<String> captureProcessOutput(
  ScriptContext context,
  List<String> command, {
  String? workingDirectory,
}) async {
  final result = await context.pm.run(
    command,
    workingDirectory: workingDirectory,
  );
  if (result.exitCode != 0) {
    throw ExitException(
      'Command failed: ${command.join(" ")}\nStderr: ${result.stderr}',
    );
  }
  return (result.stdout as String).trim();
}

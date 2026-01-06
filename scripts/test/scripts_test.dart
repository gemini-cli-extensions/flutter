// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:platform/platform.dart';
import 'package:process/process.dart';
import 'package:release_scripts/src/build_release_command.dart';
import 'package:release_scripts/src/bump_version_command.dart';
import 'package:release_scripts/src/update_local_command.dart';
import 'package:release_scripts/src/utils.dart';
import 'package:test/test.dart';

void main() {
  group('BuildReleaseCommand', () {
    late BuildReleaseCommand command;
    late MockProcessManager pm;
    late MemoryFileSystem fs;
    late FakePlatform platform;
    late FakeIOSink stdout;
    late FakeIOSink stderr;

    setUp(() {
      fs = MemoryFileSystem(style: FileSystemStyle.posix);
      pm = MockProcessManager(fs: fs);
      platform = FakePlatform(
        operatingSystem: 'linux',
        environment: {'HOME': '/home/user'},
      );
      stdout = FakeIOSink();
      stderr = FakeIOSink();
      final context = ScriptContext(
        fs: fs,
        pm: pm,
        platform: platform,
        stdout: stdout,
        stderr: stderr,
      );
      command = BuildReleaseCommand(context);

      // Setup repo root
      fs.directory('/repo').createSync();
      fs.file('/repo/gemini-extension.json').createSync();
      fs.currentDirectory = '/repo';
    });

    test('builds release archive successfully', () async {
      final archivePath = await command.run();

      expect(archivePath, '/repo/linux.arm64.flutter.tar.gz');
      expect(
        stdout.toString(),
        contains('Archive written to linux.arm64.flutter.tar.gz'),
      );

      expect(
        pm.executedCommands,
        containsAll([
          'git archive --format=tar -o linux.arm64.flutter.tar HEAD gemini-extension.json commands/ LICENSE README.md flutter.md',
          'gzip --force linux.arm64.flutter.tar',
        ]),
      );
    });

    test('parses tagName from GITHUB_REF', () async {
      platform.environment['GITHUB_REF'] = 'refs/tags/v1.2.3';

      final archivePath = await command.run();

      expect(archivePath, '/repo/linux.arm64.flutter.tar.gz');
      // Verify correct tag was used in git archive command
      expect(
        pm.executedCommands.any(
          (cmd) =>
              cmd.contains('git archive') &&
              cmd.contains('v1.2.3') &&
              !cmd.contains('--prefix'),
        ),
        isTrue,
        reason: 'Should use tag name v1.2.3 from GITHUB_REF without prefix',
      );
    });

    test('detects architecture dynamically on Linux (arm64)', () async {
      // Mock uname -m response handled in MockProcessManager

      final archivePath = await command.run();

      expect(archivePath, '/repo/linux.arm64.flutter.tar.gz');
      expect(pm.executedCommands, contains('uname -m'));
    });

    test('builds release with RUNNER_ARCH env var', () async {
      platform.environment['GITHUB_MATRIX_OS'] = 'ubuntu-latest';
      platform.environment['RUNNER_ARCH'] = 'ARM64';

      final archivePath = await command.run();

      expect(archivePath, '/repo/linux.arm64.flutter.tar.gz');
    });

    test('builds release archive successfully on Windows', () async {
      // Re-initialize for Windows
      fs = MemoryFileSystem(style: FileSystemStyle.windows);
      pm = MockProcessManager(fs: fs);
      platform = FakePlatform(
        operatingSystem: 'windows',
        environment: {'USERPROFILE': r'C:\Users\user'},
      );
      stdout = FakeIOSink();
      stderr = FakeIOSink();

      // Setup repo
      fs.directory(r'C:\repo').createSync(recursive: true);
      fs.file(r'C:\repo\gemini-extension.json').createSync();
      fs.currentDirectory = r'C:\repo';

      final context = ScriptContext(
        fs: fs,
        pm: pm,
        platform: platform,
        stdout: stdout,
        stderr: stderr,
      );
      command = BuildReleaseCommand(context);

      final archivePath = await command.run();

      expect(archivePath, r'C:\repo\windows.x64.flutter.zip');
      expect(
        pm.executedCommands,
        containsAll([
          'git archive --format=zip -o windows.x64.flutter.zip HEAD gemini-extension.json commands/ LICENSE README.md flutter.md',
        ]),
      );
    });
  });

  group('BumpVersionCommand', () {
    late BumpVersionCommand command;
    late MockProcessManager pm;
    late MemoryFileSystem fs;
    late FakePlatform platform;
    late FakeIOSink stdout;
    late FakeIOSink stderr;

    setUp(() {
      fs = MemoryFileSystem();
      pm = MockProcessManager();
      platform = FakePlatform();
      stdout = FakeIOSink();
      stderr = FakeIOSink();
      final context = ScriptContext(
        fs: fs,
        pm: pm,
        platform: platform,
        stdout: stdout,
        stderr: stderr,
      );
      command = BumpVersionCommand(context, '1.0.1');

      // Setup repo and files
      fs.directory('/repo').createSync();
      fs
          .file('/repo/gemini-extension.json')
          .writeAsStringSync('{"version": "1.0.0"}');
      fs
          .file('/repo/CHANGELOG.md')
          .writeAsStringSync('# Changelog\n\n## 1.0.0\n\nNotes');
      fs.currentDirectory = '/repo';
    });

    test('updates version in files', () async {
      await command.run();

      final jsonContent = json.decode(
        fs.file('/repo/gemini-extension.json').readAsStringSync(),
      );
      expect(jsonContent['version'], '1.0.1');

      final changelog = fs.file('/repo/CHANGELOG.md').readAsStringSync();
      expect(changelog, contains('## 1.0.1'));
      expect(changelog, contains('TODO: Describe the changes'));

      expect(stdout.toString(), contains('Version bumped to 1.0.1'));
    });
  });

  group('UpdateLocalCommand', () {
    late UpdateLocalCommand command;
    late MockProcessManager pm;
    late MemoryFileSystem fs;
    late FakePlatform platform;
    late FakeIOSink stdout;
    late FakeIOSink stderr;

    setUp(() {
      fs = MemoryFileSystem(style: FileSystemStyle.posix);
      pm = MockProcessManager(fs: fs);
      platform = FakePlatform(
        operatingSystem: 'linux',
        environment: {'HOME': '/home/user'},
      );
      stdout = FakeIOSink();
      stderr = FakeIOSink();
      final context = ScriptContext(
        fs: fs,
        pm: pm,
        platform: platform,
        stdout: stdout,
        stderr: stderr,
      );
      command = UpdateLocalCommand(context);

      fs.directory('/repo').createSync();
      fs.file('/repo/gemini-extension.json').createSync();
      fs.currentDirectory = '/repo';
    });

    test('updates local installation', () async {
      await command.run();

      expect(
        fs.directory('/home/user/.gemini/extensions/flutter').existsSync(),
        isTrue,
      );
      expect(
        pm.executedCommands,
        contains(
          'tar -xzf /repo/linux.arm64.flutter.tar.gz -C /home/user/.gemini/extensions/flutter',
        ),
      );

      expect(stdout.toString(), contains('Installation complete.'));
    });

    test('updates local installation on Windows', () async {
      // Re-initialize for Windows
      fs = MemoryFileSystem(style: FileSystemStyle.windows);
      pm = MockProcessManager(fs: fs);
      platform = FakePlatform(
        operatingSystem: 'windows',
        environment: {'USERPROFILE': r'C:\Users\user'},
      );
      stdout = FakeIOSink();
      stderr = FakeIOSink();

      // Setup repo
      fs.directory(r'C:\repo').createSync(recursive: true);
      fs.file(r'C:\repo\gemini-extension.json').createSync();
      fs.currentDirectory = r'C:\repo';

      final context = ScriptContext(
        fs: fs,
        pm: pm,
        platform: platform,
        stdout: stdout,
        stderr: stderr,
      );
      command = UpdateLocalCommand(context);

      await command.run();

      expect(
        fs.directory(r'C:\Users\user\.gemini\extensions\flutter').existsSync(),
        isTrue,
        reason: 'Installation directory should exist',
      );

      // Check executed commands contain powershell
      expect(
        pm.executedCommands.any(
          (cmd) => cmd.contains('powershell') && cmd.contains('Expand-Archive'),
        ),
        isTrue,
        reason: 'Should use PowerShell Expand-Archive',
      );
    });
  });
}

class FakeIOSink implements IOSink {
  final StringBuffer buffer = StringBuffer();

  @override
  Encoding encoding = systemEncoding;

  @override
  void add(List<int> data) {
    buffer.write(String.fromCharCodes(data));
  }

  @override
  void write(Object? object) {
    buffer.write(object);
  }

  @override
  void writeln([Object? object = ""]) {
    buffer.writeln(object);
  }

  @override
  void writeAll(Iterable objects, [String separator = ""]) {
    buffer.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) {
    buffer.writeCharCode(charCode);
  }

  @override
  Future addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future flush() async {}

  @override
  Future close() async {}

  @override
  Future get done => Future.value();

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  String toString() => buffer.toString();
}

class MockProcessManager implements ProcessManager {
  final List<String> executedCommands = [];
  final FileSystem? fs;

  MockProcessManager({this.fs});

  @override
  Future<Process> start(
    List<dynamic> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    executedCommands.add(command.map((e) => e.toString()).join(' '));
    _handleSideEffects(command, workingDirectory);
    return _MockProcess();
  }

  @override
  Future<ProcessResult> run(
    List<dynamic> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding = systemEncoding,
    Encoding? stderrEncoding = systemEncoding,
  }) async {
    final cmdStr = command.map((e) => e.toString()).join(' ');
    executedCommands.add(cmdStr);
    _handleSideEffects(command, workingDirectory);

    // Return appropriate responses directly based on command content
    if (cmdStr.contains('uname -m')) {
      return ProcessResult(0, 0, 'arm64', '');
    }
    return ProcessResult(0, 0, '', '');
  }

  void _handleSideEffects(List<dynamic> command, String? workingDirectory) {
    if (fs == null) return;

    // Detect git archive -o output_file
    if (command.contains('git') &&
        command.contains('archive') &&
        command.contains('-o')) {
      final outputIndex = command.indexOf('-o');
      if (outputIndex != -1 && outputIndex + 1 < command.length) {
        final outputFile = command[outputIndex + 1] as String;
        final dir = workingDirectory ?? fs!.currentDirectory.path;
        final path = fs!.path.join(dir, outputFile);
        // Create dummy file
        if (fs!.isFileSync(path)) fs!.file(path).deleteSync();
        fs!.file(path).createSync(recursive: true);
      }
    }
    // Handle gzip which replaces .tar with .tar.gz (if we were using gzip command)
    if (command.contains('gzip')) {
      final tarName = command.last as String;
      if (tarName.endsWith('.tar')) {
        final dir = workingDirectory ?? fs!.currentDirectory.path;
        final tarPath = fs!.path.join(dir, tarName);
        final gzPath = '$tarPath.gz';
        if (fs!.isFileSync(tarPath)) {
          fs!.file(gzPath).createSync();
          fs!.file(tarPath).deleteSync();
        }
      }
    }
    // Handle PowerShell Expand-Archive
    if (command.contains('powershell')) {
      dynamic cmdArg;
      for (final element in command) {
        if (element.toString().contains('Expand-Archive')) {
          cmdArg = element;
          break;
        }
      }
      if (cmdArg != null) {
        // Parse destination path roughly
        // Expand-Archive -Path "..." -DestinationPath "..." -Force
        final match = RegExp(
          r'-DestinationPath "([^"]+)"',
        ).firstMatch(cmdArg.toString());
        if (match != null) {
          final destDir = match.group(1)!;
          // Ensure we treat the path as appropriate for the style (Windows)
          // But MockProcessManager.fs style is dynamic.
          // destination path usually passed clean from UpdateLocalCommand.
          if (!fs!.directory(destDir).existsSync()) {
            fs!.directory(destDir).createSync(recursive: true);
          }
        }
      }
    }
  }



  @override
  ProcessResult runSync(
    List<dynamic> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding = systemEncoding,
    Encoding? stderrEncoding = systemEncoding,
  }) {
    final cmdStr = command.map((e) => e.toString()).join(' ');
    executedCommands.add(cmdStr);
    if (cmdStr.contains('uname -m')) {
      return ProcessResult(0, 0, 'arm64', '');
    }
    return ProcessResult(0, 0, '', '');
  }

  @override
  bool canRun(dynamic executable, {String? workingDirectory}) => true;

  @override
  bool killPid(int pid, [ProcessSignal signal = ProcessSignal.sigterm]) => true;
}

class _MockProcess implements Process {
  @override
  Future<int> get exitCode => Future.value(0);

  @override
  Stream<List<int>> get stdout => Stream.empty();

  @override
  Stream<List<int>> get stderr => Stream.empty();

  @override
  IOSink get stdin => IOSink(StreamController());

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;

  @override
  int get pid => 0;
}

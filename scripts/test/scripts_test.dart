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
    executedCommands.add(command.map((e) => e.toString()).join(' '));
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

void main() {
  group('BuildReleaseCommand', () {
    test('builds release on macos', () async {
      final fs = MemoryFileSystem();
      final pm = MockProcessManager(fs: fs);
      final platform = FakePlatform(
        operatingSystem: 'macos',
        environment: {'HOME': '/home/user'},
      );

      // Setup fs
      fs.directory('/repo').createSync();
      fs.currentDirectory = '/repo';
      fs.file('/repo/gemini-extension.json').createSync();

      final context = ScriptContext(fs: fs, pm: pm, platform: platform);

      await BuildReleaseCommand(context).run();

      expect(
        pm.executedCommands,
        contains(
          contains('git archive --format=tar -o darwin.arm64.flutter.tar HEAD'),
        ),
      );
      expect(
        pm.executedCommands,
        contains(contains('gzip --force darwin.arm64.flutter.tar')),
      );
    });

    test('builds release on windows', () async {
      // Use Windows style for MemoryFileSystem
      final fs = MemoryFileSystem(style: FileSystemStyle.windows);
      final pm = MockProcessManager(fs: fs);
      final platform = FakePlatform(
        operatingSystem: 'windows',
        environment: {'USERPROFILE': 'C:\\Users\\User'},
      );

      fs.directory('C:\\repo').createSync(recursive: true);
      fs.currentDirectory = 'C:\\repo';
      fs.file('C:\\repo\\gemini-extension.json').createSync();

      final context = ScriptContext(fs: fs, pm: pm, platform: platform);
      await BuildReleaseCommand(context).run();

      expect(
        pm.executedCommands.any(
          (c) =>
              c.contains('git archive --format=zip') &&
              c.contains('windows.x64.flutter.zip'),
        ),
        isTrue,
      );
    });
  });

  group('BumpVersionCommand', () {
    test('updates version in files', () async {
      final fs = MemoryFileSystem();
      final platform = FakePlatform();

      fs.directory('/repo').createSync();
      fs.currentDirectory = '/repo';
      fs
          .file('/repo/gemini-extension.json')
          .writeAsStringSync('{"version": "1.0.0"}');
      fs
          .file('/repo/CHANGELOG.md')
          .writeAsStringSync('# Changelog\n\n## 1.0.0\n\nNotes');

      final context = ScriptContext(fs: fs, platform: platform);
      await BumpVersionCommand(context, '1.0.1').run();

      expect(
        fs.file('/repo/gemini-extension.json').readAsStringSync(),
        contains('"version": "1.0.1"'),
      );

      final changelogContent = fs.file('/repo/CHANGELOG.md').readAsStringSync();
      expect(
        changelogContent,
        startsWith(
          '# Changelog\n\n## 1.0.1\n\n- TODO: Describe the changes in this version.\n\n## 1.0.0',
        ),
      );
    });
  });

  group('UpdateLocalCommand', () {
    test('updates local installation', () async {
      final fs = MemoryFileSystem();
      final pm = MockProcessManager(fs: fs);
      final platform = FakePlatform(
        operatingSystem: 'linux',
        environment: {'HOME': '/home/user'},
      );

      fs.directory('/repo').createSync();
      fs.currentDirectory = '/repo';
      fs.file('/repo/gemini-extension.json').createSync();

      final context = ScriptContext(fs: fs, pm: pm, platform: platform);
      await UpdateLocalCommand(context).run();

      expect(
        pm.executedCommands,
        contains(
          contains(
            'tar -xzf /repo/linux.x64.flutter.tar.gz -C /home/user/.gemini/extensions/flutter',
          ),
        ),
      );
      expect(
        fs.directory('/home/user/.gemini/extensions/flutter').existsSync(),
        isTrue,
      );
    });
  });
}

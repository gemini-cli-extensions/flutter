// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:file/memory.dart';
import 'package:flutter_launcher_mcp/src/utils/sdk.dart';
import 'package:process/process.dart';
import 'package:test/test.dart' as test;

void main() {
  test.group('Sdk', () {
    late MockProcessManager mockProcessManager;
    late MemoryFileSystem fileSystem;

    test.setUp(() {
      mockProcessManager = MockProcessManager();
      fileSystem = MemoryFileSystem();
    });

    test.test('create returns Sdk with paths when flutter is found', () async {
      mockProcessManager.addCommand(
        Command([
          'flutter',
          '--version',
          '--machine',
        ], stdout: jsonEncode({'flutterRoot': '/path/to/flutter/sdk'})),
      );
      fileSystem
          .file('/path/to/flutter/sdk/bin/cache/dart-sdk/version')
          .createSync(recursive: true);
      final sdk = Sdk();
      await sdk.init(
        processManager: mockProcessManager,
        fileSystem: fileSystem,
      );

      test.expect(sdk.flutterSdkPath, '/path/to/flutter/sdk');
      test.expect(sdk.dartSdkPath, '/path/to/flutter/sdk/bin/cache/dart-sdk');
      test.expect(
        sdk.flutterExecutablePath,
        '/path/to/flutter/sdk/bin/flutter',
      );
      test.expect(
        sdk.dartExecutablePath,
        '/path/to/flutter/sdk/bin/cache/dart-sdk/bin/dart',
      );
    });

    test.test(
      'create returns Sdk with null paths when flutter is not found',
      () async {
        mockProcessManager.addCommand(
          Command([
            'flutter',
            '--version',
            '--machine',
          ], exitCode: Future.value(1)),
        );
        final sdk = Sdk();
        await sdk.init(
          processManager: mockProcessManager,
          fileSystem: fileSystem,
        );

        test.expect(sdk.flutterSdkPath, test.isNull);
        test.expect(sdk.dartSdkPath, test.isNull);
        test.expect(sdk.flutterExecutablePath, test.isNull);
        test.expect(sdk.dartExecutablePath, test.isNull);
      },
    );

    test.test(
      'create returns Sdk with null paths when flutterRoot is missing',
      () async {
        mockProcessManager.addCommand(
          Command([
            'flutter',
            '--version',
            '--machine',
          ], stdout: jsonEncode({'someOtherKey': '/path/to/flutter/sdk'})),
        );
        final sdk = Sdk();
        await sdk.init(
          processManager: mockProcessManager,
          fileSystem: fileSystem,
        );

        test.expect(sdk.flutterSdkPath, test.isNull);
        test.expect(sdk.dartSdkPath, test.isNull);
      },
    );

    test.test(
      'create returns Sdk with null dartSdkPath when version file is missing',
      () async {
        mockProcessManager.addCommand(
          Command([
            'flutter',
            '--version',
            '--machine',
          ], stdout: jsonEncode({'flutterRoot': '/path/to/flutter/sdk'})),
        );
        // Do not create the version file in the mock file system.

        final sdk = Sdk();
        await sdk.init(
          processManager: mockProcessManager,
          fileSystem: fileSystem,
        );

        test.expect(sdk.flutterSdkPath, '/path/to/flutter/sdk');
        test.expect(sdk.dartSdkPath, test.isNull);
      },
    );
  });
}

class Command {
  final List<String> command;
  final String? stdout;
  final String? stderr;
  final Future<int>? exitCode;
  final int pid;

  Command(
    this.command, {
    this.stdout,
    this.stderr,
    this.exitCode,
    this.pid = 12345,
  });
}

class MockProcessManager implements ProcessManager {
  final List<Command> _commands = [];
  final List<List<Object>> commands = [];
  final Map<int, MockProcess> runningProcesses = {};
  bool shouldThrowOnStart = false;
  bool killResult = true;
  final killedPids = <int>[];
  int _pidCounter = 12345;

  void addCommand(Command command) {
    _commands.add(command);
  }

  void completeExitCodeForProcess(int pid, int exitCode) {
    runningProcesses[pid]?.completeExitCode(exitCode);
  }

  Command _findCommand(List<Object> command) {
    for (final cmd in _commands) {
      if (const ListEquality<Object>().equals(cmd.command, command)) {
        return cmd;
      }
    }
    throw Exception('Command not mocked: $command');
  }

  @override
  Future<Process> start(
    List<Object> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) async {
    if (shouldThrowOnStart) {
      throw Exception('Failed to start process');
    }
    commands.add(command);
    final mockCommand = _findCommand(command);
    final pid = mockCommand.pid == 12345 ? _pidCounter++ : mockCommand.pid;
    final process = MockProcess(
      stdout: Stream.value(utf8.encode(mockCommand.stdout ?? '')),
      stderr: Stream.value(utf8.encode(mockCommand.stderr ?? '')),
      pid: pid,
      exitCodeFuture: mockCommand.exitCode,
    );
    runningProcesses[pid] = process;
    return process;
  }

  @override
  bool killPid(int pid, [ProcessSignal signal = ProcessSignal.sigterm]) {
    killedPids.add(pid);
    runningProcesses[pid]?.kill();
    return killResult;
  }

  @override
  Future<ProcessResult> run(
    List<Object> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding = systemEncoding,
    Encoding? stderrEncoding = systemEncoding,
  }) async {
    commands.add(command);
    final mockCommand = _findCommand(command);
    return ProcessResult(
      mockCommand.pid,
      await (mockCommand.exitCode ?? Future.value(0)),
      mockCommand.stdout ?? '',
      mockCommand.stderr ?? '',
    );
  }

  @override
  bool canRun(executable, {String? workingDirectory}) => true;

  @override
  ProcessResult runSync(
    List<Object> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
    Encoding? stdoutEncoding = systemEncoding,
    Encoding? stderrEncoding = systemEncoding,
  }) {
    throw UnimplementedError();
  }
}

class MockProcess implements Process {
  @override
  final Stream<List<int>> stdout;
  @override
  final Stream<List<int>> stderr;
  @override
  final int pid;

  @override
  late final Future<int> exitCode;
  final Completer<int> exitCodeCompleter = Completer<int>();

  bool killed = false;

  @override
  late final IOSink stdin = _MockIOSink();

  MockProcess({
    required this.stdout,
    required this.stderr,
    required this.pid,
    Future<int>? exitCodeFuture,
  }) {
    exitCode = exitCodeFuture ?? exitCodeCompleter.future;
  }

  void completeExitCode(int code) {
    if (!exitCodeCompleter.isCompleted) {
      exitCodeCompleter.complete(code);
    }
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!exitCodeCompleter.isCompleted) {
      exitCodeCompleter.complete(-9); // SIGKILL
    }
    return true;
  }
}

class _MockIOSink implements IOSink {
  final List<String> writtenLines = [];
  bool _closed = false;

  @override
  Encoding encoding = utf8;

  @override
  void add(List<int> data) {
    if (_closed) throw StateError('IOSink is closed');
  }

  @override
  void write(Object? object) {
    if (_closed) throw StateError('IOSink is closed');
  }

  @override
  void writeln([Object? object = '']) {
    if (_closed) throw StateError('IOSink is closed');
    writtenLines.add(object.toString());
  }

  @override
  Future<void> flush() async {
    if (_closed) throw StateError('IOSink is closed');
  }

  @override
  Future<void> close() async {
    _closed = true;
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    throw UnimplementedError();
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    throw UnimplementedError();
  }

  @override
  Future get done => Future.value();

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    throw UnimplementedError();
  }

  @override
  void writeCharCode(int charCode) {
    throw UnimplementedError();
  }
}

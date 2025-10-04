// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:dart_mcp/client.dart';
import 'package:file/memory.dart';
import 'package:flutter_launcher_mcp/src/server.dart';
import 'package:flutter_launcher_mcp/src/utils/sdk.dart';
import 'package:process/process.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart' as test;

import 'sdk_test.dart';

void main() {
  test.group('FlutterLauncherMCPServer', () {
    late MemoryFileSystem fileSystem;

    Future<({FlutterLauncherMCPServer server, ServerConnection client})>
    createServerAndClient({
      required ProcessManager processManager,
      required MemoryFileSystem fileSystem,
    }) async {
      final channel = StreamChannelController<String>();
      final server = FlutterLauncherMCPServer(
        channel.local,
        sdk: Sdk(
          flutterSdkPath: '/path/to/flutter/sdk',
          dartSdkPath: '/path/to/flutter/sdk/bin/cache/dart-sdk',
        ),
        processManager: processManager,
        fileSystem: fileSystem,
      );
      final client = ServerConnection.fromStreamChannel(channel.foreign);
      return (server: server, client: client);
    }

    test.setUp(() {
      fileSystem = MemoryFileSystem();
    });

    test.test('launch_app tool returns DTD URI and PID on success', () async {
      final dtdUri = 'ws://127.0.0.1:12345/abcdefg=';
      final processPid = 54321;
      final mockProcessManager = MockProcessManager();
      mockProcessManager.addCommand(
        Command(
          [
            '/path/to/flutter/sdk/bin/flutter',
            'run',
            '--print-dtd',
            '--device-id',
            'test-device',
          ],
          stdout: 'The Dart Tooling Daemon is available at: $dtdUri\n',
          pid: processPid,
        ),
      );
      final serverAndClient = await createServerAndClient(
        processManager: mockProcessManager,
        fileSystem: fileSystem,
      );
      final server = serverAndClient.server;
      final client = serverAndClient.client;

      // Initialize
      final initResult = await client.initialize(
        InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
        ),
      );
      test.expect(initResult.serverInfo.name, 'Flutter Launcher MCP Server');
      client.notifyInitialized();

      // Call the tool
      final result = await client.callTool(
        CallToolRequest(
          name: 'launch_app',
          arguments: {
            'root':
                '/Users/gspencer/code/gemini-cli-extension/flutter_launcher_mcp',
            'device': 'test-device',
          },
        ),
      );

      test.expect(result.isError, test.isNot(true));
      test.expect(result.structuredContent, {
        'dtdUri': dtdUri,
        'pid': processPid,
      });
      await server.shutdown();
      await client.shutdown();
    });

    test.test(
      'launch_app tool returns DTD URI and PID on success from stderr',
      () async {
        final dtdUri = 'ws://127.0.0.1:12345/abcdefg=';
        final processPid = 54321;
        final mockProcessManager = MockProcessManager();
        mockProcessManager.addCommand(
          Command(
            [
              '/path/to/flutter/sdk/bin/flutter',
              'run',
              '--print-dtd',
              '--device-id',
              'test-device',
            ],
            stderr: 'The Dart Tooling Daemon is available at: $dtdUri\n',
            pid: processPid,
          ),
        );
        final serverAndClient = await createServerAndClient(
          processManager: mockProcessManager,
          fileSystem: fileSystem,
        );
        final server = serverAndClient.server;
        final client = serverAndClient.client;

        // Initialize
        final initResult = await client.initialize(
          InitializeRequest(
            protocolVersion: ProtocolVersion.latestSupported,
            capabilities: ClientCapabilities(),
            clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
          ),
        );
        test.expect(initResult.serverInfo.name, 'Flutter Launcher MCP Server');
        client.notifyInitialized();

        // Call the tool
        final result = await client.callTool(
          CallToolRequest(
            name: 'launch_app',
            arguments: {
              'root':
                  '/Users/gspencer/code/gemini-cli-extension/flutter_launcher_mcp',
              'device': 'test-device',
            },
          ),
        );

        test.expect(result.isError, test.isNot(true));
        test.expect(result.structuredContent, {
          'dtdUri': dtdUri,
          'pid': processPid,
        });
        await server.shutdown();
        await client.shutdown();
      },
    );

    test.test(
      'hot_restart tool sends restart command to running app',
      () async {
        final dtdUri = 'ws://127.0.0.1:12345/abcdefg=';
        final processPid = 54321;
        final mockProcessManager = MockProcessManager();
        mockProcessManager.addCommand(
          Command(
            [
              '/path/to/flutter/sdk/bin/flutter',
              'run',
              '--print-dtd',
              '--device-id',
              'test-device',
            ],
            stdout: 'The Dart Tooling Daemon is available at: $dtdUri\n',
            pid: processPid,
          ),
        );
        final serverAndClient = await createServerAndClient(
          processManager: mockProcessManager,
          fileSystem: fileSystem,
        );
        final server = serverAndClient.server;
        final client = serverAndClient.client;

        // Initialize
        await client.initialize(
          InitializeRequest(
            protocolVersion: ProtocolVersion.latestSupported,
            capabilities: ClientCapabilities(),
            clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
          ),
        );
        client.notifyInitialized();

        // Launch the app first
        final launchResult = await client.callTool(
          CallToolRequest(
            name: 'launch_app',
            arguments: {'root': '/test/project', 'device': 'test-device'},
          ),
        );
        test.expect(launchResult.isError, test.isNot(true));

        // Perform hot restart
        final restartResult = await client.callTool(
          CallToolRequest(name: 'hot_restart', arguments: {'pid': processPid}),
        );

        test.expect(restartResult.isError, test.isNot(true));
        test.expect(restartResult.structuredContent, {'success': true});
        await server.shutdown();
        await client.shutdown();
      },
    );

    test.test('hot_restart tool returns error for non-existent app', () async {
      final mockProcessManager = MockProcessManager();
      final serverAndClient = await createServerAndClient(
        processManager: mockProcessManager,
        fileSystem: fileSystem,
      );
      final server = serverAndClient.server;
      final client = serverAndClient.client;

      // Initialize
      await client.initialize(
        InitializeRequest(
          protocolVersion: ProtocolVersion.latestSupported,
          capabilities: ClientCapabilities(),
          clientInfo: Implementation(name: 'test_client', version: '1.0.0'),
        ),
      );
      client.notifyInitialized();

      // Try to hot restart a non-existent app
      final restartResult = await client.callTool(
        CallToolRequest(name: 'hot_restart', arguments: {'pid': 99999}),
      );

      test.expect(restartResult.isError, true);
      await server.shutdown();
      await client.shutdown();
    });
  });
}

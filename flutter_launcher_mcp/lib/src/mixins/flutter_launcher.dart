// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A mixin that provides tools for launching and managing Flutter applications.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/server.dart';

import '../utils/process_manager.dart';
import '../utils/sdk.dart';

class _RunningApp {
  final Process process;
  final List<String> logs = [];
  String? dtdUri;

  _RunningApp(this.process);
}

/// A mixin that provides tools for launching and managing Flutter applications.
///
/// This mixin registers tools for launching, stopping, and listing Flutter
/// applications, as well as listing available devices and retrieving application
/// logs. It manages the lifecycle of Flutter processes that it launches.
base mixin FlutterLauncherSupport
    on ToolsSupport, LoggingSupport, RootsTrackingSupport
    implements ProcessManagerSupport, SdkSupport {
  final Map<int, _RunningApp> _runningApps = {};

  @override
  FutureOr<InitializeResult> initialize(InitializeRequest request) {
    registerTool(launchAppTool, _launchApp);
    registerTool(stopAppTool, _stopApp);
    registerTool(listDevicesTool, _listDevices);
    registerTool(getAppLogsTool, _getAppLogs);
    registerTool(listRunningAppsTool, _listRunningApps);
    registerTool(hotRestartTool, _hotRestart);
    return super.initialize(request);
  }

  /// A tool to launch a Flutter application.
  final launchAppTool = Tool(
    name: 'launch_app',
    description: 'Launches a Flutter application and returns its DTD URI.',
    inputSchema: Schema.object(
      properties: {
        'root': Schema.string(
          description: 'The root directory of the Flutter project.',
        ),
        'target': Schema.string(
          description:
              'The main entry point file of the application. Defaults to "lib/main.dart".',
        ),
        'device': Schema.string(
          description:
              "The device ID to launch the application on. To get a list of available devices to present as choices, use the list_devices tool.",
        ),
      },
      required: ['root', 'device'],
    ),
    outputSchema: Schema.object(
      properties: {
        'dtdUri': Schema.string(
          description: 'The DTD URI of the launched Flutter application.',
        ),
        'pid': Schema.int(
          description: 'The process ID of the launched Flutter application.',
        ),
      },
      required: ['dtdUri', 'pid'],
    ),
  );

  Future<CallToolResult> _launchApp(CallToolRequest request) async {
    if (sdk.flutterExecutablePath == null) {
      return CallToolResult(
        isError: true,
        content: [
          TextContent(
            text:
                'Flutter executable not found. Please ensure the Flutter SDK is in your path and restart the MCP server.',
          ),
        ],
      );
    }
    final root = request.arguments!['root'] as String;
    final target = request.arguments!['target'] as String?;
    final device = request.arguments!['device'] as String;
    final completer = Completer<({Uri dtdUri, int pid})>();

    log(
      LoggingLevel.debug,
      'Launching app with root: $root, target: $target, device: $device',
    );

    Process? process;
    try {
      process = await processManager.start(
        [
          sdk.flutterExecutablePath!,
          'run',
          '--print-dtd',
          '--device-id',
          device,
          if (target != null) '--target',
          if (target != null) target,
        ],
        workingDirectory: root,
        mode: ProcessStartMode.normal,
      );
      _runningApps[process.pid] = _RunningApp(process);
      log(
        LoggingLevel.info,
        'Launched Flutter application with PID: ${process.pid}',
      );

      final stdoutDone = Completer<void>();
      final stderrDone = Completer<void>();

      late StreamSubscription stdoutSubscription;
      late StreamSubscription stderrSubscription;
      final dtdUriRegex = RegExp(
        r'The Dart Tooling Daemon is available at: (ws://.+:\d+/\S+=)',
      );

      void checkForDtdUri(String line) {
        final match = dtdUriRegex.firstMatch(line);
        if (match != null && !completer.isCompleted) {
          final dtdUri = Uri.parse(match.group(1)!);
          log(LoggingLevel.debug, 'Found DTD URI: $dtdUri');
          completer.complete((dtdUri: dtdUri, pid: process!.pid));
        }
      }

      stdoutSubscription = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              log(
                LoggingLevel.debug,
                '[flutter stdout ${process!.pid}]: $line',
              );
              _runningApps[process.pid]?.logs.add('[stdout] $line');
              checkForDtdUri(line);
            },
            onDone: () => stdoutDone.complete(),
            onError: stdoutDone.completeError,
          );

      stderrSubscription = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              log(
                LoggingLevel.warning,
                '[flutter stderr ${process!.pid}]: $line',
              );
              _runningApps[process.pid]?.logs.add('[stderr] $line');
              checkForDtdUri(line);
            },
            onDone: () => stderrDone.complete(),
            onError: stderrDone.completeError,
          );

      unawaited(
        process.exitCode.then((exitCode) async {
          // Wait for both streams to finish processing before potentially completing the completer with an error.
          await Future.wait([stdoutDone.future, stderrDone.future]);

          log(
            LoggingLevel.info,
            'Flutter application ${process!.pid} exited with code $exitCode.',
          );
          _runningApps.remove(process.pid);
          if (!completer.isCompleted) {
            completer.completeError(
              'Flutter application exited with code $exitCode before the DTD URI was found.',
            );
          }
          // Cancel subscriptions after all processing is done.
          stdoutSubscription.cancel();
          stderrSubscription.cancel();
        }),
      );

      final result = await completer.future.timeout(
        const Duration(seconds: 90),
      );
      _runningApps[result.pid]?.dtdUri = result.dtdUri.toString();

      return CallToolResult(
        content: [
          TextContent(
            text:
                'Flutter application launched successfully with PID ${result.pid} with the DTD URI ${result.dtdUri}',
          ),
        ],
        structuredContent: {
          'dtdUri': result.dtdUri.toString(),
          'pid': result.pid,
        },
      );
    } catch (e, s) {
      log(LoggingLevel.error, 'Error launching Flutter application: $e\n$s');
      if (process != null) {
        process.kill();
        // The exitCode handler will perform the rest of the cleanup.
      }
      return CallToolResult(
        isError: true,
        content: [
          TextContent(text: 'Failed to launch Flutter application: $e'),
        ],
      );
    }
  }

  /// A tool to stop a running Flutter application.
  final stopAppTool = Tool(
    name: 'stop_app',
    description:
        'Kills a running Flutter process started by the launch_app tool.',
    inputSchema: Schema.object(
      properties: {
        'pid': Schema.int(
          description: 'The process ID of the process to kill.',
        ),
      },
      required: ['pid'],
    ),
    outputSchema: Schema.object(
      properties: {
        'success': Schema.bool(
          description: 'Whether the process was killed successfully.',
        ),
      },
      required: ['success'],
    ),
  );

  Future<CallToolResult> _stopApp(CallToolRequest request) async {
    final pid = request.arguments!['pid'] as int;
    log(LoggingLevel.info, 'Attempting to stop application with PID: $pid');
    final app = _runningApps[pid];

    if (app == null) {
      log(LoggingLevel.error, 'Application with PID $pid not found.');
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Application with PID $pid not found.')],
      );
    }

    final success = processManager.killPid(pid);
    if (success) {
      log(
        LoggingLevel.info,
        'Successfully sent kill signal to application $pid.',
      );
    } else {
      log(
        LoggingLevel.warning,
        'Failed to send kill signal to application $pid.',
      );
    }

    return CallToolResult(
      content: [
        TextContent(
          text:
              'Application with PID $pid ${success ? 'was stopped' : 'was unable to be stopped'}.',
        ),
      ],
      isError: !success,
      structuredContent: {'success': success},
    );
  }

  /// A tool to list available Flutter devices.
  final listDevicesTool = Tool(
    name: 'list_devices',
    description: 'Lists available Flutter devices.',
    inputSchema: Schema.object(),
    outputSchema: Schema.object(
      properties: {
        'devices': Schema.list(
          description: 'A list of available device IDs.',
          items: Schema.string(),
        ),
      },
      required: ['devices'],
    ),
  );

  Future<CallToolResult> _listDevices(CallToolRequest request) async {
    if (sdk.flutterExecutablePath == null) {
      return CallToolResult(
        isError: true,
        content: [
          TextContent(
            text:
                'Flutter executable not found. Please ensure the Flutter SDK is in your path and restart the MCP server.',
          ),
        ],
      );
    }
    try {
      log(LoggingLevel.debug, 'Listing flutter devices.');
      final result = await processManager.run([
        sdk.flutterExecutablePath!,
        'devices',
        '--machine',
      ]);

      if (result.exitCode != 0) {
        log(
          LoggingLevel.error,
          'Flutter devices command failed with exit code ${result.exitCode}. Stderr: ${result.stderr}',
        );
        return CallToolResult(
          isError: true,
          content: [
            TextContent(
              text: 'Failed to list Flutter devices: ${result.stderr}',
            ),
          ],
        );
      }

      final stdout = result.stdout as String;
      if (stdout.isEmpty) {
        log(LoggingLevel.debug, 'No devices found.');
        return CallToolResult(
          content: [TextContent(text: 'No devices found.')],
          structuredContent: {'devices': <String>[]},
        );
      }

      final devices = (jsonDecode(stdout) as List)
          .cast<Map<String, dynamic>>()
          .map((device) => device['id'] as String)
          .toList();
      log(LoggingLevel.debug, 'Found devices: $devices');

      return CallToolResult(
        content: [TextContent(text: 'Found devices: ${devices.join(', ')}')],
        structuredContent: {'devices': devices},
      );
    } catch (e, s) {
      log(LoggingLevel.error, 'Error listing Flutter devices: $e\n$s');
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Failed to list Flutter devices: $e')],
      );
    }
  }

  /// A tool to get the logs for a running Flutter application.
  final getAppLogsTool = Tool(
    name: 'get_app_logs',
    description:
        'Returns the collected logs for a given flutter run process id. Can only retrieve logs started by the launch_app tool.',
    inputSchema: Schema.object(
      properties: {
        'pid': Schema.int(
          description:
              'The process ID of the flutter run process running the application.',
        ),
      },
      required: ['pid'],
    ),
    outputSchema: Schema.object(
      properties: {
        'logs': Schema.list(
          description: 'The collected logs for the process.',
          items: Schema.string(),
        ),
      },
      required: ['logs'],
    ),
  );

  Future<CallToolResult> _getAppLogs(CallToolRequest request) async {
    final pid = request.arguments!['pid'] as int;
    log(LoggingLevel.info, 'Getting logs for application with PID: $pid');
    final logs = _runningApps[pid]?.logs;

    if (logs == null) {
      log(
        LoggingLevel.error,
        'Application with PID $pid not found or has no logs.',
      );
      return CallToolResult(
        isError: true,
        content: [
          TextContent(
            text: 'Application with PID $pid not found or has no logs.',
          ),
        ],
      );
    }

    return CallToolResult(
      content: [TextContent(text: logs.join('\n'))],
      structuredContent: {'logs': logs},
    );
  }

  /// A tool to list all running Flutter applications.
  final listRunningAppsTool = Tool(
    name: 'list_running_apps',
    description:
        'Returns the list of running app process IDs and associated DTD URIs for apps started by the launch_app tool.',
    inputSchema: Schema.object(),
    outputSchema: Schema.object(
      properties: {
        'apps': Schema.list(
          description:
              'A list of running applications started by the launch_app tool.',
          items: Schema.object(
            properties: {
              'pid': Schema.int(
                description: 'The process ID of the application.',
              ),
              'dtdUri': Schema.string(
                description: 'The DTD URI of the application.',
              ),
            },
            required: ['pid', 'dtdUri'],
          ),
        ),
      },
      required: ['apps'],
    ),
  );

  Future<CallToolResult> _listRunningApps(CallToolRequest request) async {
    final apps = _runningApps.entries
        .where((entry) => entry.value.dtdUri != null)
        .map((entry) {
          return {'pid': entry.key, 'dtdUri': entry.value.dtdUri!};
        })
        .toList();

    return CallToolResult(
      content: [
        TextContent(
          text:
              'Found ${apps.length} running application${apps.length == 1 ? '' : 's'}.\n${apps.map<String>((e) {
                return 'PID: ${e['pid']}, DTD URI: ${e['dtdUri']}';
              }).toList().join('\n')}',
        ),
      ],
      structuredContent: {'apps': apps},
    );
  }

  /// A tool to perform a hot restart on a running Flutter application.
  final hotRestartTool = Tool(
    name: 'hot_restart',
    description:
        'Performs a hot restart on a running Flutter application. This restarts the app while maintaining the current session.',
    inputSchema: Schema.object(
      properties: {
        'pid': Schema.int(
          description:
              'The process ID of the flutter run process to hot restart.',
        ),
      },
      required: ['pid'],
    ),
    outputSchema: Schema.object(
      properties: {
        'success': Schema.bool(
          description: 'Whether the hot restart was successful.',
        ),
      },
      required: ['success'],
    ),
  );

  Future<CallToolResult> _hotRestart(CallToolRequest request) async {
    final pid = request.arguments!['pid'] as int;
    log(LoggingLevel.info, 'Attempting hot restart for application PID: $pid');
    final app = _runningApps[pid];

    if (app == null) {
      log(LoggingLevel.error, 'Application with PID $pid not found.');
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Application with PID $pid not found.')],
      );
    }

    try {
      app.process.stdin.writeln('R');
      await app.process.stdin.flush();
      log(LoggingLevel.info, 'Hot restart command sent to application $pid.');

      return CallToolResult(
        content: [
          TextContent(
            text: 'Hot restart initiated for application with PID $pid.',
          ),
        ],
        structuredContent: {'success': true},
      );
    } catch (e, s) {
      log(
        LoggingLevel.error,
        'Error performing hot restart for application $pid: $e\n$s',
      );
      return CallToolResult(
        isError: true,
        content: [
          TextContent(
            text: 'Failed to perform hot restart for application $pid: $e',
          ),
        ],
        structuredContent: {'success': false},
      );
    }
  }

  @override
  Future<void> shutdown() {
    log(LoggingLevel.info, 'Shutting down server, killing all processes.');
    for (final pid in _runningApps.keys) {
      log(LoggingLevel.debug, 'Killing process $pid.');
      processManager.killPid(pid);
    }
    _runningApps.clear();
    return super.shutdown();
  }
}

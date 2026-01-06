// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/args.dart';
import 'package:release_scripts/src/bump_version_command.dart';
import 'package:release_scripts/src/utils.dart';

Future<void> main(List<String> args) async {
  await runScript((context) async {
    final parser = ArgParser();
    parser.addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    );
    final argResults = parser.parse(args);

    if (argResults.flag('help') || argResults.rest.isEmpty) {
      print('Usage: bump_version <new_version>');
      print(parser.usage);
      if (argResults.rest.isEmpty && !argResults.flag('help')) {
        throw ExitException('No version provided.');
      }
      return;
    }
    await BumpVersionCommand(context, argResults.rest.first).run();
  });
}

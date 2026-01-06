// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/args.dart';
import 'package:release_scripts/src/update_local_command.dart';
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

    if (argResults.flag('help')) {
      print('Usage: update_local');
      print(parser.usage);
      return;
    } else if (argResults.rest.isNotEmpty) {
      throw ExitException(
        'Unexpected arguments: ${argResults.rest.join(' ')}\nUsage: update_local',
      );
    }

    await UpdateLocalCommand(context).run();
  });
}
